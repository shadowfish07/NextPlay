#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

source "$repo_root/tool/load_env.sh"
nextplay_load_env "$repo_root"

package_name="me.zqydev.nextplay.debug"
avd_name="${NEXTPLAY_AVD:-Pixel_7_Pro_API_36}"
boot_timeout="${NEXTPLAY_ANDROID_BOOT_TIMEOUT_SECONDS:-180}"
lease_timeout="${NEXTPLAY_ANDROID_LEASE_TIMEOUT_SECONDS:-900}"
started_emulator=0
emulator_pid=""
device="${NEXTPLAY_ANDROID_DEVICE:-}"
capture_visual_evidence=0
case "${NEXTPLAY_CAPTURE_VISUAL_EVIDENCE:-}" in
  1|true|TRUE|yes|YES) capture_visual_evidence=1 ;;
esac
timestamp="$(date '+%Y%m%d-%H%M%S')"
artifact_dir="$repo_root/.artifacts/e2e/$timestamp"
mkdir -p "$artifact_dir"

git_common_dir="$(git rev-parse --path-format=absolute --git-common-dir)"
lease_dir="$git_common_dir/nextplay-android-e2e.lock"
worktree_state_dir="$repo_root/.nextplay-worktree"
runtime_dir="$worktree_state_dir/e2e-runtime"
lease_token="$(date '+%s')-$$-${RANDOM}"
lease_acquired=0

require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Required command not found: $1" >&2
    exit 1
  }
}

require_command adb
require_command flutter
require_command git
require_command rg

if [[ ! "$lease_timeout" =~ ^[0-9]+$ ]]; then
  echo "NEXTPLAY_ANDROID_LEASE_TIMEOUT_SECONDS must be a non-negative integer." >&2
  exit 1
fi

android_sdk_root="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$HOME/Library/Android/sdk}}"
emulator_bin="$android_sdk_root/emulator/emulator"
if [[ ! -x "$emulator_bin" ]]; then
  emulator_bin="$(command -v emulator || true)"
fi

find_avd_device() {
  local candidate
  local candidate_avd
  while IFS= read -r candidate; do
    candidate_avd="$(adb -s "$candidate" emu avd name 2>/dev/null | head -1 | tr -d '\r')"
    if [[ "$candidate_avd" == "$avd_name" ]]; then
      echo "$candidate"
      return 0
    fi
  done < <(adb devices | awk 'NR > 1 && $2 == "device" { print $1 }')
  return 1
}

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

acquire_android_lease() {
  local deadline=$((SECONDS + lease_timeout))
  local wait_announced=0
  local owner_pid
  local owner_root
  local stale_token

  while ! mkdir "$lease_dir" 2>/dev/null; do
    owner_pid="$(read_state_file "$lease_dir/pid")"
    owner_root="$(read_state_file "$lease_dir/worktree")"
    if [[ -n "$owner_pid" ]] && ! pid_is_alive "$owner_pid"; then
      stale_token="$(read_state_file "$lease_dir/token")"
      if [[ -n "$stale_token" ]] && remove_known_lease "$stale_token" 2>/dev/null; then
        echo "Reclaimed stale Android E2E lease from ${owner_root:-unknown worktree}."
        continue
      fi
    fi

    if (( SECONDS >= deadline )); then
      echo "Timed out waiting for the shared Android E2E lease held by ${owner_root:-unknown worktree} (PID ${owner_pid:-unknown})." >&2
      exit 1
    fi
    if (( wait_announced == 0 )); then
      echo "Waiting for the shared Android E2E lease held by ${owner_root:-unknown worktree}..."
      wait_announced=1
    fi
    sleep 1
  done

  chmod 700 "$lease_dir"
  printf '%s\n' "$lease_token" >"$lease_dir/token"
  printf '%s\n' "$$" >"$lease_dir/pid"
  printf '%s\n' "$repo_root" >"$lease_dir/worktree"
  printf '%s\n' "$avd_name" >"$lease_dir/avd"
  date -u '+%Y-%m-%dT%H:%M:%SZ' >"$lease_dir/started-at"
  chmod 600 "$lease_dir"/*
  lease_acquired=1

  mkdir -p "$runtime_dir"
  chmod 700 "$worktree_state_dir" "$runtime_dir"
  printf '%s\n' "$lease_token" >"$runtime_dir/token"
  printf '%s\n' "$$" >"$runtime_dir/pid"
  printf '%s\n' "$repo_root" >"$runtime_dir/worktree"
  printf '%s\n' "$avd_name" >"$runtime_dir/avd"
  printf '0\n' >"$runtime_dir/started-emulator"
  : >"$runtime_dir/device"
  : >"$runtime_dir/emulator-pid"
  chmod 600 "$runtime_dir"/*
  echo "Acquired shared Android E2E lease for: $repo_root"
}

remove_known_runtime_state() {
  local current_token
  local name
  [[ -d "$runtime_dir" ]] || return 0
  current_token="$(read_state_file "$runtime_dir/token")"
  [[ "$current_token" == "$lease_token" ]] || return 1
  for name in token pid worktree avd device started-emulator emulator-pid; do
    [[ -e "$runtime_dir/$name" ]] && rm -f "$runtime_dir/$name"
  done
  rmdir "$runtime_dir" 2>/dev/null || true
}

stop_owned_emulator() {
  local actual_avd
  local command_line
  (( started_emulator == 1 )) || return 0

  if [[ -n "$device" ]] && adb -s "$device" get-state >/dev/null 2>&1; then
    actual_avd="$(adb -s "$device" emu avd name 2>/dev/null | head -1 | tr -d '\r')"
    if [[ "$actual_avd" == "$avd_name" ]]; then
      adb -s "$device" emu kill >/dev/null
      return
    fi
    echo "Refusing to stop ${device}: expected AVD ${avd_name}, found ${actual_avd:-unknown}." >&2
    return 1
  fi

  if pid_is_alive "$emulator_pid"; then
    command_line="$(ps -p "$emulator_pid" -o command= 2>/dev/null || true)"
    if [[ "$command_line" == *"-avd $avd_name"* ]]; then
      kill -TERM "$emulator_pid"
      return
    fi
    echo "Refusing to stop emulator PID ${emulator_pid}: command does not match AVD ${avd_name}." >&2
    return 1
  fi
}

collect_artifacts() {
  local exit_code=$?
  local cleanup_ok=1
  set +e
  if [[ -n "$device" ]] && adb -s "$device" get-state >/dev/null 2>&1; then
    adb -s "$device" exec-out screencap -p >"$artifact_dir/screenshot.png"
    adb -s "$device" shell uiautomator dump /sdcard/nextplay-e2e.xml >/dev/null
    adb -s "$device" pull /sdcard/nextplay-e2e.xml "$artifact_dir/ui.xml" >/dev/null
    adb -s "$device" shell rm /sdcard/nextplay-e2e.xml >/dev/null
    app_pid="$(adb -s "$device" shell pidof "$package_name" | tr -d '\r')"
    if [[ -n "$app_pid" ]]; then
      adb -s "$device" logcat -d --pid="$app_pid" >"$artifact_dir/logcat.txt"
    else
      adb -s "$device" logcat -d -t 2000 >"$artifact_dir/logcat.txt"
    fi
    adb -s "$device" shell am force-stop "$package_name" >/dev/null
  fi
  if ! stop_owned_emulator; then
    cleanup_ok=0
    exit_code=1
  fi
  if (( cleanup_ok == 1 )) && ! remove_known_runtime_state; then
    cleanup_ok=0
    exit_code=1
  fi
  if (( lease_acquired == 1 && cleanup_ok == 1 )); then
    if ! remove_known_lease "$lease_token"; then
      echo "Android E2E lease ownership changed; shared lease was not removed." >&2
      exit_code=1
    fi
  elif (( cleanup_ok == 0 )); then
    echo "Owned Android runtime cleanup was incomplete; lease state was preserved for 'tool/worktree.sh down'." >&2
  fi
  if (( exit_code != 0 )); then
    echo "Android E2E failed; artifacts: $artifact_dir" >&2
  else
    echo "Android E2E passed; artifacts: $artifact_dir"
  fi
  exit "$exit_code"
}

acquire_android_lease
trap collect_artifacts EXIT

if [[ -n "$device" ]]; then
  adb -s "$device" get-state >/dev/null
  selected_avd="$(adb -s "$device" emu avd name 2>/dev/null | head -1 | tr -d '\r')"
  if [[ "$selected_avd" != "$avd_name" ]]; then
    echo "Configured device ${device} belongs to AVD ${selected_avd:-unknown}, not ${avd_name}." >&2
    exit 1
  fi
else
  device="$(find_avd_device || true)"
fi

if [[ -z "$device" ]]; then
  if [[ -z "$emulator_bin" || ! -x "$emulator_bin" ]]; then
    echo "Android emulator executable not found under: $android_sdk_root" >&2
    exit 1
  fi
  if ! "$emulator_bin" -list-avds | rg -xq "$avd_name"; then
    echo "Configured AVD does not exist: $avd_name" >&2
    exit 1
  fi
  "$emulator_bin" -avd "$avd_name" -no-snapshot-save -no-boot-anim >"$artifact_dir/emulator.log" 2>&1 &
  emulator_pid=$!
  started_emulator=1
  printf '1\n' >"$runtime_dir/started-emulator"
  printf '%s\n' "$emulator_pid" >"$runtime_dir/emulator-pid"

  deadline=$((SECONDS + boot_timeout))
  while (( SECONDS < deadline )); do
    device="$(find_avd_device || true)"
    if [[ -n "$device" ]]; then
      boot_completed="$(adb -s "$device" shell getprop sys.boot_completed | tr -d '\r')"
      [[ "$boot_completed" == "1" ]] && break
    fi
    sleep 2
  done
  if [[ -z "$device" || "$(adb -s "$device" shell getprop sys.boot_completed | tr -d '\r')" != "1" ]]; then
    echo "Android emulator did not become ready within ${boot_timeout}s." >&2
    exit 1
  fi
fi

printf '%s\n' "$device" >"$runtime_dir/device"
echo "Using Android device: $device"
adb -s "$device" shell pm clear "$package_name" >/dev/null 2>&1 || true
adb -s "$device" uninstall "$package_name" >/dev/null 2>&1 || true

capture_key_state_screenshots() {
  local screenshot_name
  local ready_path
  local complete_path
  local captured
  # This listener starts before Gradle builds and installs the integration APK,
  # so its window must also cover compilation and the preceding E2E flow.
  local deadline=$((SECONDS + 240))

  for screenshot_name in \
    official-localization-status \
    localized-library \
    localized-details \
    settings-update; do
    captured=0
    ready_path="app_flutter/e2e-screenshots/${screenshot_name}.ready"
    complete_path="app_flutter/e2e-screenshots/${screenshot_name}.done"
    while (( SECONDS < deadline )); do
      if adb -s "$device" shell run-as "$package_name" test -f "$ready_path" \
        >/dev/null 2>&1; then
        sleep 0.3
        adb -s "$device" exec-out screencap -p \
          >"$artifact_dir/${screenshot_name}.png"
        adb -s "$device" shell run-as "$package_name" touch "$complete_path" \
          >/dev/null
        echo "Captured key-state screenshot: $artifact_dir/${screenshot_name}.png"
        captured=1
        break
      fi
      sleep 0.2
    done

    if (( captured != 1 )); then
      echo "Timed out waiting for the ${screenshot_name} screenshot request." >&2
      return 1
    fi
  done
}

if (( capture_visual_evidence == 1 )); then
  capture_pid=""
  capture_status=0
  capture_key_state_screenshots &
  capture_pid=$!
  if flutter test integration_test/app_flow_test.dart \
    -d "$device" \
    --dart-define=NEXTPLAY_CAPTURE_VISUAL_EVIDENCE=true; then
    integration_test_status=0
  else
    integration_test_status=$?
  fi
  if (( integration_test_status != 0 )); then
    kill "$capture_pid" >/dev/null 2>&1 || true
    wait "$capture_pid" >/dev/null 2>&1 || true
    exit "$integration_test_status"
  fi
  if wait "$capture_pid"; then
    capture_status=0
  else
    capture_status=$?
  fi
  if (( capture_status != 0 )); then
    exit 1
  fi
else
  flutter test integration_test/app_flow_test.dart -d "$device"
fi

device_abi="$(adb -s "$device" shell getprop ro.product.cpu.abi | tr -d '\r')"
case "$device_abi" in
  arm64-v8a) flutter_target="android-arm64" ;;
  armeabi-v7a) flutter_target="android-arm" ;;
  x86_64) flutter_target="android-x64" ;;
  *)
    echo "Unsupported Android ABI for scoped debug build: $device_abi" >&2
    exit 1
    ;;
esac
flutter build apk --debug --target-platform "$flutter_target"

apk_path="$repo_root/build/app/outputs/flutter-apk/app-debug.apk"
adb -s "$device" shell pm clear "$package_name" >/dev/null 2>&1 || true
if ! adb -s "$device" install -r "$apk_path" >/dev/null; then
  echo "In-place install failed; reinstalling only ${package_name}."
  adb -s "$device" uninstall "$package_name" >/dev/null 2>&1 || true
  adb -s "$device" install "$apk_path" >/dev/null
fi
adb -s "$device" shell pm clear "$package_name" >/dev/null
adb -s "$device" shell am start -W \
  -n "$package_name/me.zqydev.nextplay.MainActivity" >"$artifact_dir/launch.txt"

dismiss_known_system_anr() {
  local ui_xml="$1"
  local close_bounds
  local left
  local top
  local right
  local bottom

  if ! rg -Fq "Pixel Launcher isn't responding" "$ui_xml" \
    && ! rg -Fq "System UI isn't responding" "$ui_xml"; then
    return 1
  fi

  close_bounds="$(
    sed 's/></>\
</g' "$ui_xml" \
      | sed -n '/resource-id="android:id\/aerr_close"/s/.*bounds="\[\([0-9][0-9]*\),\([0-9][0-9]*\)\]\[\([0-9][0-9]*\),\([0-9][0-9]*\)\]".*/\1 \2 \3 \4/p' \
      | head -1
  )"
  if [[ -z "$close_bounds" ]]; then
    return 1
  fi

  read -r left top right bottom <<<"$close_bounds"
  echo "Dismissing known Android system ANR dialog before app verification."
  adb -s "$device" shell input tap \
    "$(((left + right) / 2))" "$(((top + bottom) / 2))"
  sleep 1
}

launcher_ready=0
for _ in {1..30}; do
  adb -s "$device" shell uiautomator dump /sdcard/nextplay-launch.xml >/dev/null 2>&1 || true
  adb -s "$device" pull /sdcard/nextplay-launch.xml "$artifact_dir/launcher-ui.xml" >/dev/null 2>&1 || true
  if [[ -f "$artifact_dir/launcher-ui.xml" ]] \
    && dismiss_known_system_anr "$artifact_dir/launcher-ui.xml"; then
    continue
  fi
  if [[ -f "$artifact_dir/launcher-ui.xml" ]] && rg -q '欢迎使用 NextPlay' "$artifact_dir/launcher-ui.xml"; then
    launcher_ready=1
    break
  fi
  sleep 1
done
adb -s "$device" shell rm /sdcard/nextplay-launch.xml >/dev/null 2>&1 || true

if (( launcher_ready != 1 )); then
  echo "Installed launcher did not reach the onboarding screen." >&2
  exit 1
fi

app_pid="$(adb -s "$device" shell pidof "$package_name" | tr -d '\r')"
if [[ -n "$app_pid" ]]; then
  adb -s "$device" logcat -d --pid="$app_pid" >"$artifact_dir/logcat.txt"
else
  adb -s "$device" logcat -d -t 2000 >"$artifact_dir/logcat.txt"
fi
if rg -n 'FATAL EXCEPTION|AndroidRuntime.*FATAL' "$artifact_dir/logcat.txt" >/dev/null 2>&1; then
  echo "Fatal Android runtime error detected." >&2
  exit 1
fi
