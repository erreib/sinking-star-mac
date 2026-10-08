#!/bin/sh
# Started in the background by StartupScript. Waits for the game to start and then
# exit, gives Steam time to sync cloud saves, and shuts Steam down so the wrapper
# fully closes. If Steam is closed before the game ever starts (e.g. it was opened
# only to sign in or download), there is nothing to do.
CONTENTSFOLD="$1"
. "$CONTENTSFOLD/Resources/Scripts/wine-env.sh"
# Anchored to the Windows paths Steam uses, so unrelated processes that merely
# mention these names (an editor, a shell) don't count.
GAME='^C:\\.*\\sinking_star\.exe'
STEAM='^C:\\.*\\Steam\\steam\.exe'

# Wine and Steam start after this script; give them time to appear.
waited=0
until pgrep -f "$STEAM" >/dev/null; do
    sleep 2
    waited=$((waited + 2))
    [ "$waited" -ge 120 ] && exit 0
done

until pgrep -f "$GAME" >/dev/null; do
    pgrep -f "$STEAM" >/dev/null || exit 0
    sleep 3
done

# The game is installed by now, so the app can take its icon (first play session).
"$CONTENTSFOLD/Resources/Scripts/make-icon.sh" "$CONTENTSFOLD" >/dev/null 2>&1 &

# Re-check after a pause so a brief gap between game processes isn't taken as a quit.
while :; do
    while pgrep -f "$GAME" >/dev/null; do sleep 2; done
    sleep 10
    pgrep -f "$GAME" >/dev/null || break
done

cd "$SS_STEAM_DIR" && ss_wine "$SS_STEAM_EXE" -shutdown
