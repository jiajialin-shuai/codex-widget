#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ -z "${DEVELOPER_DIR:-}" && -d /Applications/Xcode-beta.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
fi
command -v xcodegen >/dev/null || { echo 'Install XcodeGen: brew install xcodegen' >&2; exit 1; }
xcodegen generate
mkdir -p build
if ! xcodebuild -project CodexBattery.xcodeproj -scheme CodexBattery -configuration Release \
    -derivedDataPath build/DerivedData CODE_SIGN_IDENTITY=- build >build/build.log 2>&1; then
  tail -80 build/build.log >&2
  exit 1
fi
mkdir -p dist
ditto build/DerivedData/Build/Products/Release/CodexBattery.app dist/CodexBattery.app
# Remove linker debug maps/local symbols containing the builder's absolute paths.
for binary in dist/CodexBattery.app/Contents/MacOS/CodexBattery \
    dist/CodexBattery.app/Contents/PlugIns/CodexBatteryWidget.appex/Contents/MacOS/CodexBatteryWidget; do
  xcrun strip -S -x "$binary"
done
codesign --force --sign - --preserve-metadata=identifier,entitlements,flags \
  dist/CodexBattery.app/Contents/PlugIns/CodexBatteryWidget.appex
codesign --force --sign - --preserve-metadata=identifier,entitlements,flags dist/CodexBattery.app
codesign --verify --deep --strict dist/CodexBattery.app
printf 'Built: %s/dist/CodexBattery.app\n' "$PWD"
