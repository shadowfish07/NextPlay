#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

package_name="me.zqydev.nextplay.debug"
avd_name="${NEXTPLAY_AVD:-NextPlay_E2E_API_36}"
boot_timeout="${NEXTPLAY_ANDROID_BOOT_TIMEOUT_SECONDS:-180}"
started_emulator=0
device="${NEXTPLAY_ANDROID_DEVICE:-}"
timestamp="$(date '+%Y%m%d-%H%M%S')"
artifact_dir="$repo_root/.artifacts/e2e/$timestamp"
mkdir -p "$artifact_dir"

require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Required command not found: $1" >&2
    exit 1
  }
}

require_command adb
require_command flutter
require_command rg

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

collect_artifacts() {
  local exit_code=$?
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
  if (( started_emulator == 1 )) && [[ -n "$device" ]]; then
    adb -s "$device" emu kill >/dev/null
  fi
  if (( exit_code != 0 )); then
    echo "Android E2E failed; artifacts: $artifact_dir" >&2
  else
    echo "Android E2E passed; artifacts: $artifact_dir"
  fi
  exit "$exit_code"
}
trap collect_artifacts EXIT

if [[ -n "$device" ]]; then
  adb -s "$device" get-state >/dev/null
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
  started_emulator=1

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

echo "Using Android device: $device"
adb -s "$device" shell pm clear "$package_name" >/dev/null 2>&1 || true
adb -s "$device" uninstall "$package_name" >/dev/null 2>&1 || true
flutter test integration_test/app_flow_test.dart -d "$device"

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

launcher_ready=0
for _ in {1..30}; do
  adb -s "$device" shell uiautomator dump /sdcard/nextplay-launch.xml >/dev/null 2>&1 || true
  adb -s "$device" pull /sdcard/nextplay-launch.xml "$artifact_dir/launcher-ui.xml" >/dev/null 2>&1 || true
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
