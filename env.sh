# Shared environment for the Order of the Sinking Star wrapper. Source this, don't run it.
#
# The wrapper is a Sikarugir app bundle (Template-1.0.21) running Sikarugir's Wine 11
# engine, which boots the current Steam client. DirectX 12 goes through Apple's
# D3DMetal (4.0b2, shipped in the template) via the CrossOver-style hooks in that
# engine. The Wine variables live in the bundle (Resources/Scripts/wine-env.sh) so the
# app's own scripts and these terminal scripts drive the same session.
SS_APP="${SS_APP:-$HOME/Applications/Order of the Sinking Star.app}"
SS_LOGS="${SS_LOGS:-${${(%):-%x}:A:h}/logs}"
CONTENTSFOLD="$SS_APP/Contents"
source "$CONTENTSFOLD/Resources/Scripts/wine-env.sh"
