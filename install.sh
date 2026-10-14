#!/bin/sh
# Install or update the Start12 widget for the current user, then reload Plasma.
set -e
cd "$(dirname "$0")"
node tests/test_tiles.js
if kpackagetool6 -t Plasma/Applet -l | grep -qx org.start12.menu; then
    kpackagetool6 -t Plasma/Applet -u package
else
    kpackagetool6 -t Plasma/Applet -i package
fi
install -Dm755 extras/start12-settings "$HOME/.local/bin/start12-settings"
install -Dm644 extras/start12-settings.desktop "$HOME/.local/share/applications/start12-settings.desktop"
if [ "$1" = "--restart" ]; then
    systemctl --user restart plasma-plasmashell.service
fi
