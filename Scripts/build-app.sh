#!/bin/bash
# Builds Daybook.app with SwiftPM only — no Xcode required.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release

APP="dist/Daybook.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/Daybook "$APP/Contents/MacOS/Daybook"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/Daybook.icns "$APP/Contents/Resources/Daybook.icns"

codesign --force --sign - "$APP"

echo "Built $APP"
du -sh "$APP" | awk '{print "Bundle size: " $1}'
