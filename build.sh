#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="TrackApp"
APP_BUNDLE="$(pwd)/$APP_NAME.app"

echo "==> Building $APP_NAME (release)"
swift build -c release

BIN_PATH="$(swift build -c release --show-bin-path)"
EXECUTABLE="$BIN_PATH/$APP_NAME"

if [ ! -f "$EXECUTABLE" ]; then
    echo "ERROR: executable not found at $EXECUTABLE"
    exit 1
fi

echo "==> Assembling app bundle at $APP_BUNDLE"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$EXECUTABLE" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp "Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

echo "==> Ad-hoc signing"
codesign --force --deep --sign - "$APP_BUNDLE"

echo ""
echo "Built: $APP_BUNDLE"
echo ""
echo "Launch:    open \"$APP_BUNDLE\""
echo "Install:   mv \"$APP_BUNDLE\" /Applications/"
