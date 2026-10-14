pragma ComponentBehavior: Bound

import QtQuick
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
        renameDialog.pinId = id;
        renameField.text = capOf(id) || current || "";
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
    readonly property string xpTheme: cfg.menuStyle !== "xp" || !cfg.xpTaskbarTheme ? ""
        : "start12-xp-" + cfg.xpSubstyle + (cfg.xpColor === "olive" || cfg.xpColor === "silver" ? "-" + cfg.xpColor
                                         : cfg.xpColor === "custom" ? "-custom-" + xpCustomHex : "")
    onXpThemeChanged: syncDesktopTheme()
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
            const ours = cur.startsWith("start12-xp-");
            if (root.xpTheme !== "") {
                if (cur === root.xpTheme)
                    return;
                if (!ours)
                    root.cfg.savedDesktopTheme = cur;
                if (root.xpTheme.includes("-custom-")) {
                    const dir = "$HOME/.local/share/plasma/desktoptheme/";
                    const gen = decodeURIComponent(Qt.resolvedUrl("code/xptheme.py").toString().replace("file://", ""));
                    root.run("sh -c 'rm -rf " + dir + "start12-xp-*-custom-*; python3 \"" + gen + "\" --custom "
                             + root.xpCustomHex + " --sub " + root.cfg.xpSubstyle + " --out " + dir + root.xpTheme
                             + " && plasma-apply-desktoptheme " + root.xpTheme + "'");
                } else {
                    root.run("plasma-apply-desktoptheme " + root.xpTheme);
                }
            } else if (ours) {
                root.run("plasma-apply-desktoptheme " + (root.cfg.savedDesktopTheme || "default"));
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
        const keep = ["savedDesktopTheme", "resetRequest", "openSettingsRequest", "favorites", "favoritesPortedToKAstats"];
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
        }
    }
    Connections {
        target: root.cfg
        function onResetRequestChanged() {
            const w = root.cfg.resetRequest.split("|")[0];
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
        onAccepted: root.saveGroups(Tiles.setProp(root.groups, root.pickingTile, "color", selectedColor.toString()))
    }
    function pickTileIcon(id) {
        pickingTile = id;
        close();
        iconDialog.open();
    }
    function pickTileColor(id, current) {
        pickingTile = id;
        colorDialog.selectedColor = current || "#3a3a44";
        close();
        colorDialog.open();
    }

    // "Pin website / file / folder" from the menu-surface right-click menus.
    Dialogs.FileDialog {
        id: pinFileDialog
        title: i18n("Pin file to Start")
        onAccepted: root.pin(Tiles.customFor(selectedFile.toString(), "file"))
    }
    Dialogs.FolderDialog {
        id: pinFolderDialog
        title: i18n("Pin folder to Start")
        onAccepted: root.pin(Tiles.customFor(selectedFolder.toString(), "folder"))
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
            if (u) root.pin(Tiles.customFor(/^\w+:\/\//.test(u) ? u : "https://" + u, "web"));
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
        title: i18n("Rename")
        width: Kirigami.Units.gridUnit * 18
        height: renameLayout.implicitHeight + Kirigami.Units.largeSpacing * 2
        color: Kirigami.Theme.backgroundColor
        onVisibleChanged: if (visible) { requestActivate(); renameField.forceActiveFocus(); renameField.selectAll(); }
        function accept() { root.setCap(pinId, renameField.text.trim()); close(); }
        ColumnLayout {
            id: renameLayout
            anchors.fill: parent
            anchors.margins: Kirigami.Units.largeSpacing
            QQC2.Label { text: i18n("Name (empty = original):") }
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
        else pinFolderDialog.open();
    }
    // Menu-surface entries for TileArea and PinnedGrid.
    readonly property var pinNewItems: [
        { text: i18n("Pin website…"), icon: "internet-web-browser", run: () => root.pinNew("web") },
        { text: i18n("Pin file…"), icon: "document-new", run: () => root.pinNew("file") },
        { text: i18n("Pin folder…"), icon: "folder-new", run: () => root.pinNew("folder") }
    ]

    onExpandedChanged: {
        if (root.expanded) {
            rootModel.refresh();
        } else {
            searchText = "";
        }
    }

    // Full screen menu (UseFullScreenMenu): the popup takes the screen size, or the screen minus
    // the panels with SemiFull. Win10 tile groups then wrap into more columns (TileArea Flow).
    readonly property rect fullRect: {
        const c = Plasmoid.containment;
        const r = c ? (cfg.keepPanelVisible ? c.availableScreenRect : c.screenGeometry) : null;
        return r && r.width > 0 ? Qt.rect(0, 0, r.width, r.height) : Qt.rect(0, 0, 1280, 800);
    }

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
        Layout.preferredHeight: styleLoader.item ? styleLoader.item.implicitHeight : 600
        Layout.minimumWidth: styleLoader.item && styleLoader.item.minimumWidth ? styleLoader.item.minimumWidth : 300
        Layout.minimumHeight: Math.round(320 * root.cfg.uiScale)

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

        Loader {
            id: styleLoader
            anchors.fill: parent
            focus: true
            source: "styles/" + root.styleFile + ".qml"
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
            onTriggered: root.run("qdbus6 org.kde.kglobalaccel /component/kwin invokeShortcut \"Show Desktop\"")
        },
        PlasmaCore.Action {
            text: i18n("Edit panel")
            icon.name: "configure-toolbars"
            visible: root.hasMenuItem("editpanel")
            onTriggered: Plasmoid.containment.corona.editMode = true
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
        syncDesktopTheme();
    }
}
