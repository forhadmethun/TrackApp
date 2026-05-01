#!/usr/bin/env bash
# Generates Resources/AppIcon.icns from scratch.
# Run once (or whenever the icon design changes).
# Requires: swift, sips, iconutil (all ship with Xcode on macOS)
set -euo pipefail
cd "$(dirname "$0")/.."

SRC="/tmp/icon_1024.png"
ICONSET="Resources/AppIcon.iconset"

echo "==> Rendering icon…"
swift Scripts/generate_icon.swift "$SRC"

echo "==> Building iconset…"
rm -rf "$ICONSET"
mkdir -p "$ICONSET"

sips -z 16   16   "$SRC" --out "$ICONSET/icon_16x16.png"        &>/dev/null
sips -z 32   32   "$SRC" --out "$ICONSET/icon_16x16@2x.png"     &>/dev/null
sips -z 32   32   "$SRC" --out "$ICONSET/icon_32x32.png"         &>/dev/null
sips -z 64   64   "$SRC" --out "$ICONSET/icon_32x32@2x.png"     &>/dev/null
sips -z 128  128  "$SRC" --out "$ICONSET/icon_128x128.png"       &>/dev/null
sips -z 256  256  "$SRC" --out "$ICONSET/icon_128x128@2x.png"   &>/dev/null
sips -z 256  256  "$SRC" --out "$ICONSET/icon_256x256.png"       &>/dev/null
sips -z 512  512  "$SRC" --out "$ICONSET/icon_256x256@2x.png"   &>/dev/null
sips -z 512  512  "$SRC" --out "$ICONSET/icon_512x512.png"       &>/dev/null
sips -z 1024 1024 "$SRC" --out "$ICONSET/icon_512x512@2x.png"   &>/dev/null

echo "==> Packing .icns…"
iconutil -c icns "$ICONSET" -o "Resources/AppIcon.icns"
rm -rf "$ICONSET" "$SRC"

echo "Done → Resources/AppIcon.icns"
