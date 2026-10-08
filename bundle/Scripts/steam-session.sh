#!/bin/sh
# Started in the background by StartupScript on every launch. Steam runs with -silent,
# which keeps its main window and Special Offers popup hidden and holds the app's
# steam://rungameid request until someone has signed in (then it starts the game, or
# shows the install dialog). This script fills the remaining gaps:
#
#  1. While the game downloads or updates, show Steam's Downloads page so progress is
#     visible, and start the game when an initial download finishes.
#  2. Once the game runs, give the app its icon; when the game exits, let Steam sync
#     cloud saves, shut it down, and end the Wine session so the app fully closes.
#
# Usage: steam-session.sh <bundle Contents folder>
CONTENTSFOLD="$1"
. "$CONTENTSFOLD/Resources/Scripts/wine-env.sh"
SCRIPTS="$CONTENTSFOLD/Resources/Scripts"
MANIFEST="$SS_STEAM_DIR/steamapps/appmanifest_$SS_APPID.acf"
# Anchored to the Windows paths Steam uses, so unrelated processes that merely
# mention these names (an editor, a shell) don't count.
GAME='^C:\\.*\\sinking_star\.exe'
STEAM='^C:\\.*\\Steam\\steam\.exe'

LOG="$HOME/Library/Logs/Order of the Sinking Star - session.log"
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG"; }
: > "$LOG"
log "started for $CONTENTSFOLD"

steam_url() { log "sending $1"; (cd "$SS_STEAM_DIR" && ss_wine "$SS_STEAM_EXE" "$1" >/dev/null 2>&1); }
installed() { grep -Eq '"StateFlags"[[:space:]]+"4"' "$MANIFEST" 2>/dev/null; }

# Wine and Steam start after this script; give them time to appear.
waited=0
until pgrep -f "$STEAM" >/dev/null; do
    sleep 2
    waited=$((waited + 2))
    [ "$waited" -ge 120 ] && { log "Steam never appeared; exiting"; exit 0; }
done
log "Steam is running"

downloading=0
was_installed=0
installed && was_installed=1
until pgrep -f "$GAME" >/dev/null; do
    pgrep -f "$STEAM" >/dev/null || { log "Steam exited before the game started"; exit 0; }
    if [ "$downloading" = 0 ] && [ -f "$MANIFEST" ] && ! installed; then
        steam_url "steam://open/downloads"
        downloading=1
    elif [ "$downloading" = 1 ] && [ "$was_installed" = 0 ] && installed; then
        # First install just finished; Steam doesn't launch it on its own.
        steam_url "steam://rungameid/$SS_APPID"
        downloading=2
    fi
    sleep 3
done

log "game is running"
# The game is installed by now, so the app can take its icon.
"$SCRIPTS/make-icon.sh" "$CONTENTSFOLD" >/dev/null 2>&1 &

# Re-check after a pause so a brief gap between game processes isn't taken as a quit.
while :; do
    while pgrep -f "$GAME" >/dev/null; do sleep 2; done
    sleep 10
    pgrep -f "$GAME" >/dev/null || break
done

log "game exited; shutting Steam down"
cd "$SS_STEAM_DIR" && ss_wine "$SS_STEAM_EXE" -shutdown >> "$LOG" 2>&1

# Steam's client crashes on its way out under Wine, and its crash reporter and
# background service then keep the Wine session (and the menu-bar icon) alive for
# a minute or two. Cloud saves sync when the game exits, so once the client itself
# is gone, or after 60 s if it hangs, end this app's Wine session.
waited=0
while pgrep -f "$STEAM" >/dev/null && [ "$waited" -lt 60 ]; do
    sleep 2
    waited=$((waited + 2))
done
log "Steam client gone after ${waited}s; ending the Wine session"
ss_wineserver -k
