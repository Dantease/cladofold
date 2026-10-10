#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Python's plist parser keeps feed checks aligned with the shipped public key
# and monotonically increasing bundle version, without needing a signing key.
read_plist() {
    python3 - "$1" <<'PY'
import plistlib, sys
with open('Resources/App-Info.plist', 'rb') as source:
    print(plistlib.load(source)[sys.argv[1]])
PY
}
node Scripts/verify-update-feed.mjs --public-key "$(read_plist SUPublicEDKey)" \
    --feed website/public/appcast.xml --version "$(read_plist CFBundleVersion)" \
    --short-version "$(read_plist CFBundleShortVersionString)" "$@"
