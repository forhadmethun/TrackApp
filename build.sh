#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="TrackApp"
APP_BUNDLE="$(pwd)/$APP_NAME.app"
INSTALL_PATH="/Applications/$APP_NAME.app"

echo "==> Building $APP_NAME (release)"
swift build -c release

BIN_PATH="$(swift build -c release --show-bin-path)"
EXECUTABLE="$BIN_PATH/$APP_NAME"

if [ ! -f "$EXECUTABLE" ]; then
    echo "ERROR: executable not found at $EXECUTABLE"
    exit 1
fi

echo "==> Assembling app bundle"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$EXECUTABLE" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp "Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

echo "==> Ad-hoc signing"
codesign --force --deep --sign - "$APP_BUNDLE"

echo "==> Installing to $INSTALL_PATH"
# Kill any running instance first so the copy doesn't fail on a locked binary.
pkill -f "$INSTALL_PATH/Contents/MacOS/$APP_NAME" 2>/dev/null || true
sleep 0.5
rm -rf "$INSTALL_PATH"
cp -r "$APP_BUNDLE" "$INSTALL_PATH"

echo ""
echo "Installed: $INSTALL_PATH"
echo ""
echo "Launch now:"
echo "    open \"$INSTALL_PATH\""
