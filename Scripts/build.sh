#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
APP='build/cladofold..app'
PANE='build/cladofold..prefPane'
if [ "${CODE_SIGN_IDENTITY+x}" = x ]; then
    IDENTITY="${CODE_SIGN_IDENTITY:--}"
else
    # TCC associates Screen Recording access with the app's signing
    # requirement. Prefer the stable distribution identity when it is
    # available so local rebuilds do not leave an enabled-but-obsolete entry
    # in System Settings. CI and contributors without a certificate still get
    # an ad-hoc build.
    AVAILABLE_IDENTITIES=$(security find-identity -v -p codesigning 2>/dev/null || true)
    IDENTITY=$(printf '%s\n' "$AVAILABLE_IDENTITIES" |
        sed -n 's/.*"\(Developer ID Application:.*\)"/\1/p' | sed -n '1p')
    if [ -z "$IDENTITY" ]; then
        IDENTITY=$(printf '%s\n' "$AVAILABLE_IDENTITIES" |
            sed -n 's/.*"\(Apple Development:.*\)"/\1/p' | sed -n '1p')
    fi
    if [ -z "$IDENTITY" ]; then
        IDENTITY='-'
        echo 'warning: no stable signing identity found; Screen Recording permission may need to be granted again after a rebuild' >&2
    fi
fi
mkdir -p build/ModuleCache build/architectures "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/PlugIns" "$PANE/Contents/MacOS" "$PANE/Contents/Resources"
# Compile both slices, regardless of the build machine's processor.
for ARCH in arm64 x86_64; do
    SWIFT_FLAGS=(-swift-version 5 -target "$ARCH-apple-macos14.0" -module-cache-path build/ModuleCache -O)
    swiftc "${SWIFT_FLAGS[@]}" Sources/Shared/*.swift Sources/App/*.swift -o "build/architectures/cladofold-$ARCH"
    swiftc "${SWIFT_FLAGS[@]}" -emit-library -module-name CladofoldPane -Xlinker -install_name -Xlinker '@rpath/CladofoldPane' Sources/Shared/*.swift Sources/PreferencePane/*.swift -o "build/architectures/CladofoldPane-$ARCH"
done
lipo -create build/architectures/cladofold-arm64 build/architectures/cladofold-x86_64 -output "$APP/Contents/MacOS/cladofold"
lipo -create build/architectures/CladofoldPane-arm64 build/architectures/CladofoldPane-x86_64 -output "$PANE/Contents/MacOS/CladofoldPane"
cp Resources/App-Info.plist "$APP/Contents/Info.plist"
cp Resources/Pane-Info.plist "$PANE/Contents/Info.plist"
swiftc -swift-version 5 -module-cache-path build/ModuleCache -O Scripts/MakeIcon.swift -o build/make-icon
build/make-icon build/cladofold-cf.iconset
cp build/cladofold-cf.icns "$APP/Contents/Resources/"
cp build/cladofold-cf.icns "$PANE/Contents/Resources/"
rm -f "$APP/Contents/Resources/cladofold.icns" "$PANE/Contents/Resources/cladofold.icns"
SIGN_FLAGS=(--force --sign "$IDENTITY")
if [ "$IDENTITY" != '-' ]; then SIGN_FLAGS+=(--options runtime --timestamp); fi
codesign "${SIGN_FLAGS[@]}" "$PANE"
# Replace the embedded pane as a unit; never leave files from an older version.
rm -rf "$APP/Contents/PlugIns/cladofold..prefPane"
ditto "$PANE" "$APP/Contents/PlugIns/cladofold..prefPane"
codesign "${SIGN_FLAGS[@]}" "$APP"
codesign --verify --deep --strict "$APP"
if [ "$IDENTITY" = '-' ]; then
    echo 'Code signing: ad-hoc'
else
    echo "Code signing: $IDENTITY"
fi
lipo "$APP/Contents/MacOS/cladofold" -verify_arch arm64 x86_64
lipo "$PANE/Contents/MacOS/CladofoldPane" -verify_arch arm64 x86_64
VERSION=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP/Contents/Info.plist")
printf 'Built universal cladofold. %s (macOS 14.0+)\n' "$VERSION"
