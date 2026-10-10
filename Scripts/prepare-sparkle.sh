#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

SPARKLE_VERSION='2.10.0'
SPARKLE_SHA256='c2bf58aa8387266ac179357b1415d6f2635f044da8be41042af32425dae6da0c'
SPARKLE_URL="https://github.com/sparkle-project/Sparkle/releases/download/$SPARKLE_VERSION/Sparkle-$SPARKLE_VERSION.tar.xz"
DEPENDENCIES="$PWD/build/Dependencies"
ARCHIVE="$DEPENDENCIES/Sparkle-$SPARKLE_VERSION.tar.xz"
DESTINATION="$DEPENDENCIES/Sparkle-$SPARKLE_VERSION"
DOWNLOAD=''
STAGING=''
cleanup() {
    if [ -n "$DOWNLOAD" ]; then rm -f "$DOWNLOAD"; fi
    if [ -n "$STAGING" ]; then rm -rf "$STAGING"; fi
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
mkdir -p "$DEPENDENCIES"

verify_archive() {
    [ -f "$1" ] && [ "$(shasum -a 256 "$1" | awk '{print $1}')" = "$SPARKLE_SHA256" ]
}

if ! verify_archive "$ARCHIVE"; then
    DOWNLOAD=$(mktemp "$DEPENDENCIES/.Sparkle-download.XXXXXX")
    echo "Downloading pinned Sparkle $SPARKLE_VERSION" >&2
    curl --fail --silent --show-error --location --proto '=https' --proto-redir '=https' \
        --retry 3 --connect-timeout 30 --max-time 300 "$SPARKLE_URL" -o "$DOWNLOAD"
    if ! verify_archive "$DOWNLOAD"; then
        echo 'Sparkle archive SHA-256 mismatch; refusing to extract it.' >&2
        exit 1
    fi
    mv -f "$DOWNLOAD" "$ARCHIVE"
    DOWNLOAD=''
fi

# Always extract the verified archive, so a partial or modified extracted cache
# cannot silently become a build dependency. Only publish a complete extraction.
STAGING=$(mktemp -d "$DEPENDENCIES/.Sparkle-extract.XXXXXX")
tar -xJf "$ARCHIVE" -C "$STAGING"
test -f "$STAGING/Sparkle.framework/Sparkle"
test -f "$STAGING/Sparkle.framework/Headers/SPUStandardUpdaterController.h"
test -x "$STAGING/bin/sign_update"
rm -rf "$DESTINATION"
mv "$STAGING" "$DESTINATION"
STAGING=''
printf '%s\n' "$DESTINATION"
