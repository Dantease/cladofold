#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
APP='build/cladofold..app'
test -d "$APP"
if pgrep -x Foldable >/dev/null || pgrep -x cladofold >/dev/null; then
    echo 'Quit cladofold. (or Foldable) before installing. Also quit System Settings if its pane is open.' >&2
    exit 1
fi
codesign --verify --deep --strict "$APP"
BACKUP="build/install-backups/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP" "$HOME/Applications" "$HOME/Library/PreferencePanes"
# Retain restorable ZIPs and touch only bundles owned by this app.
for OLD in "$HOME/Applications/Foldable.app" "$HOME/Applications/cladofold..app" "$HOME/Library/PreferencePanes/Foldable.prefPane"; do
    if [ -d "$OLD" ]; then
        ID=$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$OLD/Contents/Info.plist")
        case "$ID" in com.dante.Foldable|com.dante.Foldable.Settings) ;;
            *) echo "Refusing to replace unrelated bundle: $OLD" >&2; exit 1 ;;
        esac
        ditto -c -k --sequesterRsrc --keepParent "$OLD" "$BACKUP/$(basename "$OLD").zip"
    fi
done
STAGING="$HOME/Applications/.cladofold-install-$$.app"
trap 'rm -rf "$STAGING"' EXIT
ditto "$APP" "$STAGING"
codesign --verify --deep --strict "$STAGING"
# ZIP backups above make the rename and replacement reversible.
rm -rf "$HOME/Applications/Foldable.app" "$HOME/Applications/cladofold..app" "$HOME/Library/PreferencePanes/Foldable.prefPane"
mv "$STAGING" "$HOME/Applications/cladofold..app"
printf 'Installed cladofold. in ~/Applications. Open it to install the System Settings pane.\nBackups: %s\n' "$BACKUP"
