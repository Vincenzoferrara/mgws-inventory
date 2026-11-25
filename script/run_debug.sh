#!/usr/bin/env bash

# Start a local debug build with a debug-only build counter.
# The number does not modify pubspec.yaml or CI/GitHub releases: it is passed
# only through --dart-define and is shown by the app only in debug builds (kDebugMode).
# Usage: script/run_debug.sh -d emulator-5554 [additional flutter run arguments]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COUNTER="$ROOT/.debug_build_nr"

n=0
if [[ -f "$COUNTER" ]]; then
  n="$(cat "$COUNTER")"
fi
[[ "$n" =~ ^[0-9]+$ ]] || n=0
n=$((n + 1))
echo "$n" >"$COUNTER"

echo "Local debug build #$n"
exec flutter run --dart-define="DEBUG_BUILD_NR=$n" "$@"
