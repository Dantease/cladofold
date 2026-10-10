#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
SPARKLE_ROOT=$(./Scripts/prepare-sparkle.sh)
TEST_APP='build/updater-tests.app'
mkdir -p "$TEST_APP/Contents/MacOS" build/ModuleCache
python3 - <<'PY'
import plistlib
from pathlib import Path
info = plistlib.loads(Path('Resources/App-Info.plist').read_bytes())
info['CFBundleIdentifier'] = 'com.dante.cladofold.UpdaterPolicyTests'
info['CFBundleExecutable'] = 'updater-tests'
info['CFBundleName'] = 'Updater Policy Tests'
info['CFBundleDisplayName'] = 'Updater Policy Tests'
Path('build/updater-tests.app/Contents/Info.plist').write_bytes(plistlib.dumps(info))
PY
swiftc -swift-version 5 -module-cache-path build/ModuleCache -F "$SPARKLE_ROOT" -framework Sparkle \
    -Xlinker -rpath -Xlinker "$SPARKLE_ROOT" \
    Sources/App/AppUpdater.swift Tests/Updates/main.swift -o "$TEST_APP/Contents/MacOS/updater-tests"
"$TEST_APP/Contents/MacOS/updater-tests" --policy
