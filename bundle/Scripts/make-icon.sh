#!/bin/sh
# Gives the app the game's own icon, built from sinking_star.exe once Steam has fully
# installed the game. Runs once; uses only tools that ship with macOS (perl, JavaScript
# for Automation, iconutil). The icon isn't bundled with the installer because it's
# the game's artwork.
#
# Usage: make-icon.sh <bundle Contents folder>
CONTENTSFOLD="$1"
APP=$(dirname "$CONTENTSFOLD")
SCRIPTS="$CONTENTSFOLD/Resources/Scripts"
ICNS="$CONTENTSFOLD/Resources/GameIcon.icns"
STEAMAPPS="$CONTENTSFOLD/SharedSupport/prefix/drive_c/Program Files (x86)/Steam/steamapps"
EXE="$STEAMAPPS/common/Order of the Sinking Star/sinking_star.exe"

[ -f "$ICNS" ] && exit 0
# StateFlags 4 = fully installed, so a half-downloaded exe is never read.
grep -Eq '"StateFlags"[[:space:]]+"4"' "$STEAMAPPS/appmanifest_499170.acf" 2>/dev/null || exit 0
[ -f "$EXE" ] || exit 0

TMP=$(mktemp -d) || exit 1
trap 'rm -rf "$TMP"' EXIT
mkdir "$TMP/GameIcon.iconset"
/usr/bin/perl "$SCRIPTS/extract-exe-icon.pl" "$EXE" "$TMP/game.ico" &&
    /usr/bin/osascript -l JavaScript "$SCRIPTS/compose-icon.js" "$TMP/game.ico" "$TMP/GameIcon.iconset" &&
    /usr/bin/iconutil -c icns "$TMP/GameIcon.iconset" -o "$TMP/GameIcon.icns" || exit 1

mv "$TMP/GameIcon.icns" "$ICNS"
/usr/bin/plutil -replace CFBundleIconFile -string GameIcon "$CONTENTSFOLD/Info.plist"
# Make Finder and the Dock pick up the new icon.
touch "$APP"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP"
