pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PC3
import org.kde.plasma.private.kicker as Kicker
import org.kde.kirigami as Kirigami
import org.kde.kitemmodels as KItemModels
import Qt.labs.folderlistmodel
import "../code/tiles.js" as Tiles

// Start11 v2 "application canvas": tabs, each with Fences-like groups of icons.
// Built-in tabs: Pinned (Pin to Start lands here), Apps (one group per KDE category), Recent.
// User tabs after them (key canvasLayout, Tiles.parseCanvas): own groups of apps, filled by dragging
// apps in from the list or between groups. Right-click a tab / group header / empty space for the menus.
// Groups get a colour and a recoloured texture from images/TabTextures, like Start11.
// Group header menu (T16): colour, icon tinting / auto tint, rows, icon size, texture, launch all, A-Z.
// Group sources: a folder (FolderListModel lists its files) or the installed Steam games.
Item {
    id: canvas

    required property QtObject metrics
    required property var contextMenu
    required property Item ghost
    readonly property QtObject m: metrics
    readonly property var cfg: Plasmoid.configuration
    property int tabSel: cfg.canvasTab
    readonly property int tab: Math.max(0, Math.min(tabSel, tabs.length - 1))
    property int rev: 0
    readonly property var layout: Tiles.parseCanvas(cfg.canvasLayout)
    readonly property int user: tab - 3   // index into layout.tabs, < 0 on a built-in tab

    readonly property real pad: m.px(8)
    readonly property real cellW: m.px(76)
    readonly property real cellH: m.px(72)
    readonly property real groupW: 4 * cellW + m.px(8)

    function reset() {
        rev++;
        tabSel = cfg.canvasTab;
        recentDocs.refresh();
        flick.contentY = 0;
    }

    Kicker.SimpleFavoritesModel {
        id: pinnedModel
        favorites: Tiles.allPins(canvas.cfg.pinnedGrid)
    }
    Kicker.RecentUsageModel {
        id: recentDocs
        favoritesModel: root.rootModel.favoritesModel
        shownItems: Kicker.RecentUsageModel.OnlyDocs
    }

    readonly property var tabs: [i18n("Pinned"), i18n("Apps"), i18n("Recent")].concat(layout.tabs.map(t => t.name))
    function save(c) { cfg.canvasLayout = JSON.stringify(c); }
    // Drops app id into group g of the current user tab, before app "before" ("" = at the end).
    function place(id, g, before) {
        id = String(id || "").replace(/^applications:/, "");
        if (user >= 0 && id && !id.startsWith("file:") && !Tiles.custom(id) && !Tiles.isFolder(id))
            save(Tiles.canvasPlace(layout, user, id, g, before, i18n("New group")));
    }
    function newTab() {
        save(Tiles.canvasAddTab(layout, i18n("New tab")));
        tabSel = tabs.length;   // clamped to the last tab = the new one
    }
    // Empty space / tab menu.
    readonly property var surfaceItems: [
        { text: i18n("New tab"), icon: "tab-new", run: () => canvas.newTab() }
    ].concat(user >= 0 ? [{ text: i18n("Add group"), icon: "list-add", run: () => canvas.addGroup() },
                          { text: i18n("Add a folder as group…"), icon: "folder-new", run: () => canvas.addFolder() },
                          { text: i18n("Add Steam folder"), icon: "applications-games", run: () => canvas.addSteam() }] : []).concat([
        { text: i18n("Always open on this tab"), icon: "bookmark-new", checkable: true, checked: cfg.canvasTab === tab,
          run: () => { canvas.cfg.canvasTab = canvas.tab; } }
    ])
    function addGroup() { save(Tiles.canvasAddGroup(layout, user, i18n("New group"))); }
    // New group g on tab u with one setting, read from the layout at call time (dialogs are async).
    function addGroupWith(u, name, key, value) {
        const c = Tiles.canvasAddGroup(layout, u, name);
        save(Tiles.canvasSet(c, u, c.tabs[u].groups.length - 1, key, value));
    }
    function addFolder() {
        const u = user;
        root.askFolder(url => canvas.addGroupWith(u, decodeURIComponent(url.replace(/\/$/, "").split("/").pop()), "folder", url));
    }
    // ponytail: Steam games are read once into a normal group; "Add Steam folder" again picks up new ones.
    function addSteam() {
        const u = user;
        root.listSteamGames(ids => canvas.addGroupWith(u, "Steam", "ids", ids));
    }
    function set(g, key, value) { save(Tiles.canvasSet(layout, user, g, key, value)); }
    // Groups of the current tab: { name, src }. ("model" would clash with the Repeater's own.)
    readonly property var groups: {
        rev;
        if (tab === 0) {
            // Pinned websites/files/folders: { name, custom: [Tiles.custom...] } instead of a model.
            const custom = canvas.cfg.pinnedGrid.map(id => Tiles.custom(id)).filter(c => c);
            return [{ name: i18n("Pinned"), src: pinnedModel }]
                .concat(custom.length ? [{ name: i18n("Shortcuts"), custom: custom }] : []);
        }
        if (user >= 0) return (layout.tabs[user]?.groups ?? []).map((g, i) => Object.assign({}, g, { g: i }));
        if (tab === 2) return [{ name: i18n("Most used"), src: root.frequentAppsModel },
                               { name: i18n("Recent files"), src: recentDocs }];
        const rm = root.rootModel;
        const out = [];
        for (let r = 2; r < rm.count; r++) {
            const sub = rm.modelForRow(r);
            if (sub) out.push({ name: rm.data(rm.index(r, 0), Qt.DisplayRole), src: sub });
        }
        return out.sort((a, b) => a.name.localeCompare(b.name));
    }
    Connections {
        target: root.rootModel
        function onRefreshed() { canvas.rev++; }
    }

    function roleData(model, row, name) {
        return model.data(model.index(row, 0), model.KItemModels.KRoleNames.role(name));
    }
    // RecentUsageModel ids are "applications:x.desktop"; pins are plain "x.desktop".
    function appId(model, row) {
        return (roleData(model, row, "favoriteId") || "").replace(/^applications:/, "");
    }
    // Each group gets its own hue, starting from the accent colour.
    function groupColor(i) {
        return Qt.hsla((Math.max(0, m.accent.hslHue) + i * 0.13) % 1, 0.45, 0.42, 1);
    }

    // Tab chips, like Start11's "Notes | Games | Photo".
    Row {
        id: tabRow
        spacing: m.px(2)
        Repeater {
            model: canvas.tabs
            delegate: PC3.AbstractButton {
                id: tabButton
                required property string modelData
                required property int index
                readonly property bool current: canvas.tab === index
                height: m.px(24)
                hoverEnabled: true
                leftPadding: m.px(10)
                rightPadding: m.px(10)
                onClicked: canvas.tabSel = index
                TapHandler {
                    acceptedButtons: Qt.RightButton
                    onTapped: point => {
                        canvas.tabSel = tabButton.index;
                        const u = tabButton.index - 3;
                        const own = u < 0 ? [] : [
                            { text: i18n("Rename"), icon: "edit-rename",
                              run: () => root.askName(canvas.layout.tabs[u].name, n => canvas.save(Tiles.canvasRename(canvas.layout, u, -1, n))) },
                            { text: i18n("Move tab left"), icon: "go-previous", enabled: u > 0,
                              run: () => { canvas.save(Tiles.canvasMoveTab(canvas.layout, u, -1)); canvas.tabSel--; } },
                            { text: i18n("Move tab right"), icon: "go-next", enabled: u < canvas.layout.tabs.length - 1,
                              run: () => { canvas.save(Tiles.canvasMoveTab(canvas.layout, u, 1)); canvas.tabSel++; } },
                            { text: i18n("Delete tab"), icon: "edit-delete", run: () => canvas.save(Tiles.canvasDeleteTab(canvas.layout, u)) }];
                        canvas.contextMenu.show(tabButton, null, -1, own.concat(canvas.surfaceItems), point.position.x, point.position.y);
                    }
                }
                background: Rectangle {
                    radius: m.px(3)
                    color: Qt.alpha(m.text, tabButton.current ? 0.18 : tabButton.pressed ? 0.15 : tabButton.hovered ? 0.1 : 0.05)
                }
                contentItem: PC3.Label {
                    text: tabButton.modelData
                    color: m.text
                    font.family: m.font
                    font.pixelSize: Math.round(m.fontSize * 0.9)
                    font.weight: tabButton.current ? Font.DemiBold : Font.Normal
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }
    }

    Flickable {
        id: flick
        anchors.top: tabRow.bottom
        anchors.topMargin: canvas.pad
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        clip: true
        contentHeight: Math.max(flow.implicitHeight, height)   // empty space below the groups takes right-clicks
        boundsBehavior: Flickable.StopAtBounds
        QQC2.ScrollBar.vertical: PC3.ScrollBar {}

        TapHandler {
            acceptedButtons: Qt.RightButton
            onTapped: point => canvas.contextMenu.show(flick, null, -1, canvas.surfaceItems, point.position.x, point.position.y)
        }
        // Empty space of a user tab: drop makes a new group.
        DropArea {
            width: flick.width
            height: Math.max(flick.height, flow.implicitHeight)
            enabled: canvas.user >= 0
            keys: ["start12-tile"]
            onDropped: d => canvas.place(d.source.favoriteId, canvas.groups.length, "")
        }

        Flow {
            id: flow
            width: flick.width - m.px(12)
            spacing: canvas.pad
            // As many groups per line as fit; they stretch to fill the line.
            readonly property int lineCount: Math.max(1, Math.floor((width + canvas.pad) / (canvas.groupW + canvas.pad)))
            readonly property real groupWidth: (width - (lineCount - 1) * canvas.pad) / lineCount
            Repeater {
                model: canvas.groups
                delegate: Rectangle {
                    id: group
                    required property var modelData
                    required property int index
                    readonly property bool isUser: modelData?.ids !== undefined
                    readonly property string folder: modelData?.folder ?? ""
                    readonly property bool takesDrops: isUser && !folder
                    readonly property var src: modelData?.src ?? (folder ? folderModel : isUser ? own : null)
                    readonly property color tint: modelData?.tint === "auto" && autoTint.dominant.valid ? autoTint.dominant
                                                  : modelData?.colour || canvas.groupColor(index)
                    readonly property var customs: modelData?.custom ?? null
                    readonly property real iconSize: m.px(modelData?.iconSize || 28)
                    readonly property int texture: modelData?.texture ?? 0
                    readonly property int needRows: Math.max(1, Math.ceil(count / cols))
                    readonly property int shownRows: modelData?.rows > 0 ? Math.min(modelData.rows, needRows) : needRows
                    function iconOf(row) {
                        if (customs) return customs[row]?.icon || "folder";
                        if (!src || row < 0) return "";
                        if (folder) return Tiles.fileIcon(src.get(row, "fileName"), src.get(row, "fileIsDir"));
                        return canvas.roleData(src, row, "decoration");
                    }
                    function launchAll() {
                        const rs = rows.slice();   // triggering may reorder Most used
                        for (let i = 0; i < count; i++) {
                            if (customs) root.openCustom(customs[i]);
                            else if (folder) Qt.openUrlExternally(src.get(rs[i], "fileUrl"));
                            else src.trigger(rs[i], "", null);
                        }
                        root.close();
                    }
                    function sortAZ() {
                        const names = {};
                        for (let r = 0; r < own.count; r++) names[canvas.appId(own, r)] = canvas.roleData(own, r, "display");
                        canvas.save(Tiles.canvasSort(canvas.layout, canvas.user, modelData.g, names));
                    }
                    // "Auto tint": the group takes the main colour of its first icon.
                    Kirigami.ImageColors {
                        id: autoTint
                        source: group.modelData?.tint === "auto" && group.count ? group.iconOf(group.customs ? 0 : group.rows[0]) : ""
                        onSourceChanged: update()
                    }
                    FolderListModel {
                        id: folderModel
                        folder: group.folder
                        showDirsFirst: true
                    }
                    // Header right-click: settings of a user group; Launch entire group on every group.
                    function menuItems() {
                        const d = modelData, g = d.g;
                        const launch = { text: i18n("Launch entire group"), icon: "system-run", enabled: count > 0, run: () => group.launchAll() };
                        if (!isUser) return [launch];
                        const pick = (key, list) => list.map(o => ({ text: o[0], checkable: true, checked: (d[key] ?? o[2]) === o[1],
                                                                  run: () => canvas.set(g, key, o[1]) }));
                        const textures = [[i18n("Automatic"), 0, 0], [i18n("None"), -1]];
                        for (let i = 1; i <= 24; i++) textures.push([i18n("Texture %1", i), i]);
                        return [
                            { text: i18n("Rename"), icon: "edit-rename",
                              run: () => root.askName(d.name, n => canvas.save(Tiles.canvasRename(canvas.layout, canvas.user, g, n))) },
                            { text: i18n("Colour…"), icon: "color-management", run: () => root.askColour(d.colour || tint, c => canvas.set(g, "colour", c)) },
                            { text: i18n("Automatic colour"), checkable: true, checked: !d.colour, run: () => canvas.set(g, "colour", "") },
                            { text: i18n("Icon tinting"), checkable: true, checked: d.tint === "icons", run: () => canvas.set(g, "tint", d.tint === "icons" ? "" : "icons") },
                            { text: i18n("Auto tint"), checkable: true, checked: d.tint === "auto", run: () => canvas.set(g, "tint", d.tint === "auto" ? "" : "auto") },
                            { text: i18n("Rows"), icon: "view-grid", subActions: pick("rows", [[i18n("Automatic"), 0, 0], ["1", 1], ["2", 2], ["3", 3], ["4", 4], ["5", 5], ["6", 6]]) },
                            { text: i18n("Icon size"), icon: "zoom-in", subActions: pick("iconSize", [[i18n("Small"), 22], [i18n("Medium"), 0, 0], [i18n("Large"), 40]]) },
                            { text: i18n("Background texture"), icon: "games-config-background", subActions: pick("texture", textures) },
                            { type: "separator" },
                            launch,
                            { text: i18n("Resort A-Z"), icon: "view-sort-ascending", enabled: !folder, run: () => group.sortAZ() },
                            { text: i18n("Delete group"), icon: "edit-delete", run: () => canvas.save(Tiles.canvasDeleteGroup(canvas.layout, canvas.user, g)) }];
                    }
                    // Source rows that are not hidden (pins stay), cell i shows src row rows[i].
                    readonly property var rows: {
                        const out = [];
                        const n = src ? src.count : 0;
                        canvas.cfg.hiddenApps;
                        for (let r = 0; r < n; r++)
                            if (isUser || src === pinnedModel || !root.isHidden(canvas.appId(src, r))) out.push(r);
                        return out;
                    }
                    readonly property int count: customs ? customs.length : rows.length
                    readonly property int cols: Math.max(1, Math.floor((width - m.px(8)) / canvas.cellW))
                    width: flow.groupWidth
                    height: header.height + shownRows * canvas.cellH + m.px(8)
                    radius: m.px(6)
                    color: Qt.alpha(tint, 0.22)
                    border.color: Qt.alpha(tint, 0.6)
                    clip: true

                    // User group: its apps (pinned folders/websites are not taken).
                    Kicker.SimpleFavoritesModel {
                        id: own
                        favorites: group.modelData?.ids ?? []
                    }
                    // Dropped on the group, not on an app: add at the end.
                    DropArea {
                        anchors.fill: parent
                        enabled: group.takesDrops
                        keys: ["start12-tile"]
                        onDropped: d => canvas.place(d.source.favoriteId, group.modelData.g, "")
                    }

                    // Grey Start11 texture, coloured by the tint under it.
                    Image {
                        anchors.fill: parent
                        visible: canvas.cfg.canvasTextures && group.texture >= 0
                        source: Qt.resolvedUrl("../../images/TabTextures/" + String(group.texture > 0 ? group.texture : group.index % 24 + 1).padStart(2, "0") + ".png")
                        fillMode: Image.Tile
                        opacity: 0.18
                    }

                    Rectangle {
                        id: header
                        width: parent.width
                        height: m.px(26)
                        radius: parent.radius
                        color: Qt.alpha(group.tint, 0.75)
                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.RightButton
                            onClicked: m => canvas.contextMenu.show(header, null, -1,
                                group.menuItems().concat([{ type: "separator" }], canvas.surfaceItems), m.x, m.y)
                        }
                        PC3.Label {
                            anchors.fill: parent
                            anchors.leftMargin: m.px(10)
                            anchors.rightMargin: m.px(10)
                            text: group.modelData?.name ?? ""
                            elide: Text.ElideRight
                            verticalAlignment: Text.AlignVCenter
                            color: "white"
                            font.family: m.font
                            font.pixelSize: Math.round(m.fontSize * 0.95)
                            font.weight: Font.DemiBold
                        }
                    }

                    PC3.Label {
                        visible: group.count === 0
                        anchors.top: header.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: m.px(10)
                        text: i18n("(Empty)")
                        color: m.text
                        opacity: 0.6
                        font.family: m.font
                        font.pixelSize: m.fontSize
                    }

                    // Rows setting: the group shows that many rows and scrolls the rest.
                    Flickable {
                        anchors.top: header.bottom
                        anchors.topMargin: m.px(4)
                        width: parent.width
                        height: group.shownRows * canvas.cellH
                        contentHeight: cellGrid.height
                        interactive: contentHeight > height
                        boundsBehavior: Flickable.StopAtBounds
                        clip: true
                    Grid {
                        id: cellGrid
                        x: (group.width - width) / 2
                        columns: group.cols
                        Repeater {
                            model: group.count
                            delegate: PC3.AbstractButton {
                                id: cell
                                required property int index
                                readonly property int row: group.rows[index] ?? -1
                                function role(name) {
                                    if (name === "decoration") return group.iconOf(group.customs ? index : row);
                                    if (group.customs) return name === "display" ? group.customs[index].name : undefined;
                                    if (group.folder) return name === "display" && row >= 0 ? group.src.get(row, "fileName") : undefined;
                                    // src is null for a moment while the groups are rebuilt
                                    return group.src ? canvas.roleData(group.src, row, name) : undefined;
                                }
                                width: canvas.cellW
                                height: canvas.cellH
                                hoverEnabled: true
                                onClicked: {
                                    if (group.customs) {
                                        root.openCustom(group.customs[index]);
                                        return;
                                    }
                                    if (group.folder) {
                                        root.openUrl(group.src.get(row, "fileUrl"));
                                        return;
                                    }
                                    group.src.trigger(row, "", null);
                                    root.close();
                                }
                                readonly property bool kbNav: true
                                KeyFrame {}
                                PC3.ToolTip.text: role("display") ?? ""
                                PC3.ToolTip.visible: hovered
                                PC3.ToolTip.delay: Kirigami.Units.toolTipDelay
                                background: Rectangle {
                                    radius: m.px(4)
                                    color: m.text
                                    opacity: cell.pressed || cellMouse.pressed ? 0.15 : cell.hovered ? 0.1 : 0
                                }
                                contentItem: Column {
                                    topPadding: m.px(6)
                                    spacing: m.px(4)
                                    Kirigami.Icon {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: group.iconSize
                                        height: width
                                        source: cell.role("decoration") ?? ""
                                        isMask: group.modelData?.tint === "icons"
                                        color: group.tint
                                    }
                                    PC3.Label {
                                        width: cell.width - m.px(8)
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        horizontalAlignment: Text.AlignHCenter
                                        text: cell.role("display") ?? ""
                                        elide: Text.ElideRight
                                        color: m.text
                                        font.family: m.font
                                        font.pixelSize: Math.round(m.fontSize * 0.85)
                                    }
                                }
                                function menu(x, y) {
                                    if (group.folder) return;   // plain files: no app actions
                                    if (group.customs) {
                                        const c = group.customs[index];
                                        canvas.contextMenu.show(cell, null, -1, [{ text: i18n("Unpin from Start"), icon: "window-unpin",
                                            run: () => root.unpin(c.id) }], x, y);
                                        return;
                                    }
                                    const id = canvas.appId(group.src, row);
                                    const own = !id || id.startsWith("file:") ? [] : root.isPinned(id)
                                        ? [{ text: i18n("Unpin from Start"), icon: "window-unpin", run: () => root.unpin(id) }]
                                        : [{ text: i18n("Pin to Start"), icon: "window-pin", run: () => root.pin(id) }];
                                    if (group.isUser) own.push({ text: i18n("Remove from group"), icon: "list-remove",
                                        run: () => canvas.save(Tiles.canvasRemove(canvas.layout, canvas.user, id)) });
                                    else if (id && !id.startsWith("file:")) own.push({ text: i18n("Hide from apps"), icon: "hint", run: () => root.hideApp(id) });
                                    canvas.contextMenu.show(cell, group.src, row, own, x, y);
                                }
                                // Drop on an app of a user group: insert before it.
                                DropArea {
                                    anchors.fill: parent
                                    enabled: group.takesDrops
                                    keys: ["start12-tile"]
                                    onDropped: d => canvas.place(d.source.favoriteId, group.modelData.g, canvas.appId(group.src, cell.row))
                                }
                                // Click, right-click, and drag (user groups only) like PinnedGrid.
                                MouseArea {
                                    id: cellMouse
                                    anchors.fill: parent
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    preventStealing: true
                                    property point pressPos
                                    property bool dragging: false
                                    onPressed: m => pressPos = Qt.point(m.x, m.y)
                                    onPositionChanged: m => {
                                        if (!dragging && pressed && group.takesDrops && Math.hypot(m.x - pressPos.x, m.y - pressPos.y) > Qt.styleHints.startDragDistance) {
                                            dragging = true;
                                            canvas.ghost.favoriteId = canvas.appId(group.src, cell.row);
                                            canvas.ghost.icon = cell.role("decoration");
                                            canvas.ghost.Drag.active = true;
                                        }
                                        if (dragging) {
                                            const p = mapToItem(canvas.ghost.parent, m.x, m.y);
                                            canvas.ghost.x = p.x - canvas.ghost.width / 2;
                                            canvas.ghost.y = p.y - canvas.ghost.height / 2;
                                        }
                                    }
                                    onReleased: m => {
                                        if (dragging) {
                                            canvas.ghost.Drag.drop();
                                            canvas.ghost.Drag.active = false;
                                            dragging = false;
                                        } else if (m.button === Qt.LeftButton && containsMouse) {
                                            cell.clicked();
                                        } else if (m.button === Qt.RightButton) {
                                            cell.menu(m.x, m.y);
                                        }
                                    }
                                    onCanceled: {
                                        canvas.ghost.Drag.active = false;
                                        dragging = false;
                                    }
                                }
                            }
                        }
                    }
                    }
                }
            }
        }
    }
}
