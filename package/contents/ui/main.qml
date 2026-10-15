pragma ComponentBehavior: Bound

import QtQuick
import QtCore
import QtQuick.Layouts
import QtQuick.Dialogs as Dialogs
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.private.kicker as Kicker
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami
import org.kde.kitemmodels as KItemModels
import org.kde.iconthemes as KIconThemes
import "code/tiles.js" as Tiles

PlasmoidItem {
    id: root

    readonly property var cfg: Plasmoid.configuration

    // Styles that have a QML file. The others fall back to Windows 10 for now.
    readonly property var builtStyles: ["windows7", "modern", "windows10", "windows11", "app", "pro", "launcher", "xp"]
    // Modern style = the Windows 7 file with a flat look.
    readonly property string styleFile: cfg.menuStyle === "modern" ? "windows7"
                                      : builtStyles.includes(cfg.menuStyle) ? cfg.menuStyle : "windows10"

    property string searchText: ""

    // Design mode (T40, not saved): dividers between menu sections can be dragged (common/SplitHandle).
    // The menu stays open on outside clicks; closing it ends design mode.
    property bool designMode: false
    hideOnWindowDeactivate: !designMode
    // Divider widths: `name` = "<style>" or "<style>/<part>"; stored unscaled, returned scaled.
    function splitFor(name, def) {
        const w = Tiles.splitGet(cfg.splits, name);
        return w === null ? def : Math.round(w * cfg.uiScale);
    }
    function setSplit(name, w) {
        cfg.splits = Tiles.splitSet(cfg.splits, name, w / cfg.uiScale);
    }
    function editLayout() {
        designMode = true;
        expanded = true;
    }
    Connections {
        target: root.cfg
        function onDesignRequestChanged() { if (root.cfg.designRequest) root.editLayout(); }
    }
    readonly property bool searching: searchText.length > 0
    property Item kbCurrent: null   // keyboard focus item (common/KeyNav), drawn by common/KeyFrame

    // ---- Pinned apps ----
    // Windows 10 style pins to tile groups; the grid styles (Windows 11, App, Pro) to a flat list.
    readonly property bool usesTiles: styleFile === "windows10"
    // Tile pages: `groups` is the shown page (cfg.tilePage); saveGroups writes that page back.
    readonly property var pages: Tiles.parsePages(cfg.tileGroups)
    readonly property int tilePage: Math.max(0, Math.min(cfg.tilePage, pages.length - 1))
    readonly property var groups: pages[tilePage].groups
    function savePages(p) {
        cfg.tileGroups = JSON.stringify({ pages: p });
    }
    function saveGroups(g) {
        savePages(Tiles.setPage(pages, tilePage, g));
    }
    function isPinned(id) {
        return usesTiles ? pages.some(p => Tiles.findTile(p.groups, id) !== null) : Tiles.allPins(cfg.pinnedGrid).includes(id);
    }
    // Hidden apps (key hiddenApps, desktop ids): left out of every app list and search.
    // ponytail: Kicker.RootModel has no hiddenEntries property in 6.7, so the lists filter.
    function isHidden(id) {
        return !!id && cfg.hiddenApps.includes(String(id).replace(/^applications:/, ""));
    }
    function hideApp(id) {
        if (id && !isHidden(id)) cfg.hiddenApps = cfg.hiddenApps.concat([String(id).replace(/^applications:/, "")]);
    }
    // Renamed pins (key pinnedCaptions, JSON id -> name); capOf returns "" when not renamed.
    function capOf(id) {
        try { return JSON.parse(cfg.pinnedCaptions)[id] || ""; } catch (e) { return ""; }
    }
    function setCap(id, name) {
        let m = {};
        try { m = JSON.parse(cfg.pinnedCaptions); } catch (e) {}
        if (name) m[id] = name; else delete m[id];
        cfg.pinnedCaptions = JSON.stringify(m);
    }
    function renamePin(id, current) {
        close();
        renameDialog.apply = null;
        renameDialog.pinId = id;
        renameField.text = capOf(id) || current || "";
        renameDialog.show();
    }
    // Same dialog for any name (canvas tabs/groups): fn(newName) runs on OK.
    function askName(current, fn) {
        close();
        renameDialog.apply = fn;
        renameField.text = current || "";
        renameDialog.show();
    }
    function pin(id) {
        if (!id || isPinned(id)) return;
        if (!usesTiles) {
            cfg.pinnedGrid = cfg.pinnedGrid.concat([id]);
            return;
        }
        // New pins go to the end of the last group, like Windows.
        const g = Math.max(0, groups.length - 1);
        saveGroups(Tiles.place(groups, id, g, groups.length ? groups[g].tiles.length : 0));
    }
    function unpin(id) {
        if (usesTiles) {
            // Folder ids repeat across pages: a folder only goes on the shown page.
            savePages(Tiles.isFolder(id) ? Tiles.setPage(pages, tilePage, Tiles.remove(groups, id))
                                         : pages.map(p => ({ groups: Tiles.remove(p.groups, id) })));
        } else {
            cfg.pinnedGrid = Tiles.removePin(cfg.pinnedGrid, id);
        }
    }
    // Pins whose app is not installed (e.g. the default Konsole pin) are hidden, not removed.
    // ponytail: one model over all pins (as windows7.qml); if a pin id is also rewritten
    // (preferred://browser) while another app is missing, the rewritten one may hide too.
    Kicker.SimpleFavoritesModel {
        id: pinCheck
        favorites: Tiles.allPins(cfg.pinnedGrid).filter(id => !Tiles.custom(id))
    }
    readonly property var missingPins: {
        const apps = Tiles.allPins(cfg.pinnedGrid).filter(id => !Tiles.custom(id)); // not pinCheck.favorites: the model drops missing ids there
        if (pinCheck.count >= apps.length) return [];
        const role = pinCheck.KItemModels.KRoleNames.role("favoriteId");
        const have = [];
        for (let r = 0; r < pinCheck.count; r++)
            have.push((pinCheck.data(pinCheck.index(r, 0), role) || "").replace(/^applications:/, ""));
        return apps.filter(id => !have.includes(id));
    }
    readonly property var shownPins: cfg.pinnedGrid.filter(id => !missingPins.includes(id))
    function movePinned(id, index) {
        // Out of a folder: unpin it there first (a dissolving folder keeps its place).
        const list = cfg.pinnedGrid.includes(id) ? cfg.pinnedGrid : Tiles.removePin(cfg.pinnedGrid, id);
        cfg.pinnedGrid = Tiles.placeInList(list, id, index);
    }
    // Pinned grid folders (Windows 11): drop id on entry target; rename; unpin = its apps back in place.
    function folderPins(id, target) {
        cfg.pinnedGrid = Tiles.placeInFolder(cfg.pinnedGrid, id, target, i18n("Folder"));
    }
    function renameFolder(entry, name) {
        const f = Tiles.folderOf(entry);
        if (f) cfg.pinnedGrid = cfg.pinnedGrid.map(e => e === entry ? Tiles.folderEntry(name, f.ids) : e);
    }
    function unfoldFolder(entry) {
        const f = Tiles.folderOf(entry), i = cfg.pinnedGrid.indexOf(entry);
        if (f && i >= 0) cfg.pinnedGrid = cfg.pinnedGrid.slice(0, i).concat(f.ids, cfg.pinnedGrid.slice(i + 1));
    }

    // ---- Models from KDE's own launcher library ----
    readonly property Kicker.RootModel rootModel: Kicker.RootModel {
        autoPopulate: false
        appletInterface: root
        flat: true
        sorted: true
        showSeparators: false
        showTopLevelItems: true
        showAllApps: true
        showAllAppsCategorized: false
        showRecentApps: false
        showRecentDocs: false
        showPowerSession: false
        showFavoritesPlaceholder: true
        highlightNewlyInstalledApps: true
        Component.onCompleted: {
            favoritesModel.initForClient("org.start12.menu.favorites.instance-" + Plasmoid.id);
            root.cfg.favoritesPortedToKAstats = true;
        }
    }

    readonly property Kicker.RunnerModel runnerModel: Kicker.RunnerModel {
        appletInterface: root
        query: root.searchText
        mergeResults: !root.cfg.groupResults
        // Plasma 6.7: an empty list means no runners at all, so "empty = default" is spelled out here.
        runners: root.cfg.searchRunners.length ? root.cfg.searchRunners
            : ["krunner_services", "krunner_systemsettings", "baloosearch", "krunner_recentdocuments",
               "krunner_placesrunner", "locations", "calculator", "unitconverter", "krunner_sessions",
               "krunner_powerdevil", "krunner_bookmarksrunner"]
        favoritesModel: root.rootModel.favoritesModel
    }

    // Created only after rootModel.refresh(): SystemModel crashes on a null favoritesModel.
    property Kicker.SystemModel systemModel: null
    Component {
        id: systemModelComponent
        Kicker.SystemModel {}
    }

    readonly property Kicker.RecentUsageModel frequentAppsModel: Kicker.RecentUsageModel {
        favoritesModel: root.rootModel.favoritesModel
        shownItems: Kicker.RecentUsageModel.OnlyApps
        ordering: 1 // most used
    }

    Kicker.ProcessRunner {
        id: processRunner
    }

    // Run a shell command (systemsettings, dolphin, ...).
    P5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []
        onNewData: sourceName => disconnectSource(sourceName)
    }
    function run(cmd) {
        executable.connectSource(cmd);
    }
    // XP taskbar: with the XP style, the Plasma Style follows substyle + colour scheme (made by
    // code/xptheme.py: install.sh writes blue/olive/silver; a custom colour is generated here under a
    // new name per colour, so Plasma's svg cache never shows a stale one). Leaving XP restores the theme
    // saved in savedDesktopTheme. Reads the current theme first so nothing is applied when already right.
    // ponytail: two Start12 widgets with different styles would fight over the theme; one menu is the norm.
    readonly property string xpCustomHex: cfg.xpCustomColor.toString().slice(-6)
    readonly property string xpScheme: "start12-xp-" + cfg.xpSubstyle + (cfg.xpColor === "olive" || cfg.xpColor === "silver" ? "-" + cfg.xpColor
                                       : cfg.xpColor === "custom" ? "-custom-" + xpCustomHex : "")
    readonly property string xpTheme: cfg.menuStyle !== "xp" || !cfg.xpTaskbarTheme ? "" : xpScheme
    onXpThemeChanged: syncDesktopTheme()
    // Window decorations (T26a, key windowTheme): Aurorae theme per menu style, and (T26b) the colour scheme of the
    // same name. From xptheme.py --deco / --scheme (install.sh; XP custom colour made here). T37: windows10/11
    // light or dark like the user's own scheme (userDark), windows7 light, modern/app/pro/launcher = Win11 look.
    function windowDecoration() {
        const s = cfg.menuStyle;
        // T39 Colours page: every non-XP style follows light/dark (winDark) and "accent on title bars" (-accent-hex).
        const acc = cfg.win10AccentTitles ? "-accent-" + accentHex : "";
        return s === "xp" ? xpScheme : s === "windows7" ? "start12-win7" + acc
            : "start12-" + (s === "windows10" ? "win10-" : "win11-") + (winDark ? "dark" : "light") + acc;
    }
    // T38/T39 Colours page: light/dark from colorMode (0 Plasma = userDark, 1 dark, 2 light, 3 custom menu colour),
    // accent = the menu's accent (Plasma or custom).
    property var userAccent: ""   // read with userDark (readBrightness)
    readonly property string accentHex: (cfg.accentMode === 1 ? cfg.accentColor
                                         : userAccent !== "" ? userAccent : Kirigami.Theme.highlightColor).toString().slice(-6)
    readonly property bool winDark: cfg.colorMode === 1 || (cfg.colorMode === 0 && userDark)
        || (cfg.colorMode === 3 && Kirigami.ColorUtils.brightnessForColor(cfg.menuColor) === Kirigami.ColorUtils.Dark)
    // xptheme.py args for a deco/scheme made at apply time (XP custom colour, Win10 accent title bar); "" = shipped one.
    function customArgs(name) {
        return name.includes("-custom-") ? "--custom " + xpCustomHex + " --sub " + cfg.xpSubstyle
            : name.includes("-accent-") ? "--custom " + accentHex + " --win10 " + (winDark ? "dark" : "light") + " --kind " + name.split("-")[1] : "";
    }
    readonly property string customNames: "\\( -name 'start12-xp-*-custom-*' -o -name 'start12-win*-accent-*' -o -name 'start12-*-g[0-9]*b[01]r*t[0-9]*' \\)"
    readonly property string windowDeco: cfg.windowTheme ? windowDecoration() : ""
    // T41 window glass (Taskbar page): opacity/blur/radius/title height = a deco made at apply time,
    // <windowDeco>-g<opacity>b<blur>r<radius|d>t<title>; the colour scheme keeps the windowDeco name.
    readonly property string glassSuffix: cfg.windowOpacity < 100 || cfg.windowRadius >= 0 || cfg.titleHeight > 0
        ? "-g" + cfg.windowOpacity + "b" + (cfg.windowBlur ? 1 : 0) + "r" + (cfg.windowRadius < 0 ? "d" : cfg.windowRadius) + "t" + cfg.titleHeight : ""
    readonly property string decoName: windowDeco === "" ? "" : windowDeco + glassSuffix
    readonly property bool wantBlur: windowDeco !== "" && cfg.windowOpacity < 100 && cfg.windowBlur
    onGlassSuffixChanged: syncWindowDeco()
    onWantBlurChanged: syncWindowDeco()
    onWindowDecoChanged: readBrightness()
    // Brightness of the user's own colour scheme (the saved one while ours is applied), then both syncs.
    property bool userDark: false
    function readBrightness() {
        brightReader.connectSource("S=" + Tiles.shQuote(cfg.savedColorScheme) + "; f=kdeglobals; "
            + "case \"$(kreadconfig6 --file kdeglobals --group General --key ColorScheme)\" in start12-*) "
            + "f=$(ls \"$HOME/.local/share/color-schemes/$S.colors\" \"/usr/share/color-schemes/$S.colors\" 2>/dev/null | head -1);; esac; "
            + "kreadconfig6 --file \"${f:-kdeglobals}\" --group Colors:Window --key BackgroundNormal; "
            + "kreadconfig6 --file kdeglobals --group General --key AccentColor; "
            + "kreadconfig6 --file \"${f:-kdeglobals}\" --group Colors:Selection --key BackgroundNormal");
    }
    P5Support.DataSource {
        id: brightReader
        engine: "executable"
        connectedSources: []
        onNewData: (sourceName, data) => {
            disconnectSource(sourceName);
            const lines = (data.stdout || "").split("\n");
            const v = (lines[0] || "").trim().split(",").map(Number);
            root.userDark = v.length === 3 && 0.299 * v[0] + 0.587 * v[1] + 0.114 * v[2] < 128;
            // The user's own accent (Plasma accent colour, else their scheme's selection): Kirigami's highlight
            // follows whatever scheme/style Start12 applied, so it can't be used for "Automatic".
            const a = ((lines[1] || "").trim() || (lines[2] || "").trim()).split(",").map(Number);
            root.userAccent = a.length >= 3 && a.every(n => n >= 0 && n <= 255) ? Qt.rgba(a[0] / 255, a[1] / 255, a[2] / 255, 1) : "";
            root.syncWindowDeco();
            root.syncWindowColors();
        }
    }
    // Same save/restore idea as syncDesktopTheme: kwinrc [org.kde.kdecoration2] library + theme are saved in
    // savedDecoLibrary/savedDecoTheme when ours goes on and written back when it goes off.
    function syncWindowDeco() {
        const rd = key => "\"$(kreadconfig6 --file kwinrc --group org.kde.kdecoration2 --key " + key + ")\"";
        decoReader.connectSource("printf '%s|%s|%s' " + rd("library") + " " + rd("theme")
            + " \"$(kreadconfig6 --file kwinrc --group Plugins --key blurEnabled)\"");
    }
    P5Support.DataSource {
        id: decoReader
        engine: "executable"
        connectedSources: []
        onNewData: (sourceName, data) => {
            disconnectSource(sourceName);
            const parts = (data.stdout || "").split("|");
            const lib = parts[0].trim(), cur = (parts[1] || "").trim(), blur = (parts[2] || "").trim();
            // T41: KWin's blur effect on for the glass frame; the user's blurEnabled is saved in savedBlur ("unset" =
            // no key) and written back when our blur goes off.
            const plug = "kwriteconfig6 --file kwinrc --group Plugins --key blurEnabled ";
            const fx = f => " && " + Tiles.QDBUS + " org.kde.KWin /Effects org.kde.kwin.Effects." + f + " blur";
            if (root.wantBlur && root.cfg.savedBlur === "") {
                root.cfg.savedBlur = blur || "unset";
                root.run("sh -c " + Tiles.shQuote(plug + "true" + fx("loadEffect")));
            } else if (!root.wantBlur && root.cfg.savedBlur !== "") {
                const old = root.cfg.savedBlur;
                root.cfg.savedBlur = "";
                root.run("sh -c " + Tiles.shQuote(old === "unset" ? plug + "--delete" : plug + Tiles.shQuote(old)
                         + (old === "false" ? fx("unloadEffect") : "")));
            }
            const ours = cur.startsWith("__aurorae__svg__start12-");
            const kw = (key, v) => v === "" ? "kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key " + key + " --delete"
                : "kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key " + key + " " + Tiles.shQuote(v);
            const reconf = " && " + Tiles.QDBUS + " org.kde.KWin /KWin reconfigure";
            const dir = "$HOME/.local/share/aurorae/themes/";
            if (root.windowDeco !== "") {
                const want = "__aurorae__svg__" + root.decoName;
                if (cur === want && lib === "org.kde.kwin.aurorae")
                    return;
                if (!ours) {
                    root.cfg.savedDecoLibrary = lib;
                    root.cfg.savedDecoTheme = cur;
                }
                const gen = decodeURIComponent(Qt.resolvedUrl("code/xptheme.py").toString().replace("file://", ""));
                const make = root.customArgs(root.windowDeco) === "" && root.glassSuffix === "" ? "true"
                    : "python3 " + Tiles.shQuote(gen) + " --deco --name " + root.windowDeco + " --opacity " + root.cfg.windowOpacity
                      + " --blur " + (root.cfg.windowBlur ? 1 : 0) + " --radius " + root.cfg.windowRadius + " --title " + root.cfg.titleHeight
                      + " --out " + dir + root.decoName;
                root.run("sh -c " + Tiles.shQuote(make + " && " + kw("library", "org.kde.kwin.aurorae") + " && " + kw("theme", want) + reconf
                         + " && find " + dir + " -maxdepth 1 " + root.customNames + " ! -name " + root.decoName + " -exec rm -rf {} +"));
            } else if (ours) {
                root.run("sh -c " + Tiles.shQuote(kw("library", root.cfg.savedDecoLibrary) + " && " + kw("theme", root.cfg.savedDecoTheme) + reconf));
            }
        }
    }
    // Window colours (T26b, same windowTheme key and name as windowDeco). Same save/restore idea: kdeglobals [General] ColorScheme is saved in savedColorScheme when ours goes on.
    function syncWindowColors() {
        colorReader.connectSource("kreadconfig6 --file kdeglobals --group General --key ColorScheme");
    }
    P5Support.DataSource {
        id: colorReader
        engine: "executable"
        connectedSources: []
        onNewData: (sourceName, data) => {
            disconnectSource(sourceName);
            const cur = (data.stdout || "").trim();
            const ours = cur.startsWith("start12-");
            const want = root.windowDeco;
            if (want !== "") {
                if (cur === want)
                    return;
                if (!ours)
                    root.cfg.savedColorScheme = cur;
                const dir = "$HOME/.local/share/color-schemes/";
                const gen = decodeURIComponent(Qt.resolvedUrl("code/xptheme.py").toString().replace("file://", ""));
                const make = root.customArgs(want) === "" ? "true"
                    : "python3 " + Tiles.shQuote(gen) + " --scheme " + root.customArgs(want) + " --out " + dir + want + ".colors";
                root.run("sh -c " + Tiles.shQuote(make + " && plasma-apply-colorscheme " + want
                         + " && find " + dir + " -maxdepth 1 " + root.customNames + " ! -name " + want + ".colors -delete"));
            } else if (ours) {
                root.run("plasma-apply-colorscheme " + Tiles.shQuote(root.cfg.savedColorScheme || "BreezeLight"));
            }
        }
    }
    // Generated taskbar for any style (T31, xptheme.py --taskbar): start12-taskbar-<hash of args + fallback>,
    // FallbackTheme = the user's saved style, so only panel/tasks/colors change. XP taskbar wins.
    // T35: taskbarFollowsStyle picks a preset per menu style instead of the custom keys (T37: others = windows11, xp = none).
    // T34: button style (buttons=plasma|win10|win11|win7), accent for the Win10/11 active bar, solid = focused
    // item less transparent; added to presets and custom alike.
    // T38/T39 the presets follow the Colours page (light/dark, accent taskbar, transparency); windows7 = accent-tinted glass.
    readonly property var taskbarPresets: ({
        "windows10": "colour=" + (cfg.win10AccentStart ? accentHex : winDark ? "101010" : "eeeeee")
                     + " alpha=" + (cfg.win10Transparency ? 0.85 : 1) + " radius=2 line=0 buttons=win10",
        "windows11": "colour=" + (cfg.win10AccentStart ? accentHex : winDark ? "202020" : "f3f3f3")
                     + " alpha=" + (cfg.win10Transparency ? 0.8 : 1) + " radius=8 line=0 buttons=win11",
        "windows7": "colour=" + (cfg.win10AccentStart ? accentHex : "2a5a96")
                    + " alpha=" + (cfg.win10Transparency ? 0.6 : 1) + " radius=6 line=1 buttons=win7" })
    readonly property string taskbarBase: cfg.taskbarFollowsStyle ? (taskbarPresets[cfg.menuStyle] || (cfg.menuStyle === "xp" ? "" : taskbarPresets.windows11))
        : cfg.taskbarTheme !== "custom" ? ""
        : "colour=" + cfg.taskbarColor.toString().slice(-6) + " alpha=" + (cfg.taskbarAlpha / 100)
          + " radius=" + cfg.taskbarRadius + " line=" + (cfg.taskbarLine ? 1 : 0) + " buttons=" + Tiles.shQuote(cfg.taskbarButtons)
          // T33 texture (path shell-quoted: it ends up in sh -c; the hash makes a new theme per change)
          + (cfg.taskbarImage === "" ? "" : " image=" + Tiles.shQuote(cfg.taskbarImage) + " mode=" + cfg.taskbarImageMode
             + " imagealpha=" + (cfg.taskbarImageAlpha / 100)
             + (cfg.taskbarImageTint ? " tint=" + cfg.accentColor.toString().slice(-6) : ""))
    readonly property string taskbarArgs: taskbarBase === "" ? "" : taskbarBase
        + " accent=" + (cfg.menuStyle !== "xp" && cfg.win10AccentStart && cfg.taskbarFollowsStyle
                        ? Qt.lighter("#" + accentHex, 1.6).toString().slice(-6) : cfg.accentColor.toString().slice(-6)) + " solid=" + (cfg.taskbarFocusedSolid ? 1 : 0)
    onTaskbarArgsChanged: syncDesktopTheme()
    function syncDesktopTheme() {
        themeReader.connectSource("kreadconfig6 --file plasmarc --group Theme --key name");
    }
    P5Support.DataSource {
        id: themeReader
        engine: "executable"
        connectedSources: []
        onNewData: (sourceName, data) => {
            disconnectSource(sourceName);
            const cur = (data.stdout || "").trim() || "default";
            const ours = cur.startsWith("start12-xp-") || cur.startsWith("start12-taskbar-");
            const fallback = ours ? (root.cfg.savedDesktopTheme || "default") : cur;
            const want = root.xpTheme !== "" ? root.xpTheme : root.taskbarArgs === "" ? ""
                : "start12-taskbar-" + Qt.md5(root.taskbarArgs + " " + fallback).slice(0, 10);
            if (want !== "") {
                if (cur === want)
                    return;
                if (!ours)
                    root.cfg.savedDesktopTheme = cur;
                if (want !== root.xpTheme) {
                    const tdir = "$HOME/.local/share/plasma/desktoptheme/";
                    const tgen = decodeURIComponent(Qt.resolvedUrl("code/xptheme.py").toString().replace("file://", ""));
                    // Old generated themes go only after the new one is applied (a failed generate keeps the current one).
                    root.run("sh -c " + Tiles.shQuote("python3 " + Tiles.shQuote(tgen)
                             + " --taskbar " + root.taskbarArgs + " fallback=" + Tiles.shQuote(fallback) + " --out " + tdir + want
                             + " && plasma-apply-desktoptheme " + want
                             + " && find " + tdir + " -maxdepth 1 -name 'start12-taskbar-*' ! -name " + want + " -exec rm -rf {} +"));
                } else if (root.xpTheme.includes("-custom-")) {
                    const dir = "$HOME/.local/share/plasma/desktoptheme/";
                    const gen = decodeURIComponent(Qt.resolvedUrl("code/xptheme.py").toString().replace("file://", ""));
                    root.run("sh -c " + Tiles.shQuote("python3 " + Tiles.shQuote(gen) + " --custom "
                             + root.xpCustomHex + " --sub " + root.cfg.xpSubstyle + " --out " + dir + root.xpTheme
                             + " && plasma-apply-desktoptheme " + root.xpTheme
                             + " && find " + dir + " -maxdepth 1 -name 'start12-xp-*-custom-*' ! -name " + root.xpTheme + " -exec rm -rf {} +"));
                } else {
                    root.run("plasma-apply-desktoptheme " + root.xpTheme);
                }
            } else if (ours) {
                root.run("plasma-apply-desktoptheme " + Tiles.shQuote(root.cfg.savedDesktopTheme || "default"));
            }
        }
    }
    function openUrl(url) {
        Qt.openUrlExternally(url);
        root.expanded = false;
    }
    // Pinned website/file/folder (Tiles.custom): open its target, or run "cmd:..." targets.
    function openCustom(c) {
        if (c.target.startsWith("cmd:")) {
            run(c.target.slice(4));
            close();
        } else {
            openUrl(c.target);
        }
    }
    // T32: custom pins on the taskbar. Writes start12-pin-<md5>.desktop (Tiles.pinDesktop) and adds/removes its
    // url in the launchers of the Task Manager(s) in this widget's panel (evaluateScript, like "autohide").
    // ponytail: pinned state is our own list (cfg.taskbarPins); a launcher removed by hand on the panel or a
    // renamed pin (new id) leaves a stale entry, harmless. Read the launchers back if that ever matters.
    function taskbarItem(id) {
        if (!Tiles.custom(id)) return [];
        const on = cfg.taskbarPins.indexOf(id) >= 0;
        return [{ text: on ? i18n("Unpin from taskbar") : i18n("Pin to taskbar"), icon: on ? "window-unpin" : "window-pin",
                  run: () => setTaskbarPin(id, !on) }];
    }
    function setTaskbarPin(id, on) {
        const dir = decodeURIComponent(StandardPaths.writableLocation(StandardPaths.GenericDataLocation).toString().replace(/^file:\/\//, "")) + "/applications";
        const name = "start12-pin-" + Qt.md5(id).slice(0, 8) + ".desktop";
        const path = dir + "/" + name;
        const script = "for (const p of panels()) { if (p.widgetIds.indexOf(" + Plasmoid.id + ") < 0) continue; "
            + "for (const w of p.widgets()) { if (!/icontasks|taskmanager/.test(w.type)) continue; w.currentConfigGroup = ['General']; "
            // ponytail: launchers still at the task manager's built-in default read as '' here; writing would
            // drop those defaults, so such a task manager is skipped (pinning works once it has its own list).
            + "const raw = String(w.readConfig('launchers', '')); if (!raw) continue; "
            + "const l = raw.split(',').filter(s => s && s.indexOf(" + JSON.stringify(name) + ") < 0); "
            + (on ? "l.push(" + JSON.stringify("file://" + path) + "); " : "")
            + "w.writeConfig('launchers', l); w.reloadConfig(); } }";
        const dbus = "" + Tiles.QDBUS + " org.kde.plasmashell /PlasmaShell evaluateScript " + Tiles.shQuote(script);
        run("sh -c " + Tiles.shQuote(on
            ? "mkdir -p " + Tiles.shQuote(dir) + " && printf %s " + Tiles.shQuote(Tiles.pinDesktop(Tiles.custom(id))) + " > " + Tiles.shQuote(path) + " && " + dbus
            : dbus + "; rm -f " + Tiles.shQuote(path)));
        cfg.taskbarPins = on ? cfg.taskbarPins.concat([id]) : cfg.taskbarPins.filter(p => p !== id);
    }

    // T42: Menu position Center + key centerTaskbar = Windows 11 taskbar. In this widget's (horizontal) panel:
    // two expanding panel spacers marked start12Centre, one right before the Start button and one after the
    // last Task Manager, and the Task Manager(s) stop filling the panel (key "fill", old value kept in
    // start12Fill). Turning it off removes the marked spacers and puts "fill" back, so the old layout returns.
    // Order: a second script (1 s later, once the new spacers are in the panel layout) sets Widget.index,
    // which makes plasmashell call the panel's reorderApplets() live (writing AppletOrder alone does not).
    // Each sync marks its spacers with a new token and removes all older marked ones: a removed widget stays in
    // p.widgets() for a while (Plasma keeps it for undo), so old spacers must never be reused.
    // Menu position Right + centerTaskbar = mirrored panel: the whole widget order is reversed (clock, tray and
    // show desktop go left, Start goes to the right end) with one spacer before the Task Manager so the tasks sit
    // next to Start. The original order is kept in the panel's start12PanelOrder key and put back when it ends.
    readonly property int panelMode: !cfg.centerTaskbar ? 0 : cfg.menuPosition === 1 ? 1 : cfg.menuPosition === 2 ? 2 : 0
    readonly property bool centerPanel: panelMode !== 0
    onPanelModeChanged: syncCenterPanel()
    function syncCenterPanel() {
        const token = String(Date.now());
        const head = "const ID = " + Plasmoid.id + ", M = 'start12Centre', T = '" + token + "';"
            + "for (const p of panels()) { if (p.widgetIds.indexOf(ID) < 0 || p.location === 'left' || p.location === 'right') continue; "
            + "const marked = v => p.widgets('org.kde.plasma.panelspacer').filter(w => { w.currentConfigGroup = ['General']; const m = String(w.readConfig(M, '')); return v ? m === v : m !== ''; }); "
            + "const mine = marked(T); "
            + "const tasks = p.widgets().filter(w => /icontasks|taskmanager/.test(w.type)); "
            + "const byId = id => p.widgets().find(x => x.id === id); "
            + "p.currentConfigGroup = ['General']; const saved = String(p.readConfig('start12PanelOrder', '')); ";
        // Undo the mirror: widgets back to the saved order (ones gone since are skipped).
        const unmirror = "if (saved) { saved.split(';').map(Number).forEach((id, i) => { const w = byId(id); if (w) w.index = i; }); "
            + "p.currentConfigGroup = ['General']; p.writeConfig('start12PanelOrder', ''); } ";
        const dbus = Tiles.QDBUS + " org.kde.plasmashell /PlasmaShell evaluateScript ";
        const off = head + unmirror + "for (const w of marked('')) w.remove(); "
                + "for (const w of tasks) { w.currentConfigGroup = ['General']; const f = String(w.readConfig('start12Fill', '')); "
                + "if (f) { w.writeConfig('fill', f !== 'false'); w.writeConfig('start12Fill', ''); w.reloadConfig(); } } }";
        if (!centerPanel) {
            run(dbus + Tiles.shQuote(off));
            return;
        }
        const n = panelMode === 2 ? 1 : 2;
        const add = head + (panelMode === 1 ? unmirror : "") + "for (const w of marked('')) w.remove(); "
            + "for (const w of tasks) { w.currentConfigGroup = ['General']; if (!String(w.readConfig('start12Fill', ''))) w.writeConfig('start12Fill', String(w.readConfig('fill', true))); w.writeConfig('fill', false); w.reloadConfig(); } "
            + "for (let i = 0; i < " + n + "; i++) { const s = p.addWidget('org.kde.plasma.panelspacer'); s.currentConfigGroup = ['General']; s.writeConfig(M, T); s.reloadConfig(); } }";
        // index = position in the order without the moved widget: spacer 1 right before Start, spacer 2 after the last task manager.
        const centre = "let o = ord(mine[0]); mine[0].index = o.indexOf(ID); "
            + "if (mine.length > 1) { o = ord(mine[1]); let end = o.indexOf(ID); for (const w of tasks) end = Math.max(end, o.indexOf(w.id)); mine[1].index = end + 1; } ";
        // Mirror: reverse the order without our spacers (saved first, unless already mirrored), spacer before the tasks.
        const mirror = "const spacers = marked('').map(w => w.id); "
            + "const cur = String(p.readConfig('AppletOrder', '')).split(';').map(Number).filter(i => i && spacers.indexOf(i) < 0); "
            + "if (!saved) p.writeConfig('start12PanelOrder', cur.join(';')); "
            + "const rev = (saved ? saved.split(';').map(Number).filter(i => byId(i)) : cur).slice().reverse(); "
            + "const t = rev.findIndex(i => tasks.some(w => w.id === i)); rev.splice(t < 0 ? rev.indexOf(ID) : t, 0, mine[0].id); "
            + "rev.forEach((id, i) => { const w = byId(id); if (w) w.index = i; }); ";
        const order = head + "if (mine.length < " + n + ") continue; p.currentConfigGroup = ['General']; "
            + "const ord = x => String(p.readConfig('AppletOrder', '')).split(';').map(Number).filter(i => i && i !== x.id); "
            + (panelMode === 2 ? mirror : centre)
            // the spacers' optimalSize binding misses the move: flip "expanding" so it recomputes (centred).
            + "for (const s of mine) { s.writeConfig('expanding', false); s.reloadConfig(); s.writeConfig('expanding', true); s.reloadConfig(); } }";
        run(dbus + Tiles.shQuote(add) + "; sleep 1; " + dbus + Tiles.shQuote(order));
    }

    // Find a power/session action by its id ("shutdown", "reboot", ...).
    // Returns the row, or -1 when this session can't do it (e.g. no hibernate).
    function systemAction(id) {
        if (!systemModel) return -1;
        const role = systemModel.KItemModels.KRoleNames.role("favoriteId");
        for (let i = 0; i < systemModel.count; i++) {
            if (systemModel.data(systemModel.index(i, 0), role) === id) {
                return i;
            }
        }
        return -1;
    }
    function runSystemAction(id) {
        const row = systemAction(id);
        if (row >= 0) {
            systemModel.trigger(row, "", null);
        }
        close();
    }

    function close() {
        root.expanded = false;
    }

    // The Start12 settings window (Plasma's configure dialog with our pages).
    function openSettings() {
        Plasmoid.internalAction("configure").trigger();
    }

    // The "Start12 Settings" app asks for the window through this config key.
    Connections {
        target: root.cfg
        function onOpenSettingsRequestChanged() {
            root.openSettings();
        }
    }

    // Reset from the settings pages (they set cfg.resetRequest = "positions|<time>" or "all|<time>").
    // Backup/restore (T13) use the same key: "backup|<time>|<file>" / "restore|<time>|<file>" (JSON file).
    // Delayed so the dialog's own Apply finishes writing first. "all" puts every key back to its main.xml
    // default; savedDesktopTheme is kept so leaving XP (menuStyle default) restores the user's Plasma Style.
    Timer {
        id: resetTimer
        interval: 700
        property string what: ""
        onTriggered: {
            const parts = root.cfg.resetRequest.split("|");
            const file = parts.slice(2).join("|");
            if (what === "backup") {
                const data = {};
                for (const k of root.userKeys()) {
                    const v = root.cfg[k];
                    // Colours become "#rrggbb"; string lists become plain arrays.
                    data[k] = v !== null && typeof v === "object" ? (v.length !== undefined ? Array.from(v) : v.toString()) : v;
                }
                root.run(Tiles.writeFileCmd(JSON.stringify({ start12Backup: 1, settings: data }), file));
                root.cfg.resetRequest = "";
                return;
            }
            if (what === "restore") {
                backupReader.connectSource("cat " + Tiles.shQuote(file));
                root.cfg.resetRequest = "";
                return;
            }
            const keys = what === "all" ? root.userKeys() : ["tileGroups", "pinnedGrid", "pinnedCaptions", "tilePage"];
            for (const k of keys) {
                const d = root.cfg[k + "Default"];
                if (d !== undefined)
                    root.cfg[k] = d;
            }
            root.cfg.resetRequest = "";
        }
    }
    // Keys that reset/backup/restore touch: everything in main.xml but bookkeeping and kicker's favorites.
    function userKeys() {
        const keep = ["savedDesktopTheme", "savedDecoLibrary", "savedDecoTheme", "savedColorScheme", "savedBlur", "resetRequest", "openSettingsRequest", "designRequest", "favorites", "favoritesPortedToKAstats"];
        return root.cfg.keys().filter(k => !k.endsWith("Default") && !keep.includes(k));
    }
    // Restore: read the backup JSON, write back every known key, then put the Plasma Style in line
    // (xpTheme changes call syncDesktopTheme too; the explicit call covers an unchanged xpTheme).
    P5Support.DataSource {
        id: backupReader
        engine: "executable"
        connectedSources: []
        onNewData: (sourceName, data) => {
            disconnectSource(sourceName);
            let s = null;
            try { s = JSON.parse(data.stdout).settings; } catch (e) {}
            if (!s) {
                console.warn("start12: not a Start12 backup:", sourceName, data.stderr);
                return;
            }
            for (const k of root.userKeys()) {
                if (s[k] !== undefined)
                    root.cfg[k] = s[k];
            }
            root.syncDesktopTheme();
            root.readBrightness();
        }
    }
    property string doneReset: ""
    Connections {
        target: root.cfg
        // The settings window re-writes its old resetRequest on every later Apply: run each request once.
        function onResetRequestChanged() {
            const v = root.cfg.resetRequest;
            if (!v || v === root.doneReset) return;
            root.doneReset = v;
            const w = v.split("|")[0];
            if (["all", "positions", "backup", "restore"].includes(w)) {
                resetTimer.what = w;
                resetTimer.restart();
            }
        }
    }

    // Per-tile icon and colour pickers, shared by all tiles.
    property string pickingTile: ""
    KIconThemes.IconDialog {
        id: iconDialog
        onIconNameChanged: name => {
            if (root.pickingTile && name) {
                root.saveGroups(Tiles.setProp(root.groups, root.pickingTile, "icon", name));
            }
        }
    }
    Dialogs.ColorDialog {
        id: colorDialog
        property var apply: null   // set by askColour; null = tile colour
        onAccepted: apply ? apply(selectedColor.toString()) : root.saveGroups(Tiles.setProp(root.groups, root.pickingTile, "color", selectedColor.toString()))
    }
    function pickTileIcon(id) {
        pickingTile = id;
        close();
        iconDialog.open();
    }
    Dialogs.FileDialog {
        id: tileImageDialog
        title: i18n("Pick tile image…")
        nameFilters: [i18n("Images (*.png *.jpg *.jpeg *.webp *.svg)")]
        onAccepted: root.saveGroups(Tiles.setProp(root.groups, root.pickingTile, "image",
            decodeURIComponent(selectedFile.toString().replace("file://", ""))))
    }
    Dialogs.FileDialog {
        id: photoFileDialog
        title: i18n("Choose picture…")
        nameFilters: [i18n("Images (*.png *.jpg *.jpeg *.webp *.svg)")]
        onAccepted: root.saveGroups(Tiles.setProp(root.groups, root.pickingTile, "photo",
            decodeURIComponent(selectedFile.toString().replace("file://", ""))))
    }
    Dialogs.FolderDialog {
        id: photoFolderDialog
        title: i18n("Choose folder…")
        onAccepted: root.saveGroups(Tiles.setProp(root.groups, root.pickingTile, "photo",
            "dir:" + decodeURIComponent(selectedFolder.toString().replace("file://", ""))))
    }
    function pickPhoto(id, folder) {
        pickingTile = id;
        close();
        (folder ? photoFolderDialog : photoFileDialog).open();
    }
    function pickTileImage(id) {
        pickingTile = id;
        close();
        tileImageDialog.open();
    }
    function pickTileColor(id, current) {
        pickingTile = id;
        colorDialog.apply = null;
        colorDialog.selectedColor = current || "#3a3a44";
        close();
        colorDialog.open();
    }
    // Same dialogs for canvas groups: fn(colour) / fn(folderUrl) runs on OK.
    function askColour(current, fn) {
        colorDialog.apply = fn;
        colorDialog.selectedColor = current || "#3a3a44";
        close();
        colorDialog.open();
    }
    function askFolder(fn) {
        close();
        pinFolderDialog.apply = fn;
        pinFolderDialog.open();
    }
    // Desktop ids of installed Steam games (Steam writes <Game>.desktop with steam://rungameid), for fn(ids).
    property var steamDone: null
    // Filtered folders (T17): [{ name, path, include, exclude }]; folderUrl(f) = its file url.
    readonly property var filteredFolders: Tiles.parseFiltered(cfg.filteredFolders)
    function folderUrl(f) { return Tiles.dirUrl(f.path, StandardPaths.writableLocation(StandardPaths.HomeLocation)); }
    function listSteamGames(fn) {
        steamDone = fn;
        steamLister.connectSource("grep -l steam://rungameid ~/.local/share/applications/*.desktop; true");
    }
    P5Support.DataSource {
        id: steamLister
        engine: "executable"
        connectedSources: []
        onNewData: (sourceName, data) => {
            disconnectSource(sourceName);
            const ids = (data.stdout || "").split("\n").filter(l => l).map(l => l.split("/").pop());
            if (root.steamDone) root.steamDone(ids);
            root.steamDone = null;
        }
    }

    // "Pin website / file / folder" from the menu-surface right-click menus.
    Dialogs.FileDialog {
        id: pinFileDialog
        title: i18n("Pin file to Start")
        onAccepted: root.pin(Tiles.customFor(selectedFile.toString(), "file"))
    }
    Dialogs.FolderDialog {
        id: pinFolderDialog
        property var apply: null   // set by askFolder; null = pin the folder
        title: apply ? i18n("Add a folder as group") : i18n("Pin folder to Start")
        onAccepted: apply ? apply(selectedFolder.toString()) : root.pin(Tiles.customFor(selectedFolder.toString(), "folder"))
    }
    // A plain window: the popup is closed, so an in-popup Kirigami dialog can't show.
    Window {
        id: webDialog
        title: i18n("Pin website to Start")
        width: Kirigami.Units.gridUnit * 22
        height: webLayout.implicitHeight + Kirigami.Units.largeSpacing * 2
        color: Kirigami.Theme.backgroundColor
        onVisibleChanged: if (visible) { requestActivate(); webField.forceActiveFocus(); }
        function accept() {
            const u = webField.text.trim();
            if (u) root.pin(Tiles.customFor(/^\w+:\/\//.test(u) ? u : "https://" + u, "web", cfg.webFavicons));
            webField.text = "";
            close();
        }
        ColumnLayout {
            id: webLayout
            anchors.fill: parent
            anchors.margins: Kirigami.Units.largeSpacing
            QQC2.Label { text: i18n("Web address:") }
            QQC2.TextField {
                id: webField
                Layout.fillWidth: true
                placeholderText: "https://…"
                onAccepted: webDialog.accept()
                Keys.onEscapePressed: webDialog.close()
            }
            RowLayout {
                Layout.alignment: Qt.AlignRight
                QQC2.Button { text: i18n("Pin"); icon.name: "window-pin"; onClicked: webDialog.accept() }
                QQC2.Button { text: i18n("Cancel"); icon.name: "dialog-cancel"; onClicked: webDialog.close() }
            }
        }
    }
    Window {
        id: renameDialog
        property string pinId: ""
        property var apply: null
        title: i18n("Rename")
        width: Kirigami.Units.gridUnit * 18
        height: renameLayout.implicitHeight + Kirigami.Units.largeSpacing * 2
        color: Kirigami.Theme.backgroundColor
        onVisibleChanged: if (visible) { requestActivate(); renameField.forceActiveFocus(); renameField.selectAll(); }
        function accept() {
            if (apply) apply(renameField.text.trim());
            else root.setCap(pinId, renameField.text.trim());
            close();
        }
        ColumnLayout {
            id: renameLayout
            anchors.fill: parent
            anchors.margins: Kirigami.Units.largeSpacing
            QQC2.Label { text: renameDialog.apply ? i18n("Name:") : i18n("Name (empty = original):") }
            QQC2.TextField {
                id: renameField
                Layout.fillWidth: true
                onAccepted: renameDialog.accept()
                Keys.onEscapePressed: renameDialog.close()
            }
            RowLayout {
                Layout.alignment: Qt.AlignRight
                QQC2.Button { text: i18n("OK"); icon.name: "dialog-ok"; onClicked: renameDialog.accept() }
                QQC2.Button { text: i18n("Cancel"); icon.name: "dialog-cancel"; onClicked: renameDialog.close() }
            }
        }
    }
    function pinNew(kind) {
        close();
        if (kind === "web") webDialog.show();
        else if (kind === "file") pinFileDialog.open();
        else {
            pinFolderDialog.apply = null;
            pinFolderDialog.open();
        }
    }
    // Menu-surface entries for TileArea and PinnedGrid.
    readonly property var pinNewItems: [
        { text: i18n("Pin website…"), icon: "internet-web-browser", run: () => root.pinNew("web") },
        { text: i18n("Pin file…"), icon: "document-new", run: () => root.pinNew("file") },
        { text: i18n("Pin folder…"), icon: "folder-new", run: () => root.pinNew("folder") }
    ]

    // "Add widget" submenu (TileArea, TileGroup): a new kind = Tiles.WIDGETS + here + Tile.widgetFile + widgets/<Kind>.qml.
    readonly property var widgetItems: [["clock", i18n("Clock")], ["calendar", i18n("Calendar")], ["sysmon", i18n("System monitor")],
        ["drives", i18n("Drives")], ["weather", i18n("Weather")], ["notes", i18n("Notes")], ["photo", i18n("Photo")]]
        .map(k => ({ kind: k[0], text: k[1], run: () => savePages(Tiles.addWidget(pages, tilePage, k[0])) }))

    onExpandedChanged: {
        if (root.expanded) {
            rootModel.refresh();
        } else {
            searchText = "";
            designMode = false;
        }
    }

    // Full screen menu (UseFullScreenMenu): the popup takes the screen size, or the screen minus
    // the panels with SemiFull. Win10 tile groups then wrap into more columns (TileArea Flow).
    readonly property rect fullRect: {
        const c = Plasmoid.containment;
        const r = c ? (cfg.keepPanelVisible ? c.availableScreenRect : c.screenGeometry) : null;
        return r && r.width > 0 ? Qt.rect(0, 0, r.width, r.height) : Qt.rect(0, 0, 1280, 800);
    }
    // Win10/Win11 stretch over the full-screen popup; the narrow styles keep their size and sit
    // centred on a dim backdrop (Metrics.heightFor gives them their normal height).
    readonly property bool fillScreen: cfg.fullScreen && (styleFile === "windows10" || styleFile === "windows11")
    readonly property bool narrowFull: cfg.fullScreen && !fillScreen

    Plasmoid.icon: "start-here-kde"
    // On the desktop (or in a test window) show the menu itself.
    preferredRepresentation: Plasmoid.formFactor === PlasmaCore.Types.Planar ? fullRepresentation : compactRepresentation
    compactRepresentation: StartButton {}

    fullRepresentation: Item {
        id: full
        focus: true

        // The style gives the start size; the user can drag the popup edges to resize it.
        Layout.preferredWidth: root.cfg.fullScreen ? root.fullRect.width
                             : styleLoader.item ? styleLoader.item.implicitWidth : 600
        Layout.preferredHeight: root.cfg.fullScreen ? root.fullRect.height
                              : styleLoader.item ? styleLoader.item.implicitHeight : 600
        // Plasma keeps the user's dragged popup size and ignores preferred sizes, so full screen
        // forces the size through the minimum.
        Layout.minimumWidth: root.cfg.fullScreen ? root.fullRect.width
                           : designW > 0 ? designW
                           : shrink && styleLoader.item ? styleLoader.item.implicitWidth
                           : styleLoader.item && styleLoader.item.minimumWidth ? styleLoader.item.minimumWidth : 300
        // Design mode: Plasma keeps the dragged popup width, so pin it (min = max) at the opening width
        // plus whatever the style's implicitWidth gains from a divider (Win10 list, App canvas): the
        // section right of the divider keeps its size. Styles whose divider side is fixed on the right
        // keep implicitWidth, so the popup stays put and the left side gives way.
        property real designBase: 0
        readonly property real designW: root.designMode && !root.cfg.fullScreen && styleLoader.item
                                        ? designBase + styleLoader.item.implicitWidth : 0
        Connections {
            target: root
            function onDesignModeChanged() {
                if (root.designMode && styleLoader.item) full.designBase = full.width - styleLoader.item.implicitWidth;
            }
        }
        Layout.minimumHeight: root.cfg.fullScreen ? root.fullRect.height
                            : shrink && styleLoader.item ? styleLoader.item.implicitHeight : Math.round(320 * root.cfg.uiScale)
        // Plasma keeps one saved popup size for every style. After leaving full screen or switching style
        // (or menu size), pin the popup once (min = max) at the style's own size until it has opened and
        // stored that size; the user can drag it afterwards as before.
        property bool shrink: false
        onShrinkChanged: if (shrink && root.expanded) shrinkDone.restart()   // style switched while open
        Layout.maximumWidth: designW > 0 ? designW
                           : shrink && styleLoader.item ? styleLoader.item.implicitWidth : Number.POSITIVE_INFINITY
        Layout.maximumHeight: shrink && styleLoader.item ? styleLoader.item.implicitHeight : Number.POSITIVE_INFINITY
        Connections {
            target: root.cfg
            function onFullScreenChanged() {
                if (!root.cfg.fullScreen) full.shrink = true;
            }
            function onMenuSizeChanged() { full.shrink = true; }
        }
        Connections {
            target: root
            function onStyleFileChanged() { full.shrink = true; }
        }
        Timer {
            id: shrinkDone
            interval: 1000
            onTriggered: full.shrink = false
        }

        // Remember a dragged height as the "Custom height" setting.
        Timer {
            id: saveHeight
            interval: 400
            onTriggered: {
                const h = Math.round(full.height / root.cfg.uiScale);
                if (root.expanded && !root.cfg.fullScreen && Math.abs(full.height - full.Layout.preferredHeight) > 2) {
                    root.cfg.menuHeight = h;
                }
            }
        }
        onHeightChanged: if (root.expanded) saveHeight.restart()

        // T42 Menu position (key menuPosition 0 left, 1 center, 2 right), horizontal panels only. The popup
        // (AppletPopup) lines its edge up with its visualParent, normally the Start button. For Center/Right it
        // gets StartButton.popupAnchor instead: an empty item in the panel, as wide as the popup, put under the
        // screen centre or at the right screen edge, so either alignment (LTR left edges, RTL right edges) lands
        // the popup there. Done while closed (and once when the popup window first appears) so it opens in place.
        readonly property var popupWindow: Window.window
        onPopupWindowChanged: place()
        onWidthChanged: if (!root.expanded) place()
        Connections {
            target: root
            function onExpandedChanged() { if (!root.expanded) full.place(); }
        }
        Connections {
            target: root.cfg
            function onMenuPositionChanged() { full.place(); }
        }
        function place() {
            const w = popupWindow, btn = root.compactRepresentationItem;
            if (!w || !btn || !btn.popupAnchor || w.visualParent === undefined) return;
            const g = Plasmoid.containment ? Plasmoid.containment.screenGeometry : null;
            const pos = Plasmoid.formFactor === PlasmaCore.Types.Horizontal && !root.cfg.fullScreen && g && g.width > 0 ? root.cfg.menuPosition : 0;
            if (pos !== 1 && pos !== 2) {
                if (w.visualParent !== btn) w.visualParent = btn;
                return;
            }
            // The anchor lives in the panel window's root item, not in the button: the button moves when
            // centerTaskbar adds its spacers and a button-relative x went stale (popup opened off-centre).
            const a = btn.popupAnchor, o = btn.mapToGlobal(0, 0), sc = btn.mapToItem(null, 0, 0);
            if (btn.Window.contentItem && a.parent !== btn.Window.contentItem) a.parent = btn.Window.contentItem;
            a.width = w.width;
            a.y = sc.y;
            a.x = (pos === 1 ? g.x + (g.width - w.width) / 2 : g.x + g.width - w.width) - (o.x - sc.x);
            w.visualParent = a;
        }

        // Open animation (Start11 "NoAnims" inverse): short fade + slide in.
        ParallelAnimation {
            id: openAnim
            NumberAnimation { target: full; property: "opacity"; from: 0; to: 1; duration: Kirigami.Units.shortDuration }
            NumberAnimation { target: styleLoader; property: "anchors.topMargin"; from: Kirigami.Units.gridUnit; to: 0; duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic }
        }
        Connections {
            target: root
            function onExpandedChanged() {
                if (root.expanded && full.shrink) shrinkDone.restart();
                if (root.expanded && root.cfg.animateMenu) openAnim.restart();
                else { openAnim.stop(); full.opacity = 1; styleLoader.anchors.topMargin = 0; }
            }
        }

        // Narrow style in full screen: dim the rest of the screen, click it to close.
        Rectangle {
            anchors.fill: parent
            visible: root.narrowFull
            color: Qt.rgba(0, 0, 0, 0.5)
            MouseArea { anchors.fill: parent; onClicked: root.expanded = false }
        }

        Item {
            id: frame
            readonly property int gapX: root.narrowFull && styleLoader.item ? Math.max(0, (full.width - styleLoader.item.implicitWidth) / 2) : 0
            readonly property int gapY: root.narrowFull && styleLoader.item ? Math.max(0, full.height - styleLoader.item.implicitHeight) : 0
            readonly property bool atTop: Plasmoid.location === PlasmaCore.Types.TopEdge
            // T42 Menu position Right: the whole menu mirrored (anchors, rows, lists, split handles; styles flip
            // their explicit x with LayoutMirroring.enabled). Tile grids keep their own order inside.
            LayoutMirroring.enabled: root.cfg.menuPosition === 2
            LayoutMirroring.childrenInherit: true
            anchors.fill: parent
            anchors.leftMargin: gapX
            anchors.rightMargin: gapX
            anchors.topMargin: (atTop ? 0 : gapY) + (root.designMode ? designBar.height : 0)   // sits on the panel side; design bar above
            anchors.bottomMargin: atTop ? gapY : 0

            Loader {
                id: styleLoader
                anchors.fill: parent
                focus: true
                source: "styles/" + root.styleFile + ".qml"
            }
        }

        // Design mode bar above the menu (the menu moves down, nothing is covered).
        Rectangle {
            id: designBar
            visible: root.designMode
            anchors.left: frame.left
            anchors.right: frame.right
            anchors.bottom: frame.top
            height: designRow.implicitHeight + Kirigami.Units.smallSpacing * 2
            color: Kirigami.Theme.highlightColor
            RowLayout {
                id: designRow
                anchors.fill: parent
                anchors.margins: Kirigami.Units.smallSpacing
                QQC2.Label {
                    Layout.fillWidth: true
                    text: i18n("Design mode — drag the dividers")
                    color: Kirigami.Theme.highlightedTextColor
                    elide: Text.ElideRight
                }
                QQC2.Button {
                    text: i18n("Reset")
                    icon.name: "edit-reset"
                    onClicked: root.cfg.splits = Tiles.splitReset(root.cfg.splits, root.cfg.menuStyle)
                }
                QQC2.Button {
                    text: i18n("Done")
                    icon.name: "dialog-ok"
                    onClicked: root.designMode = false
                }
            }
        }
    }

    // Start button right-click menu (Start11: run item, shutdown option, explorer link, ...).
    function hasMenuItem(id) {
        return cfg.buttonMenuItems.includes(id);
    }
    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: i18n("Settings")
            icon.name: "systemsettings"
            visible: root.hasMenuItem("settings")
            onTriggered: root.run("systemsettings")
        },
        PlasmaCore.Action {
            text: i18n("File Explorer")
            icon.name: "system-file-manager"
            visible: root.hasMenuItem("files")
            onTriggered: root.run("dolphin")
        },
        PlasmaCore.Action {
            text: i18n("System Monitor")
            icon.name: "utilities-system-monitor"
            visible: root.hasMenuItem("monitor")
            onTriggered: root.run("plasma-systemmonitor")
        },
        PlasmaCore.Action {
            text: i18n("Terminal")
            icon.name: "utilities-terminal"
            visible: root.hasMenuItem("terminal")
            onTriggered: root.run("konsole")
        },
        PlasmaCore.Action {
            text: i18n("Run…")
            icon.name: "system-run"
            visible: root.hasMenuItem("run")
            onTriggered: root.run("krunner")
        },
        PlasmaCore.Action {
            text: i18n("Show desktop")
            icon.name: "user-desktop"
            visible: root.hasMenuItem("desktop")
            onTriggered: root.run("" + Tiles.QDBUS + " org.kde.kglobalaccel /component/kwin invokeShortcut \"Show Desktop\"")
        },
        PlasmaCore.Action {
            text: i18n("Edit panel")
            icon.name: "configure-toolbars"
            visible: root.hasMenuItem("editpanel")
            onTriggered: root.run("" + Tiles.QDBUS + " org.kde.plasmashell /PlasmaShell org.freedesktop.DBus.Properties.Set org.kde.PlasmaShell editMode true")
        },
        PlasmaCore.Action {
            text: i18n("Auto-hide panel")
            icon.name: "view-fullscreen"
            visible: root.hasMenuItem("autohide")
            // flips hiding of the panel holding this widget (found by widget id)
            onTriggered: root.run("" + Tiles.QDBUS + " org.kde.plasmashell /PlasmaShell evaluateScript 'for (const p of panels()) { if (p.widgetIds.indexOf(" + Plasmoid.id + ") >= 0) p.hiding = (p.hiding == \"none\" ? \"autohide\" : \"none\"); }'")
        },
        PlasmaCore.Action {
            isSeparator: true
            visible: root.hasMenuItem("power")
        },
        PlasmaCore.Action {
            text: i18n("Lock")
            icon.name: "system-lock-screen"
            visible: root.hasMenuItem("power")
            onTriggered: root.runSystemAction("lock-screen")
        },
        PlasmaCore.Action {
            text: i18n("Sign out")
            icon.name: "system-log-out"
            visible: root.hasMenuItem("power")
            onTriggered: root.runSystemAction("logout")
        },
        PlasmaCore.Action {
            text: i18n("Sleep")
            icon.name: "system-suspend"
            visible: root.hasMenuItem("power")
            onTriggered: root.runSystemAction("suspend")
        },
        PlasmaCore.Action {
            text: i18n("Restart")
            icon.name: "system-reboot"
            visible: root.hasMenuItem("power")
            onTriggered: root.runSystemAction("reboot")
        },
        PlasmaCore.Action {
            text: i18n("Shut down")
            icon.name: "system-shutdown"
            visible: root.hasMenuItem("power")
            onTriggered: root.runSystemAction("shutdown")
        },
        PlasmaCore.Action {
            isSeparator: true
        },
        PlasmaCore.Action {
            text: i18n("Edit menu layout")
            icon.name: "transform-move-horizontal"
            onTriggered: root.editLayout()
        },
        PlasmaCore.Action {
            text: i18nc("@action:inmenu", "Edit Applications…")
            icon.name: "kmenuedit"
            visible: Plasmoid.immutability !== PlasmaCore.Types.SystemImmutable
            onTriggered: processRunner.runMenuEditor()
        }
    ]

    Component.onCompleted: {
        Plasmoid.activationTogglesExpanded = true;
        rootModel.refresh();
        systemModel = systemModelComponent.createObject(root, { favoritesModel: rootModel.systemFavoritesModel });
        // T44: code/setup.sh makes the generated themes first (KDE Store installs skip install.sh), then the syncs apply them.
        setupRunner.connectSource("sh " + Tiles.shQuote(decodeURIComponent(Qt.resolvedUrl("code/setup.sh").toString().replace("file://", ""))));
    }
    P5Support.DataSource {
        id: setupRunner
        engine: "executable"
        connectedSources: []
        onNewData: sourceName => {
            disconnectSource(sourceName);
            root.syncDesktopTheme();
            root.readBrightness();   // then syncWindowDeco + syncWindowColors
        }
    }
}
