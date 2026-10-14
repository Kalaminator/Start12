#!/bin/sh
# Install or update the Start12 widget for the current user, then reload Plasma.
set -e
cd "$(dirname "$0")"
# Developer checks run only when node is installed.
if command -v node >/dev/null 2>&1; then node tests/test_tiles.js; fi
# Translations: po/<lang>.po -> contents/locale/<lang>/LC_MESSAGES/plasma_applet_<id>.mo (Plasma looks there);
# the compiled .mo files are shipped, so gettext is only needed to rebuild them.
if command -v msgfmt >/dev/null 2>&1; then
    for po in po/*.po; do
        lang=$(basename "$po" .po)
        mkdir -p "package/contents/locale/$lang/LC_MESSAGES"
        msgfmt --check -o "package/contents/locale/$lang/LC_MESSAGES/plasma_applet_org.start12.menu.mo" "$po"
    done
fi
if kpackagetool6 -t Plasma/Applet -l | grep -qx org.start12.menu; then
    kpackagetool6 -t Plasma/Applet -u package
else
    kpackagetool6 -t Plasma/Applet -i package
fi
# Generated themes + "Start12 Settings" command; the widget runs the same script on start (store installs).
sh package/contents/ui/code/setup.sh --force
if [ "$1" = "--restart" ]; then
    systemctl --user restart plasma-plasmashell.service
fi
