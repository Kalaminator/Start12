pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PC3
import org.kde.kirigami as Kirigami
import org.kde.kitemmodels as KItemModels
import "../common"

// Windows 10 all-apps list: optional "Recently added" / "Most used", then
// # A..Z with letter headers. Click a letter for the jump grid. Folders open in place.
Item {
    id: list

    required property QtObject metrics
    required property var contextMenu
    required property Item ghost

    readonly property var cfg: Plasmoid.configuration
    property var entries: []
    property var openFolders: ({})
    property bool jumpMode: false

    function roleData(model, row, name) {
        return model.data(model.index(row, 0), model.KItemModels.KRoleNames.role(name));
    }

    function letterOf(name) {
        const c = (name || "#").charAt(0).toLocaleUpperCase();
        return c.toLocaleLowerCase() !== c ? c : "#";   // letters only, digits/symbols -> #
    }

    function appEntries(model, depth) {
        const out = [];
        if (!model) return out;
        for (let r = 0; r < model.count; r++) {
            if (roleData(model, r, "isSeparator") || root.isHidden(roleData(model, r, "favoriteId"))) continue;
            out.push({ kind: "app", name: roleData(model, r, "display"), model: model, row: r, depth: depth });
        }
        return out;
    }

    function rebuild() {
        const rm = root.rootModel;
        const out = [];
        if (cfg.showRecentlyAdded) {
            const all = rm.modelForRow(1);
            const fresh = appEntries(all, 0).filter(e => roleData(e.model, e.row, "isNewlyInstalled")).slice(0, 3);
            if (fresh.length) out.push({ kind: "title", name: i18n("Recently added") }, ...fresh);
        }
        if (cfg.showMostUsed) {
            const used = appEntries(root.frequentAppsModel, 0).slice(0, 6);
            if (used.length) out.push({ kind: "title", name: i18n("Most used") }, ...used);
        }

        let items;
        if (cfg.categoryFolders) {
            items = [];
            for (let r = 2; r < rm.count; r++) {
                const sub = rm.modelForRow(r);
                if (!sub) continue;
                items.push({ kind: "folder", name: roleData(rm, r, "display"), icon: roleData(rm, r, "decoration"), model: sub, depth: 0 });
            }
            items.sort((a, b) => a.name.localeCompare(b.name));
        }

        // "Place folders at the bottom of the list": folders after all the letters.
        if (cfg.categoryFolders && cfg.foldersAtBottom) {
            items = items.filter(e => e.kind !== "folder").concat(items.filter(e => e.kind === "folder"));
        } else {
            items = appEntries(rm.modelForRow(1), 0);
        }

        let letter = null;
        for (const e of items) {
            const l = cfg.foldersAtBottom && e.kind === "folder" ? i18n("Folders") : letterOf(e.name);
            if (l !== letter) {
                letter = l;
                out.push({ kind: "header", name: l });
            }
            out.push(e);
            if (e.kind === "folder" && openFolders[e.name]) {
                out.push(...appEntries(e.model, 1));
            }
        }
        entries = out;
    }

    function reset() {
        jumpMode = false;
        openFolders = {};
        rebuild();
        view.positionViewAtBeginning();
    }

    function toggleFolder(name) {
        const f = Object.assign({}, openFolders);
        f[name] = !f[name];
        openFolders = f;
        const y = view.contentY;
        rebuild();
        view.contentY = y;
    }

    function jumpTo(letter) {
        jumpMode = false;
        const i = entries.findIndex(e => e.kind === "header" && e.name === letter);
        if (i >= 0) view.positionViewAtIndex(i, ListView.Beginning);
    }

    // KeyNav: up/down through apps and folders, skipping titles and letters.
    function kbStep(cur, dx, dy) {
        if (dy === 0 || jumpMode) return null;
        let i = cur && cur === view.currentItem ? view.currentIndex : -1;
        do { i += dy; } while (i >= 0 && i < entries.length && entries[i].kind !== "app" && entries[i].kind !== "folder");
        if (i < 0 || i >= entries.length) return null;
        view.currentIndex = i;
        return view.currentItem;
    }

    function pinItems(e) {
        const id = roleData(e.model, e.row, "favoriteId");
        if (!id) return [];
        return [root.isPinned(id)
            ? { text: i18n("Unpin from Start"), icon: "window-unpin", run: () => root.unpin(id) }
            : { text: i18n("Pin to Start"), icon: "window-pin", run: () => root.pin(id) },
            { text: i18n("Hide from apps"), icon: "hint", run: () => root.hideApp(id) }];
    }

    Connections {
        target: root.rootModel
        function onRefreshed() { list.rebuild(); }
    }
    Connections {
        target: list.cfg
        function onCategoryFoldersChanged() { list.rebuild(); }
        function onFoldersAtBottomChanged() { list.rebuild(); }
        function onShowRecentlyAddedChanged() { list.rebuild(); }
        function onShowMostUsedChanged() { list.rebuild(); }
        function onHiddenAppsChanged() { list.rebuild(); }
    }
    Component.onCompleted: rebuild()

    ListView {
        id: view
        anchors.fill: parent
        anchors.topMargin: Math.round(8 * list.metrics.s)
        visible: !list.jumpMode
        clip: true
        model: list.entries
        boundsBehavior: Flickable.StopAtBounds
        reuseItems: true
        QQC2.ScrollBar.vertical: PC3.ScrollBar {
            opacity: view.moving || hovered ? 1 : 0.0
            Behavior on opacity { NumberAnimation { duration: 150 } }
        }

        delegate: PC3.AbstractButton {
            id: row
            required property var modelData
            required property int index
            readonly property var e: modelData
            readonly property bool isApp: e.kind === "app"
            readonly property bool kbNav: true
            function kbShow() { view.positionViewAtIndex(index, ListView.Contain); }
            function kbMenu() {
                if (isApp) list.contextMenu.show(row, e.model, e.row, list.pinItems(e), width / 2, height / 2);
            }

            width: view.width - Math.round(12 * list.metrics.s)
            height: list.metrics.row
            hoverEnabled: e.kind !== "title"
            leftPadding: Math.round((12 + 24 * (e.depth || 0)) * list.metrics.s)

            background: Rectangle {
                color: list.metrics.text
                opacity: row.pressed || mouse.pressed ? 0.15 : (row.hovered ? 0.08 : 0)
            }

            KeyFrame {}

            contentItem: Item {
                Kirigami.Icon {
                    id: rowIcon
                    visible: row.e.kind === "app" || row.e.kind === "folder"
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: visible ? list.metrics.listIcon : 0
                    height: width
                    source: row.e.kind === "app" ? list.roleData(row.e.model, row.e.row, "decoration")
                          : row.e.kind === "folder" ? "folder" : ""
                }
                PC3.Label {
                    id: rowLabel
                    anchors.left: rowIcon.right
                    anchors.leftMargin: rowIcon.visible ? Math.round(12 * list.metrics.s) : 0
                    anchors.right: parent.right
                    anchors.rightMargin: chevron.visible ? chevron.width + chevron.anchors.rightMargin : 0
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.e.name
                    elide: Text.ElideRight
                    color: list.metrics.text
                    font.family: list.metrics.font
                    font.pixelSize: list.metrics.fontSize
                    font.weight: row.e.kind === "title" ? Font.DemiBold : Font.Normal
                }
                // "New" mark for newly installed apps (Start11 "Highlight").
                Rectangle {
                    visible: row.isApp && list.cfg.highlightNew && !!list.roleData(row.e.model, row.e.row, "isNewlyInstalled")
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: newLabel.implicitWidth + list.metrics.px(10)
                    height: newLabel.implicitHeight + list.metrics.px(2)
                    radius: height / 2
                    color: list.metrics.accent
                    PC3.Label {
                        id: newLabel
                        anchors.centerIn: parent
                        text: i18nc("newly installed app", "New")
                        color: "white"
                        font.pixelSize: Math.round(list.metrics.fontSize * 0.8)
                    }
                }
            }

            Kirigami.Icon {
                id: chevron
                visible: row.e.kind === "folder"
                anchors.right: parent.right
                anchors.rightMargin: Math.round(10 * list.metrics.s)
                anchors.verticalCenter: parent.verticalCenter
                width: Math.round(14 * list.metrics.s)
                height: width
                source: list.openFolders[row.e.name] ? "arrow-up" : "arrow-down"
                color: list.metrics.text
                isMask: true
            }

            onClicked: {
                if (e.kind === "header") {
                    list.jumpMode = true;
                } else if (e.kind === "folder") {
                    list.toggleFolder(e.name);
                } else if (e.kind === "app") {
                    e.model.trigger(e.row, "", null);
                    root.close();
                }
            }

            // Right click: Pin to Start + KDE actions. Drag: pin onto the tiles.
            MouseArea {
                id: mouse
                anchors.fill: parent
                enabled: row.isApp
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                propagateComposedEvents: true
                preventStealing: true   // the list must not scroll away a drag to the tiles
                property point pressPos
                property bool dragging: false
                onPressed: mouse => {
                    pressPos = Qt.point(mouse.x, mouse.y);
                    if (mouse.button === Qt.LeftButton) mouse.accepted = true;
                }
                onPositionChanged: mouse => {
                    if (!dragging && (pressed && Math.hypot(mouse.x - pressPos.x, mouse.y - pressPos.y) > Qt.styleHints.startDragDistance)) {
                        const id = list.roleData(row.e.model, row.e.row, "favoriteId");
                        if (!id || Plasmoid.configuration.tilesLocked) return;
                        dragging = true;
                        const g = list.ghost;
                        g.favoriteId = id;
                        g.icon = list.roleData(row.e.model, row.e.row, "decoration");
                        const p = mapToItem(g.parent, mouse.x, mouse.y);
                        g.x = p.x - g.width / 2;
                        g.y = p.y - g.height / 2;
                        g.Drag.active = true;
                    }
                    if (dragging) {
                        const p = mapToItem(list.ghost.parent, mouse.x, mouse.y);
                        list.ghost.x = p.x - list.ghost.width / 2;
                        list.ghost.y = p.y - list.ghost.height / 2;
                    }
                }
                onReleased: mouse => {
                    if (dragging) {
                        list.ghost.Drag.drop();
                        list.ghost.Drag.active = false;
                        dragging = false;
                    } else if (mouse.button === Qt.LeftButton && containsMouse) {
                        row.clicked();
                    }
                }
                onCanceled: {
                    list.ghost.Drag.active = false;
                    dragging = false;
                }
                onClicked: mouse => {
                    if (mouse.button === Qt.RightButton) {
                        list.contextMenu.show(row, row.e.model, row.e.row, list.pinItems(row.e), mouse.x, mouse.y);
                    }
                }
            }
        }
    }

    // Letter jump grid (# A..Z), like Windows 10.
    Grid {
        anchors.centerIn: parent
        visible: list.jumpMode
        columns: 4
        spacing: Math.round(4 * list.metrics.s)
        Repeater {
            model: ["#"].concat("ABCDEFGHIJKLMNOPQRSTUVWXYZ".split(""))
            delegate: PC3.AbstractButton {
                id: letterBtn
                required property string modelData
                readonly property bool present: list.entries.some(e => e.kind === "header" && e.name === modelData)
                width: Math.round(48 * list.metrics.s)
                height: width
                enabled: present
                hoverEnabled: true
                onClicked: list.jumpTo(modelData)
                background: Rectangle {
                    color: list.metrics.text
                    opacity: letterBtn.hovered ? 0.12 : 0
                }
                contentItem: PC3.Label {
                    text: letterBtn.modelData
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    color: list.metrics.text
                    opacity: letterBtn.present ? 1 : 0.35
                    font.family: list.metrics.font
                    font.pixelSize: list.metrics.fontSize * 1.6
                }
            }
        }
    }
}
