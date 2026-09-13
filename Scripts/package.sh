#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
MODE="${1:---preview}"
case "$MODE" in
  --preview) unset CODE_SIGN_IDENTITY; CHANNEL='preview' ;;
  --notarize)
    : "${CODE_SIGN_IDENTITY:?Set a Developer ID Application identity}"
    : "${NOTARY_PROFILE:?Set the name of an existing notarytool keychain profile}"
    [[ "$CODE_SIGN_IDENTITY" == 'Developer ID Application: '* ]] || { echo 'A Developer ID Application certificate is required.' >&2; exit 1; }
    CHANNEL='notarized' ;;
  *) echo 'Usage: Scripts/package.sh [--preview|--notarize]' >&2; exit 1 ;;
esac
./Scripts/build.sh
APP='build/cladofold..app'
VERSION=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP/Contents/Info.plist")
NAME="cladofold.-$VERSION-universal-$CHANNEL"
STAGE="build/$NAME"
mkdir -p dist
rm -rf "$STAGE"
mkdir -p "$STAGE"
if [ "$MODE" = '--notarize' ]; then
    ditto -c -k --sequesterRsrc --keepParent "$APP" build/notary-submission.zip
    xcrun notarytool submit build/notary-submission.zip --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$APP"
    xcrun stapler validate "$APP"
    spctl --assess --type execute --verbose "$APP"
fi
ditto "$APP" "$STAGE/cladofold..app"
cp Distribution/READ-ME.txt "$STAGE/READ ME.txt"
if [ "$MODE" = '--notarize' ]; then
    python3 - "$STAGE/READ ME.txt" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1]); s = p.read_text().replace('1.3.0 — preview', '1.3.0')
a = s.index('THIS IS AN UNNOTARIZED PREVIEW'); b = s.index('\nREQUIREMENTS', a)
s = s[:a] + 'APPLE NOTARIZATION\nThis release is signed with Developer ID and notarized by Apple. macOS will\nask whether you want to open the downloaded app on first launch.\n' + s[b:]
p.write_text(s)
PY
fi
ln -s /Applications "$STAGE/Applications"
hdiutil create -ov -volname 'cladofold.' -srcfolder "$STAGE" -format UDZO "dist/$NAME.dmg"
if [ "$MODE" = '--notarize' ]; then
    codesign --force --sign "$CODE_SIGN_IDENTITY" --timestamp "dist/$NAME.dmg"
    xcrun notarytool submit "dist/$NAME.dmg" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "dist/$NAME.dmg"
    xcrun stapler validate "dist/$NAME.dmg"
fi
# ZIP contains a single named folder, with the app and the same installation guide.
rm "$STAGE/Applications"
rm -f "dist/$NAME.zip"
ditto -c -k --sequesterRsrc --keepParent "$STAGE" "dist/$NAME.zip"
(cd dist && shasum -a 256 "$NAME.dmg" "$NAME.zip" > "$NAME-SHA256.txt")
printf 'Shareable files: dist/%s.{dmg,zip}\n' "$NAME"
