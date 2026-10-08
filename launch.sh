#!/bin/zsh
# Launches Order of the Sinking Star from a terminal.
#
#   ./launch.sh            normal launch
#   ./launch.sh --hud      with Apple's Metal performance HUD (FPS, frame/GPU time)
#   ./launch.sh --debug    HUD plus Wine error channels, logged to logs/game-*.log
#
# If the wrapper's Windows Steam is already running, the game is started directly
# (SteamAppId tells steam_api to attach to that Steam instead of relaunching through
# it), so per-launch variables like the HUD apply. Otherwise Steam is started with
# the variables set and launches the game itself, the way the app bundle does.
source "${0:A:h}/env.sh"
"$CONTENTSFOLD/Resources/Scripts/reshim-steamwebhelper.sh" "$CONTENTSFOLD"

case "$1" in
    --hud)   export MTL_HUD_ENABLED=1 SIKARUGIR_KEEP_METAL_HUD=1 ;;
    --debug) export MTL_HUD_ENABLED=1 SIKARUGIR_KEEP_METAL_HUD=1 WINEDEBUG="err+all,warn+seh" ;;
esac

mkdir -p "$SS_LOGS"
log="$SS_LOGS/game-$(date +%Y%m%d-%H%M%S).log"
game_dir="$SS_STEAM_DIR/steamapps/common/Order of the Sinking Star"

if pgrep -f 'Steam\\steam.exe' >/dev/null; then
    cd "$game_dir"
    SteamAppId=$SS_APPID SteamGameId=$SS_APPID ss_wine sinking_star.exe >> "$log" 2>&1 &!
else
    cd "$SS_STEAM_DIR"
    ss_wine "$SS_STEAM_EXE" ${=SS_STEAM_FLAGS} "steam://rungameid/$SS_APPID" >> "$log" 2>&1 &!
fi
echo "launched; log: $log"
