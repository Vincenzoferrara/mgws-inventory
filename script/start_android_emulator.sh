#!/usr/bin/env bash

# Start a local Android AVD and wait until the boot completes.
set -euo pipefail

AVD_NAME="${1:-pixel_36}"
ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-/opt/android-sdk}}"
EMULATOR="$ANDROID_SDK_ROOT/emulator/emulator"
ADB="$ANDROID_SDK_ROOT/platform-tools/adb"
EMULATOR_LOG="${TMPDIR:-/tmp}/flutter-android-emulator-${AVD_NAME}.log"

if [[ ! -x "$EMULATOR" || ! -x "$ADB" ]]; then
  echo "Local Android SDK not found in: $ANDROID_SDK_ROOT" >&2
  echo "Set ANDROID_SDK_ROOT or install emulator and platform-tools." >&2
  exit 1
fi

if ! "$EMULATOR" -list-avds | grep -Fxq "$AVD_NAME"; then
  echo "AVD '$AVD_NAME' not found. Available AVDs:" >&2
  "$EMULATOR" -list-avds >&2
  exit 1
fi

"$ADB" start-server >/dev/null

wait_for_android_boot() {
  timeout 180 "$ADB" wait-for-device
  timeout 180 bash -c "until '$ADB' shell getprop sys.boot_completed 2>/dev/null | grep -qx '1'; do sleep 2; done"
  "$ADB" shell getprop ro.build.version.sdk >/dev/null
}

configure_reverse_proxy() {
  for port in 8080 8081; do
    "$ADB" reverse "tcp:$port" "tcp:$port"
  done
  echo "ADB forwarding active: localhost:8080 and localhost:8081 on the emulator point to the PC." 
}

if "$ADB" devices | awk 'NR > 1 && $1 ~ /^emulator-/ && $2 == "device" { found = 1 } END { exit !found }'; then
  echo "An Android emulator is already running."
  echo "Checking whether Android is ready..."
  wait_for_android_boot
  configure_reverse_proxy
  exit 0
fi

echo "Starting local Android emulator '$AVD_NAME'..."
# setsid separates the emulator from the VS Code task: the task can terminate
# without sending its own stop signal to the emulator process.
setsid --fork "$EMULATOR" -avd "$AVD_NAME" -no-snapshot-load >"$EMULATOR_LOG" 2>&1

echo "Waiting for boot to complete..."
wait_for_android_boot

echo "Emulator '$AVD_NAME' is ready."
configure_reverse_proxy
