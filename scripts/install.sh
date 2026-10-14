#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
[[ -d dist/CodexBattery.app ]] || scripts/build.sh
target="${1:-$HOME/Applications}"
mkdir -p "$target"
if pgrep -x CodexBattery >/dev/null; then
  pkill -x CodexBattery
  for ((i=0; i<50; i++)); do pgrep -x CodexBattery >/dev/null || break; sleep 0.1; done
fi
ditto dist/CodexBattery.app "$target/CodexBattery.app"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$target/CodexBattery.app"
pluginkit -a "$target/CodexBattery.app/Contents/PlugIns/CodexBatteryWidget.appex"
# Keep the installed extension as the only development copy registered.
pluginkit -r "$PWD/build/DerivedData/Build/Products/Release/CodexBattery.app/Contents/PlugIns/CodexBatteryWidget.appex" 2>/dev/null || true
pluginkit -r "$PWD/dist/CodexBattery.app/Contents/PlugIns/CodexBatteryWidget.appex" 2>/dev/null || true
open "$target/CodexBattery.app"
printf 'Installed: %s/CodexBattery.app\n' "$target"
