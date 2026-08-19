#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

source "$repo_root/tool/load_env.sh"
nextplay_load_env "$repo_root"

local_url="${NEXTPLAY_IGDB_LOCAL_URL:-http://127.0.0.1:61000}"
public_url="${NEXTPLAY_IGDB_PUBLIC_URL:-https://igdb.zqydev.me}"
timeout_seconds="${NEXTPLAY_LIVE_TIMEOUT_SECONDS:-15}"
smoke_tmp="$(mktemp -d "${TMPDIR:-/tmp}/nextplay-live-smoke.XXXXXX")"

cleanup() {
  rm -rf "$smoke_tmp"
}
trap cleanup EXIT

check_igdb() {
  local label="$1"
  local base_url="$2"
  local health_file="$smoke_tmp/${label}-health.json"
  local games_file="$smoke_tmp/${label}-games.json"

  echo "Checking IGDB ${label}: ${base_url}"
  curl --fail --silent --show-error \
    --connect-timeout 5 --max-time "$timeout_seconds" \
    "${base_url}/health" >"$health_file"
  rg -q '"status"[[:space:]]*:[[:space:]]*"(ok|healthy)"' "$health_file" || {
    echo "IGDB ${label} health response did not report ok/healthy." >&2
    return 1
  }

  curl --fail --silent --show-error \
    --connect-timeout 5 --max-time "$timeout_seconds" \
    --header 'Content-Type: application/json' \
    --data '{"steamIds":[570],"forceRefresh":false,"language":"en"}' \
    "${base_url}/api/games" >"$games_file"
  rg -q '"games"[[:space:]]*:' "$games_file"
  rg -q '"steamId"[[:space:]]*:[[:space:]]*570' "$games_file" || {
    echo "IGDB ${label} contract did not return Steam app 570." >&2
    return 1
  }
}

check_igdb local "$local_url"
check_igdb public "$public_url"

if [[ -n "${NEXTPLAY_STEAM_API_KEY:-}" && -n "${NEXTPLAY_STEAM_ID:-}" ]]; then
  echo "Checking Steam owned-games contract with redacted credentials."
  steam_file="$smoke_tmp/steam.json"
  curl --fail --silent --show-error \
    --connect-timeout 5 --max-time "$timeout_seconds" \
    --get 'https://api.steampowered.com/IPlayerService/GetOwnedGames/v1/' \
    --data-urlencode "key=${NEXTPLAY_STEAM_API_KEY}" \
    --data-urlencode "steamid=${NEXTPLAY_STEAM_ID}" \
    --data-urlencode 'include_appinfo=true' >"$steam_file"
  rg -q '"response"[[:space:]]*:' "$steam_file"
  rg -q '"game_count"[[:space:]]*:' "$steam_file"

  echo "Checking Steam software-catalog contract for 3DMark."
  software_file="$smoke_tmp/steam-software.json"
  curl --fail --silent --show-error \
    --connect-timeout 5 --max-time "$timeout_seconds" \
    --get 'https://api.steampowered.com/IStoreService/GetAppList/v1/' \
    --data-urlencode "key=${NEXTPLAY_STEAM_API_KEY}" \
    --data-urlencode 'include_games=false' \
    --data-urlencode 'include_dlc=false' \
    --data-urlencode 'include_software=true' \
    --data-urlencode 'include_videos=false' \
    --data-urlencode 'include_hardware=false' \
    --data-urlencode 'max_results=50000' >"$software_file"
  rg -q '"appid"[[:space:]]*:[[:space:]]*223850' "$software_file" || {
    echo "Steam software catalog did not classify app 223850 (3DMark)." >&2
    exit 1
  }
else
  echo "Steam live smoke skipped: set NEXTPLAY_STEAM_API_KEY and NEXTPLAY_STEAM_ID to opt in."
fi

echo "Live service smoke checks passed."
