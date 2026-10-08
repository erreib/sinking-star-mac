# Wine environment for this wrapper, matching what the Sikarugir launcher exports, so
# scripts can talk to the same Wine session. Source with CONTENTSFOLD set to the
# bundle's Contents folder.
SS_WINE="$CONTENTSFOLD/SharedSupport/wine"
SS_FRAMEWORKS="$CONTENTSFOLD/Frameworks"
SS_D3DMETAL="$SS_FRAMEWORKS/renderer/d3dmetal"
SS_APPID=499170

export WINEPREFIX="$CONTENTSFOLD/SharedSupport/prefix"
export WINEDEBUG="${WINEDEBUG:--all}"
export WINEMSYNC=1
export WINEESYNC=1
export WINEBOOT_HIDE_DIALOG=1
# The engine's ntdll refuses to start child processes without this marker.
export SikarugirAppWine11=1
export CX_ROOT="$SS_WINE"
export PATH="$SS_WINE/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export DYLD_FALLBACK_LIBRARY_PATH="$SS_WINE/lib:$SS_FRAMEWORKS:$SS_FRAMEWORKS/GStreamer.framework/Libraries:/usr/lib:/usr/libexec:/usr/lib/system"
export GST_PLUGIN_PATH="$SS_FRAMEWORKS/GStreamer.framework/Libraries/gstreamer-1.0"
export WINEDLLPATH="$SS_WINE/lib/x86_64-windows:$SS_WINE/lib/i386-windows:$SS_WINE/lib/x86_64-unix"
export VK_DRIVER_FILES="$CONTENTSFOLD/Resources/vulkan/icd.d/MoltenVK_icd.json"

# D3DMetal: d3d11/d3d12/dxgi come from Apple's builds instead of Wine's.
export WINEDLLPATH_PREPEND="$SS_D3DMETAL/wine"
export WINEDLLPATH_D3DMETAL="$SS_D3DMETAL/wine"
export CX_D3DMETALPATH="$SS_D3DMETAL"
export CX_APPLEGPTK_LIBD3DSHARED_PATH="$SS_D3DMETAL/external/libd3dshared.dylib"
export CX_APPLEGPT_LIBD3DSHARED_PATH="$CX_APPLEGPTK_LIBD3DSHARED_PATH"
export CX_FWD_COMPAT_GL_CTX=1

# Lets Rosetta report AVX/AVX2 to the game (macOS 15+).
export ROSETTA_ADVERTISE_AVX=1
export MTL_HUD_ENABLED="${MTL_HUD_ENABLED:-0}"

ss_wine() { "$SS_WINE/bin/wine" "$@"; }
ss_wineserver() { "$SS_WINE/bin/wineserver" "$@"; }

SS_STEAM_DIR="$WINEPREFIX/drive_c/Program Files (x86)/Steam"
SS_STEAM_EXE='C:\Program Files (x86)\Steam\steam.exe'
# No CEF sandbox (Wine can't model it), software rendering, and don't let Steam's
# file verification undo the webhelper shim.
SS_STEAM_FLAGS='-no-cef-sandbox -cef-disable-gpu -noverifyfiles'
