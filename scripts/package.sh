#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
app=dist/CodexBattery.app
[[ -d "$app" ]] || scripts/build.sh
codesign --verify --deep --strict "$app"
python3 - <<'PY'
from pathlib import Path
import re
app = Path('dist/CodexBattery.app')
patterns = [rb'/Users/', rb'gh[pousr]_[A-Za-z0-9]{20,}', rb'github_pat_[A-Za-z0-9_]{20,}', rb'-----BEGIN .*PRIVATE KEY-----']
for path in app.rglob('*'):
    if path.is_symlink(): raise SystemExit('Unexpected symlink in release bundle')
    if path.is_file():
        data = path.read_bytes()
        if any(re.search(pattern, data) for pattern in patterns):
            raise SystemExit('Release privacy scan failed: ' + path.name)
        if path.name in {'snapshot.json', 'auth.json', '.env'} or path.suffix in {'.log', '.p12', '.pem', '.key'}:
            raise SystemExit('Unexpected private file in bundle: ' + path.name)
print('PASS: release bundle privacy scan')
PY
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")
archive="CodexBattery-${version}-macOS-universal.zip"
# Exclude resource forks, extended attributes and quarantine metadata.
ditto -c -k --keepParent --norsrc --noextattr --noqtn "$app" "dist/$archive"
(cd dist && shasum -a 256 "$archive" > SHA256SUMS)
printf 'Packaged: dist/%s\n' "$archive"
