#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
./Scripts/prepare-sparkle.sh
SPARKLE='build/Dependencies/Sparkle-2.10.0'
APP='build/cladofold..app'
VERSION=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP/Contents/Info.plist")
BUILD=$(/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' "$APP/Contents/Info.plist")
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo 'Expected a numeric release version.' >&2; exit 1; }
NAME="cladofold.-$VERSION-universal-notarized"
ARCHIVE="dist/$NAME.dmg"
PUBLIC_KEY=$(/usr/libexec/PlistBuddy -c 'Print SUPublicEDKey' "$APP/Contents/Info.plist")
SIGNING_KEY=$("$SPARKLE/bin/generate_keys" --account com.dante.Foldable.sparkle -p)
[ "$PUBLIC_KEY" = "$SIGNING_KEY" ] || { echo 'The update signing key does not match this app.' >&2; exit 1; }
codesign --verify --deep --strict "$APP"
xcrun stapler validate "$ARCHIVE"
spctl --assess --type open --context context:primary-signature "$ARCHIVE"
STAGING=$(mktemp -d build/update-feed.XXXXXX)
trap 'rm -rf "$STAGING"' EXIT
cp "$ARCHIVE" "$STAGING/$NAME.dmg"
if [ -f website/public/appcast.xml ]; then cp website/public/appcast.xml "$STAGING/appcast.xml"; fi
if [ "$#" -gt 0 ]; then cp "$1" "$STAGING/$NAME.txt"; fi
"$SPARKLE/bin/generate_appcast" --account com.dante.Foldable.sparkle \
    --download-url-prefix "https://github.com/Dantease/cladofold/releases/download/v$VERSION-preview/" \
    --link 'https://cladofold.app/' --embed-release-notes --maximum-deltas 0 \
    -o "$STAGING/appcast.xml" "$STAGING"
"$SPARKLE/bin/sign_update" --account com.dante.Foldable.sparkle --verify "$STAGING/appcast.xml"
node Scripts/verify-update-feed.mjs --public-key "$PUBLIC_KEY" --feed "$STAGING/appcast.xml" \
    --version "$BUILD" --short-version "$VERSION" "$ARCHIVE"
cp "$STAGING/appcast.xml" website/public/appcast.xml
printf 'Generated signed update feed for %s (build %s). Publish the release assets before deploying this feed.\n' "$VERSION" "$BUILD"
