#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ -z "${DEVELOPER_DIR:-}" && -d /Applications/Xcode-beta.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
fi
mkdir -p build
xcrun swiftc -O -parse-as-library Sources/Shared/*.swift Tools/Render/main.swift -o build/render
build/render "${1:-build/previews}"
