#!/bin/sh
# One-time setup the widget runs on every start (also run by install.sh): generated Plasma Styles,
# window decorations and colour schemes (xptheme.py) plus the "Start12 Settings" command and menu entry.
# A KDE Store / Discover install only unpacks the package, so this is how those files get made.
# Quick no-op unless the package version changed or a generated file is missing; --force always runs.
cd "$(dirname "$0")" || exit 1
D="${XDG_DATA_HOME:-$HOME/.local/share}"
B="$HOME/.local/bin"
STAMP="$D/start12/setup-version"
VER=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["KPlugin"]["Version"])' ../../../metadata.json)
if [ "$1" != "--force" ] && [ "$(cat "$STAMP" 2>/dev/null)" = "$VER" ] \
    && [ -d "$D/plasma/desktoptheme/start12-xp-classic" ] && [ -d "$D/aurorae/themes/start12-xp-classic" ] \
    && [ -f "$D/color-schemes/start12-xp-classic.colors" ] && [ -x "$B/start12-settings" ] && [ -d "$D/kwin/effects/start12panelpop" ]; then
    exit 0
fi
set -e
python3 xptheme.py "$D/plasma/desktoptheme"
python3 xptheme.py --deco "$D/aurorae/themes"
python3 xptheme.py --scheme "$D/color-schemes"
install -Dm755 ../../extras/start12-settings "$B/start12-settings"
install -Dm644 ../../extras/start12-settings.desktop "$D/applications/start12-settings.desktop"
# The effect ships as metadata.json.in: a metadata.json inside the plasmoid makes Plasma scan it as an applet.
FX=$(mktemp -d) && cp -r ../../extras/start12-panelpop/. "$FX" && mv "$FX/metadata.json.in" "$FX/metadata.json"
kpackagetool6 -t KWin/Effect -u "$FX" >/dev/null 2>&1 || kpackagetool6 -t KWin/Effect -i "$FX" >/dev/null
rm -rf "$FX"
mkdir -p "$D/start12"
echo "$VER" > "$STAMP"
