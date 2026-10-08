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

# Any version of the shim, including ones from before the marker existed (Valve's
# helper is several MB; the shim is about 140 KB).
is_shim() {
    LC_ALL=C /usr/bin/grep -q -a -F "sinking-star-mac steamwebhelper shim" "$1" ||
        [ "$(stat -f %z "$1")" -lt 1000000 ]
}

for dir in "$CONTENTSFOLD/SharedSupport/prefix/drive_c/Program Files (x86)/Steam/bin/cef"/cef.win*; do
    helper="$dir/steamwebhelper.exe"
    [ -f "$helper" ] || continue
    [ "$(md5 -q "$helper")" = "$SHIM_MD5" ] && continue
    # An older shim is just replaced; anything else is Valve's helper (a fresh install
    # or a Steam update), which moves aside for the shim to launch.
    is_shim "$helper" || mv -f "$helper" "$dir/steamwebhelper_real.exe"
    cp "$SHIM" "$helper"
done
