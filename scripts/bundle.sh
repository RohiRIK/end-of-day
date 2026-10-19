#!/bin/bash
# Release build wrapped in build/EndOfDay.app and ad-hoc signed.
set -euo pipefail
cd "$(dirname "$0")/.."

APP="build/EndOfDay.app"
swift build -c release --product EndOfDay
BIN="$(swift build -c release --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/EndOfDay" "$APP/Contents/MacOS/EndOfDay"
cp Resources/Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"
echo "$APP"
