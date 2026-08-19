#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$repo_root"

git_common_dir="$(git rev-parse --path-format=absolute --git-common-dir)"
primary_root="$(git worktree list --porcelain | sed -n 's/^worktree //p' | head -1)"
primary_root="$(cd "$primary_root" && pwd -P)"
state_dir="$repo_root/.nextplay-worktree"
setup_marker="$state_dir/setup-complete"
lease_dir="$git_common_dir/nextplay-android-e2e.lock"
runtime_dir="$state_dir/e2e-runtime"

hash_value() {
  if command -v shasum >/dev/null 2>&1; then
    printf '%s' "$1" | shasum -a 256 | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then
    printf '%s' "$1" | sha256sum | awk '{print $1}'
  else
    printf '%s' "$1" | cksum | awk '{print $1}'
  fi
}

worktree_id="wt_$(hash_value "$repo_root|$git_common_dir" | cut -c1-12)"

read_state_file() {
  local path="$1"
  local value=""
  if [[ -f "$path" ]]; then
    IFS= read -r value <"$path" || true
  fi
  printf '%s' "$value"
}

pid_is_alive() {
  local pid="$1"
  [[ "$pid" =~ ^[0-9]+$ ]] && kill -0 "$pid" >/dev/null 2>&1
}

ensure_state_dir() {
  mkdir -p "$state_dir"
  chmod 700 "$state_dir"
}

write_identity_file() {
  local name="$1"
  local expected="$2"
  local path="$state_dir/$name"
  local actual

  if [[ -f "$path" ]]; then
    actual="$(read_state_file "$path")"
    if [[ "$actual" != "$expected" ]]; then
      echo "Worktree state mismatch for ${name}: expected ${expected}, found ${actual}." >&2
      exit 1
    fi
    return
  fi

  printf '%s\n' "$expected" >"$path"
  chmod 600 "$path"
}

record_identity() {
  ensure_state_dir
  write_identity_file id "$worktree_id"
  write_identity_file root "$repo_root"
  write_identity_file primary-root "$primary_root"
}

env_mode() {
  local path="$1"
  if stat -f '%Lp' "$path" >/dev/null 2>&1; then
    stat -f '%Lp' "$path"
  else
    stat -c '%a' "$path"
  fi
}

copy_primary_env() {
  local replace_existing="$1"
  local source_env="$primary_root/.env"
  local target_env="$repo_root/.env"
  local staged_env
  local backup_dir

  if [[ "$repo_root" == "$primary_root" ]]; then
    if [[ -f "$target_env" ]]; then
      chmod 600 "$target_env"
      echo "Primary .env retained with mode 600."
    else
      echo "Primary .env is absent; create it from .env.example when live credentials are needed."
    fi
    return
  fi

  if [[ ! -f "$source_env" ]]; then
    if [[ -f "$target_env" ]]; then
      chmod 600 "$target_env"
      echo "Primary .env is absent; existing worktree .env was preserved."
      return
    fi
    echo "Primary .env is absent; no credentials were copied."
    return
  fi

  if [[ -f "$target_env" && "$replace_existing" != "1" ]]; then
    chmod 600 "$target_env"
    echo "Existing worktree .env preserved. Use 'tool/worktree.sh env:pull' to refresh it."
    return
  fi

  ensure_state_dir
  if [[ -f "$target_env" ]]; then
    backup_dir="$(mktemp -d "$state_dir/env-backup-$(date '+%Y%m%d-%H%M%S').XXXXXX")"
    chmod 700 "$backup_dir"
    cp "$target_env" "$backup_dir/.env"
    chmod 600 "$backup_dir/.env"
    echo "Backed up the previous worktree .env under: $backup_dir"
  fi

  staged_env="$(mktemp "$state_dir/.env.stage.XXXXXX")"
  chmod 600 "$staged_env"
  cp "$source_env" "$staged_env"
  chmod 600 "$staged_env"
  mv -f "$staged_env" "$target_env"
  chmod 600 "$target_env"
  printf '%s\n' "$source_env" >"$state_dir/env-origin"
  chmod 600 "$state_dir/env-origin"
  echo "Copied primary .env into this worktree with mode 600."
}

lease_belongs_to_this_worktree() {
  [[ -d "$lease_dir" ]] || return 1
  [[ "$(read_state_file "$lease_dir/worktree")" == "$repo_root" ]]
}

refuse_active_e2e() {
  local owner_pid
  if lease_belongs_to_this_worktree; then
    owner_pid="$(read_state_file "$lease_dir/pid")"
    if pid_is_alive "$owner_pid"; then
      echo "Android E2E is active for this worktree (PID ${owner_pid}); interrupt its foreground terminal first." >&2
      exit 1
    fi
  fi
}

configured_avd() {
  source "$repo_root/tool/load_env.sh"
  nextplay_load_env "$repo_root"
  printf '%s' "${NEXTPLAY_AVD:-Pixel_7_Pro_API_36}"
}

remove_known_runtime_state() {
  local name
  [[ -d "$runtime_dir" ]] || return 0
  for name in token pid worktree avd device started-emulator emulator-pid; do
    [[ -e "$runtime_dir/$name" ]] && rm -f "$runtime_dir/$name"
  done
  rmdir "$runtime_dir" 2>/dev/null || true
}

remove_known_lease() {
  local expected_token="$1"
  local current_token
  local name

  [[ -n "$expected_token" && -d "$lease_dir" ]] || return 1
  current_token="$(read_state_file "$lease_dir/token")"
  [[ "$current_token" == "$expected_token" ]] || return 1

  for name in token pid worktree avd started-at; do
    [[ -e "$lease_dir/$name" ]] && rm -f "$lease_dir/$name"
  done
  rmdir "$lease_dir"
}

stop_orphaned_owned_emulator() {
  local token="$1"
  local runtime_token
  local started
  local device
  local expected_avd
  local actual_avd
  local emulator_pid
  local command_line

  [[ -d "$runtime_dir" ]] || return 0
  runtime_token="$(read_state_file "$runtime_dir/token")"
  [[ -n "$token" && "$runtime_token" == "$token" ]] || {
    echo "Runtime ownership token does not match the stale Android lease; refusing cleanup." >&2
    return 1
  }

  started="$(read_state_file "$runtime_dir/started-emulator")"
  [[ "$started" == "1" ]] || return 0
  expected_avd="$(read_state_file "$runtime_dir/avd")"
  device="$(read_state_file "$runtime_dir/device")"

  if [[ -n "$device" ]] && adb -s "$device" get-state >/dev/null 2>&1; then
    actual_avd="$(adb -s "$device" emu avd name 2>/dev/null | head -1 | tr -d '\r')"
    if [[ "$actual_avd" != "$expected_avd" ]]; then
      echo "Device ${device} now belongs to AVD ${actual_avd}, not ${expected_avd}; refusing cleanup." >&2
      return 1
    fi
    adb -s "$device" emu kill >/dev/null
    echo "Stopped orphaned worktree-owned AVD ${expected_avd} on ${device}."
    return
  fi

  emulator_pid="$(read_state_file "$runtime_dir/emulator-pid")"
  if pid_is_alive "$emulator_pid"; then
    command_line="$(ps -p "$emulator_pid" -o command= 2>/dev/null || true)"
    if [[ "$command_line" != *"-avd $expected_avd"* ]]; then
      echo "Emulator PID ${emulator_pid} does not match AVD ${expected_avd}; refusing cleanup." >&2
      return 1
    fi
    kill -TERM "$emulator_pid"
    echo "Stopped booting worktree-owned AVD ${expected_avd} (PID ${emulator_pid})."
  fi
}

run_setup() {
  record_identity
  refuse_active_e2e
  copy_primary_env 0
  flutter pub get --enforce-lockfile
  dart run build_runner build --delete-conflicting-outputs
  if [[ ! -f "$setup_marker" ]]; then
    date -u '+%Y-%m-%dT%H:%M:%SZ' >"$setup_marker"
    chmod 600 "$setup_marker"
  fi
  echo "Worktree setup complete: $worktree_id"
}

run_env_pull() {
  if [[ "$repo_root" == "$primary_root" ]]; then
    echo "env:pull is only valid in a linked worktree; the primary .env is already canonical." >&2
    exit 1
  fi
  record_identity
  refuse_active_e2e
  copy_primary_env 1
}

run_status() {
  local role="linked"
  local setup_state="no"
  local env_state="absent"
  local env_origin="n/a"
  local lease_state="idle"
  local owner_pid
  local owner_root
  local device
  local avd_name

  [[ "$repo_root" == "$primary_root" ]] && role="primary"
  [[ -f "$setup_marker" ]] && setup_state="yes"
  if [[ -f "$repo_root/.env" ]]; then
    env_state="present (mode $(env_mode "$repo_root/.env"))"
    env_origin="$(read_state_file "$state_dir/env-origin")"
    [[ -n "$env_origin" ]] || env_origin="local"
  fi

  if [[ -d "$lease_dir" ]]; then
    owner_pid="$(read_state_file "$lease_dir/pid")"
    owner_root="$(read_state_file "$lease_dir/worktree")"
    if pid_is_alive "$owner_pid"; then
      if [[ "$owner_root" == "$repo_root" ]]; then
        lease_state="active here (PID ${owner_pid})"
      else
        lease_state="active in ${owner_root} (PID ${owner_pid})"
      fi
    else
      lease_state="stale (${owner_root:-unknown owner}, PID ${owner_pid:-unknown})"
    fi
  fi

  avd_name="$(configured_avd)"
  device="$(read_state_file "$runtime_dir/device")"

  printf '%-18s %s\n' \
    "worktree:" "$repo_root" \
    "role:" "$role" \
    "id:" "$worktree_id" \
    "primary:" "$primary_root" \
    "setup complete:" "$setup_state" \
    ".env:" "$env_state" \
    ".env origin:" "$env_origin" \
    "configured AVD:" "$avd_name" \
    "Android lease:" "$lease_state" \
    "active device:" "${device:-none}" \
    "runtime data:" "AVD-local; never synchronized to primary"
}

run_down() {
  local owner_pid
  local token

  if ! lease_belongs_to_this_worktree; then
    echo "No Android E2E lease owned by this worktree."
    return
  fi

  owner_pid="$(read_state_file "$lease_dir/pid")"
  if pid_is_alive "$owner_pid"; then
    echo "Android E2E is active for this worktree (PID ${owner_pid}); refusing to terminate a foreground run." >&2
    exit 1
  fi

  token="$(read_state_file "$lease_dir/token")"
  stop_orphaned_owned_emulator "$token"
  remove_known_runtime_state
  if remove_known_lease "$token"; then
    echo "Released stale Android E2E lease for this worktree."
  else
    echo "Android lease changed during cleanup; no shared state was removed." >&2
    exit 1
  fi
}

usage() {
  cat <<'EOF'
Usage: tool/worktree.sh <command>

Commands:
  setup       Initialize this checkout and copy primary .env once.
  status      Show worktree identity, env provenance, AVD, and lease state.
  e2e         Run the repository Android E2E under the shared AVD lease.
  down        Clean up only a stale Android runtime owned by this worktree.
  env:pull    Refresh .env from primary with a local backup; never writes back.
EOF
}

case "${1:-}" in
  setup) run_setup ;;
  status) run_status ;;
  e2e)
    run_setup
    exec "$repo_root/tool/e2e_android.sh"
    ;;
  down) run_down ;;
  env:pull) run_env_pull ;;
  help|-h|--help|"") usage ;;
  *)
    echo "Unknown worktree command: $1" >&2
    usage >&2
    exit 2
    ;;
esac
