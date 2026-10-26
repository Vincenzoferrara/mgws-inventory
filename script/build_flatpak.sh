#!/usr/bin/env bash

# Builds mgws_inventory.flatpak from the Linux release bundle.
# The release workflow runs it as it is, so a local run tests the same steps.
# Needs flutter, flatpak and flatpak-builder; the runtime and the SDK come
# from Flathub.
# Usage: script/build_flatpak.sh [--build-name X.Y.Z --build-number N]
# The bundle lands in build/mgws_inventory.flatpak; FLATPAK_WORK_DIR moves
# the flatpak-builder folders (build/flatpak by default).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_ID=io.github.vincenzoferrara.mgws-inventory
WORK_DIR="${FLATPAK_WORK_DIR:-$ROOT/build/flatpak}"
OUTPUT="$ROOT/build/mgws_inventory.flatpak"
FLATHUB_REPO=https://dl.flathub.org/repo/flathub.flatpakrepo

cd "$ROOT"

# FLATPAK_ID makes linux/CMakeLists.txt use the Flatpak ID as the GTK
# application ID. Flathub brings no updates to this bundle yet, but Velopack
# cannot replace files in /app: the update check stays off.
rm -rf build/linux/x64/release
FLATPAK_ID="$APP_ID" flutter build linux --release \
  --dart-define=UPDATE_CHECK=false "$@"

flatpak remote-add --user --if-not-exists flathub "$FLATHUB_REPO"
flatpak-builder --user --install-deps-from=flathub --force-clean \
  --disable-rofiles-fuse \
  --state-dir="$WORK_DIR/state" --repo="$WORK_DIR/repo" \
  "$WORK_DIR/build" "linux/packaging/$APP_ID.yml"

# --runtime-repo lets `flatpak install` fetch the runtime from Flathub.
flatpak build-bundle --runtime-repo="$FLATHUB_REPO" \
  "$WORK_DIR/repo" "$OUTPUT" "$APP_ID"
echo "Flatpak: $OUTPUT"
