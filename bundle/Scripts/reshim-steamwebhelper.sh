#!/bin/sh
# Steam's CEF UI paints a black window under Wine unless it runs single-process, and
# Steam ignores its own -cef-single-process option. Put the shim (which re-launches
# Valve's webhelper with --disable-gpu --single-process) in front of every CEF build
# Steam ships, and again whenever a Steam update restores Valve's original.
#
# Usage: reshim-steamwebhelper.sh <bundle Contents folder>
CONTENTSFOLD="$1"
SHIM="$CONTENTSFOLD/Resources/steamwebhelper-shim.exe"
SHIM_MD5=$(md5 -q "$SHIM")

for dir in "$CONTENTSFOLD/SharedSupport/prefix/drive_c/Program Files (x86)/Steam/bin/cef"/cef.win*; do
    [ -f "$dir/steamwebhelper.exe" ] || continue
    if [ "$(md5 -q "$dir/steamwebhelper.exe")" != "$SHIM_MD5" ]; then
        mv -f "$dir/steamwebhelper.exe" "$dir/steamwebhelper_real.exe"
        cp "$SHIM" "$dir/steamwebhelper.exe"
    fi
done
