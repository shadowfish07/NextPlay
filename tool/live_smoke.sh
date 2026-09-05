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
  local check_ratings="${3:-false}"
  local health_file="$smoke_tmp/${label}-health.json"
  local games_file="$smoke_tmp/${label}-games.json"
  local localizations_file="$smoke_tmp/${label}-localizations.json"
  local rating_file="$smoke_tmp/${label}-rating.json"

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

  curl --fail --silent --show-error \
    --connect-timeout 5 --max-time "$timeout_seconds" \
    --header 'Content-Type: application/json' \
    --data '{"steamIds":[620],"language":"zh-CN"}' \
    "${base_url}/api/localizations" >"$localizations_file"
  rg -q '"items"[[:space:]]*:' "$localizations_file"
  rg -q '"status"[[:space:]]*:' "$localizations_file"
  rg -q '"requested"[[:space:]]*:[[:space:]]*1' "$localizations_file" || {
    echo "IGDB ${label} localization contract did not accept Steam app 620." >&2
    return 1
  }

  if [[ "$check_ratings" == "true" ]]; then
    curl --fail --silent --show-error \
      --connect-timeout 5 --max-time "$timeout_seconds" \
      "${base_url}/api/ratings/620" >"$rating_file"
    rg -q '"steamId"[[:space:]]*:[[:space:]]*620' "$rating_file" || {
      echo "IGDB ${label} VGC contract did not return Steam app 620." >&2
      return 1
    }
    rg -q '"status"[[:space:]]*:[[:space:]]*"(scored|early_access)"' \
      "$rating_file" || {
      echo "IGDB ${label} VGC contract did not return a supported rating state." >&2
      return 1
    }
    rg -q '"sourceUrl"[[:space:]]*:[[:space:]]*"https://videogamescritic\.com/game/620"' \
      "$rating_file" || {
      echo "IGDB ${label} VGC contract returned an unexpected source URL." >&2
      return 1
    }
  fi
}

check_igdb local "$local_url" true
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
