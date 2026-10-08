#!/bin/zsh
# Builds "Order of the Sinking Star.app": a Sikarugir wrapper (Wine 11) with Apple's
# D3DMetal for DirectX 12, running the Windows Steam client. Everything is downloaded
# from its original source; the game itself is installed by Steam under your account.
#
#   ./install.sh                 build into ~/Applications
#   ./install.sh --dest DIR      build into DIR instead
#   ./install.sh --no-retina     run Wine at macOS point resolution (blurrier, faster;
#                                the default follows your main display)
set -euo pipefail

REPO="${0:A:h}"
APP_NAME="Order of the Sinking Star.app"
DEST="$HOME/Applications"
RETINA=auto

TEMPLATE_URL="https://github.com/Sikarugir-App/Template/releases/download/v1.0/Template-1.0.21.tar.xz"
TEMPLATE_SHA256="bbe996e4e4375318485953d0c7818b7b4b0a4dc1f13303bcc584f99f7602f78d"
ENGINE_URL="https://github.com/Sikarugir-App/Engines/releases/download/v1.0/WS12WineSikarugir11.0_1.tar.xz"
ENGINE_SHA256="67e29fb3d74f363af39c69ba11f9b13a79812c5db07cf4748672658e4a200a0e"
STEAM_URL="https://cdn.cloudflare.steamstatic.com/client/installer/SteamSetup.exe"

while (( $# )); do
    case "$1" in
        --dest) DEST="$2"; shift 2 ;;
        --no-retina) RETINA=no; shift ;;
        -h|--help) sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

step() { print -P "%B==>%b $1"; }
die() { print -P "%F{red}Error:%f $1" >&2; exit 1; }

# --- Preflight -----------------------------------------------------------------
[[ "$(sysctl -n hw.optional.arm64 2>/dev/null)" == 1 ]] || die "This needs an Apple Silicon Mac."
macos_major=$(sw_vers -productVersion | cut -d. -f1)
(( macos_major >= 15 )) || die "This needs macOS 15 Sequoia or later (D3DMetal 4)."
arch -x86_64 /usr/bin/true 2>/dev/null ||
    die "Rosetta 2 is required. Install it with: softwareupdate --install-rosetta --agree-to-license"
(( EUID != 0 )) || die "Run this as your normal user, not with sudo."
# Sikarugir's launcher waits until no Wine server is running anywhere before it
# finishes creating the prefix, so another Wine session would hang the install.
! pgrep -x wineserver >/dev/null ||
    die "Quit other Wine-based apps first (CrossOver, Whisky, other wrappers, or a running copy of this app)."

mkdir -p "$DEST"
APP="$DEST/$APP_NAME"
[[ ! -e "$APP" ]] || die "$APP already exists. Move it aside or delete it first."
free_gb=$(df -g "$DEST" | awk 'NR==2 {print $4}')
(( free_gb >= 20 )) || die "Needs about 20 GB free on the destination disk (Steam + the game); found ${free_gb} GB."

LOG="$HOME/Library/Logs/sinking-star-mac-install.log"
: > "$LOG"
WORK=$(mktemp -d)
built=0
cleanup() {
    rm -rf "$WORK"
    if (( ! built )) && [[ -d "$APP" ]]; then
        [[ -n "${CONTENTSFOLD:-}" && -x "$CONTENTSFOLD/SharedSupport/wine/bin/wineserver" ]] &&
            WINEPREFIX="$CONTENTSFOLD/SharedSupport/prefix" "$CONTENTSFOLD/SharedSupport/wine/bin/wineserver" -k 2>/dev/null
        rm -rf "$APP"
        print "Removed the partial app. Details are in $LOG" >&2
    fi
}
trap cleanup EXIT

fetch() {  # url, output, sha256 (empty to skip the check)
    curl -fL --retry 3 --progress-bar -o "$2" "$1" || die "Download failed: $1"
    if [[ -n "$3" ]]; then
        [[ "$(shasum -a 256 "$2" | cut -d' ' -f1)" == "$3" ]] || die "Checksum mismatch for $1"
    fi
}

# --- Assemble the wrapper --------------------------------------------------------
step "Downloading the Sikarugir wrapper template"
fetch "$TEMPLATE_URL" "$WORK/template.tar.xz" "$TEMPLATE_SHA256"
step "Downloading the Sikarugir Wine 11 engine"
fetch "$ENGINE_URL" "$WORK/engine.tar.xz" "$ENGINE_SHA256"

step "Assembling $APP_NAME"
tar -xJf "$WORK/template.tar.xz" -C "$WORK"
mkdir "$WORK/engine" && tar -xJf "$WORK/engine.tar.xz" -C "$WORK/engine"
mv "$WORK"/Template-*.app "$APP"
CONTENTSFOLD="$APP/Contents"
mv "$WORK/engine/wswine.bundle" "$CONTENTSFOLD/SharedSupport/wine"
xattr -dr com.apple.quarantine "$APP" 2>/dev/null || true

cp "$REPO"/bundle/Scripts/* "$CONTENTSFOLD/Resources/Scripts/"
chmod +x "$CONTENTSFOLD"/Resources/Scripts/*.sh "$CONTENTSFOLD/Resources/Scripts/StartupScript"
cp "$REPO/bundle/steamwebhelper-shim.exe" "$CONTENTSFOLD/Resources/"

PLIST="$CONTENTSFOLD/Info.plist"
. "$CONTENTSFOLD/Resources/Scripts/wine-env.sh"
plutil -replace CFBundleName -string "Order of the Sinking Star" "$PLIST"
plutil -replace CFBundleIdentifier -string "local.wrapper.order-of-the-sinking-star" "$PLIST"
plutil -replace D3DMETAL -integer 1 "$PLIST"
plutil -replace WINEDEBUG -string "-all" "$PLIST"
plutil -replace "Program Name and Path" -string "/Program Files (x86)/Steam/steam.exe" "$PLIST"
plutil -replace "Program Flags" -string "$SS_STEAM_FLAGS steam://rungameid/$SS_APPID" "$PLIST"

step "Creating the Windows environment (Wine prefix)"
"$CONTENTSFOLD/MacOS/wineskinlauncher" WSS-wineprefixcreate >> "$LOG" 2>&1
[[ -d "$WINEPREFIX/drive_c/windows" ]] || die "Creating the Wine prefix failed."

step "Applying display and Steam settings"
if [[ "$RETINA" == auto ]]; then
    scale=$(osascript -l JavaScript -e 'ObjC.import("AppKit"); $.NSScreen.mainScreen.backingScaleFactor' 2>/dev/null || echo 1)
    [[ "$scale" == 2* ]] && RETINA=yes || RETINA=no
fi
reg() { ss_wine reg add "$@" /f >> "$LOG" 2>&1; }
# Steam's in-game overlay commonly hangs D3D device creation under Wine/Metal.
reg 'HKCU\Software\Wine\DllOverrides' /v gameoverlayrenderer /t REG_SZ /d ""
reg 'HKCU\Software\Wine\DllOverrides' /v gameoverlayrenderer64 /t REG_SZ /d ""
if [[ "$RETINA" == yes ]]; then
    # Full pixel resolution instead of macOS points, and 200% UI scaling to match.
    reg 'HKCU\Software\Wine\Mac Driver' /v RetinaMode /t REG_SZ /d y
    reg 'HKCU\Control Panel\Desktop' /v LogPixels /t REG_DWORD /d 192
fi

step "Installing the Windows Steam client"
fetch "$STEAM_URL" "$WORK/SteamSetup.exe" ""
[[ "$(file -b "$WORK/SteamSetup.exe")" == PE32* ]] || die "SteamSetup.exe doesn't look like a Windows installer."
ss_wine "$WORK/SteamSetup.exe" /S >> "$LOG" 2>&1
[[ -f "$SS_STEAM_DIR/steam.exe" ]] || die "Steam didn't install."

# Steam downloads the rest of itself (including its CEF webhelper) on first run.
# Let that finish here so the shim is in place before the first real launch.
# No -noverifyfiles this time: with it, a fresh install skips the download entirely.
step "Letting Steam update itself (a few hundred MB)"
(cd "$SS_STEAM_DIR" && ss_wine "$SS_STEAM_EXE" -no-cef-sandbox -cef-disable-gpu >> "$LOG" 2>&1 &)
for i in {1..450}; do
    [[ -f "$SS_STEAM_DIR/bin/cef/cef.win64/steamwebhelper.exe" ]] &&
        grep -q "Update complete" "$SS_STEAM_DIR/logs/bootstrap_log.txt" 2>/dev/null && break
    sleep 2
done
(( i < 450 )) || die "Steam's first-run update didn't finish within 15 minutes."
sleep 5
ss_wineserver -k 2>/dev/null || true
ss_wineserver -w 2>/dev/null || true
"$CONTENTSFOLD/Resources/Scripts/reshim-steamwebhelper.sh" "$CONTENTSFOLD"

built=1
step "Done: $APP"
cat <<EOF

Next:
  1. Open "$APP_NAME" (Applications folder, Spotlight or Launchpad).
  2. Sign in to Steam in the window that appears (it can take up to a minute).
  3. Steam offers to install Order of the Sinking Star (about 11 GB). Once it's
     installed, press Play. Later launches go straight into the game, and Steam
     closes itself when you quit.

Tip: Settings > Resolution "1440p" is a good balance of sharpness and frame rate.
EOF
