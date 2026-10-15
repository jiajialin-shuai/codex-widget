#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ -z "${DEVELOPER_DIR:-}" && -d /Applications/Xcode-beta.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
fi
mkdir -p build
xcrun swiftc -O Sources/Shared/UsageSnapshot.swift Sources/Shared/SnapshotRequest.swift Sources/App/CodexClient.swift Tests/main.swift -o build/verify
build/verify "$@"
