#!/bin/sh
# Usage: firefox-titlebar.sh on|off. Firefox draws its own title bar, so the XP window decoration never shows.
# "on" adds a marked block to user.js of every Firefox profile, "off" removes exactly that block. Idempotent.
# Firefox reads user.js on start, so a running Firefox must be restarted. Chromium-family browsers are skipped:
# they rewrite Preferences while running, so editing it from outside is not safe.
for p in "$HOME"/.mozilla/firefox/*/prefs.js "${XDG_CONFIG_HOME:-$HOME/.config}"/mozilla/firefox/*/prefs.js; do
    [ -f "$p" ] || continue
    u="$(dirname "$p")/user.js"
    [ -f "$u" ] && sed -i '/^\/\/ win12 begin$/,/^\/\/ win12 end$/d' "$u"
    if [ "$1" = on ]; then
        printf '// win12 begin\nuser_pref("browser.tabs.inTitlebar", 0);\n// win12 end\n' >> "$u"
    else
        # user.js values get copied into prefs.js, so drop our 0 there too (back to Firefox's default).
        # ponytail: a Firefox still running writes the 0 back on exit; the next "off" sync clears it again.
        sed -i '/"browser.tabs.inTitlebar", 0)/d' "$p"
        [ -f "$u" ] && [ ! -s "$u" ] && rm "$u"
    fi
done
