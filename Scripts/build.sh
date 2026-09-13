#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
APP='build/cladofold..app'
PANE='build/cladofold..prefPane'
IDENTITY="${CODE_SIGN_IDENTITY:--}"
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
lipo "$APP/Contents/MacOS/cladofold" -verify_arch arm64 x86_64
lipo "$PANE/Contents/MacOS/CladofoldPane" -verify_arch arm64 x86_64
VERSION=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP/Contents/Info.plist")
printf 'Built universal cladofold. %s (macOS 14.0+)\n' "$VERSION"
