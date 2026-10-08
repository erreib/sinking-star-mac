#!/bin/zsh
# Builds dist/Install Order of the Sinking Star.app (an AppleScript applet wrapping
# install.sh and bundle/) plus a zip for GitHub Releases.
#
#   ./make-installer-app.sh                  release build
#   ./make-installer-app.sh --test-dest DIR  test build that installs into DIR
#
# The app is only ad-hoc signed, so people who download it get macOS's "Open Anyway"
# step (System Settings > Privacy & Security). Re-signing after adding resources keeps
# the bundle seal valid; otherwise macOS would call the download "damaged".
set -euo pipefail

REPO="${0:A:h}"
NAME="Install Order of the Sinking Star"
OUT="$REPO/dist"
TEST_DEST=""
[[ "${1:-}" == --test-dest ]] && TEST_DEST="$2"

APP="$OUT/$NAME.app"
rm -rf "$APP" "$OUT/$NAME.zip"
mkdir -p "$OUT"

src="$REPO/installer/Installer.applescript"
if [[ -n "$TEST_DEST" ]]; then
    src="$(mktemp -d)/Installer.applescript"
    sed "s|^property destDir : \"\"|property destDir : \"$TEST_DEST\"|" "$REPO/installer/Installer.applescript" > "$src"
fi
osacompile -o "$APP" "$src"

mkdir -p "$APP/Contents/Resources/installer"
cp "$REPO/install.sh" "$APP/Contents/Resources/installer/"
cp -R "$REPO/bundle" "$APP/Contents/Resources/installer/"

PLIST="$APP/Contents/Info.plist"
plutil -replace CFBundleIdentifier -string "local.installer.order-of-the-sinking-star" "$PLIST"
plutil -replace CFBundleName -string "$NAME" "$PLIST"
plutil -replace LSMinimumSystemVersion -string "15.0" "$PLIST"

codesign --force --deep --sign - "$APP"
codesign --verify --deep --strict "$APP"

if [[ -z "$TEST_DEST" ]]; then
    (cd "$OUT" && ditto -c -k --keepParent "$NAME.app" "$NAME.zip")
    echo "Built $OUT/$NAME.zip"
else
    echo "Built test installer (installs into $TEST_DEST): $APP"
fi
