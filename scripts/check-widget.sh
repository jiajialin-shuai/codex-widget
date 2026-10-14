#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ -z "${DEVELOPER_DIR:-}" && -d /Applications/Xcode-beta.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
fi
probe=build/WidgetProbe.app
mkdir -p "$probe/Contents/MacOS"
xcrun swiftc -O -parse-as-library Sources/Shared/UsageSnapshot.swift Sources/Shared/WidgetSnapshotLoader.swift \
    Tools/WidgetProbe/main.swift -o "$probe/Contents/MacOS/WidgetProbe"
cp Resources/Widget-Info.plist "$probe/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier com.jiajialin.codexbattery.widgetprobe' "$probe/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleExecutable WidgetProbe' "$probe/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Delete :NSExtension' "$probe/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundlePackageType APPL' "$probe/Contents/Info.plist"
codesign --force --sign - --entitlements Resources/Widget.entitlements "$probe"
"$probe/Contents/MacOS/WidgetProbe" "$@"
