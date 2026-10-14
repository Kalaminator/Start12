pragma ComponentBehavior: Bound

import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PC3
import org.kde.plasma.private.kicker as Kicker
import org.kde.kirigami as Kirigami
import org.kde.kitemmodels as KItemModels
import "../code/tiles.js" as Tiles

// Windows 11 "Pinned": pages of icons with names. Drag to reorder; wheel or dots change page.
// Drop an icon on the right 3/4 of another to make a folder ("folder|name|ids"), click opens it.
Item {
    id: grid

    required property QtObject metrics
    required property var contextMenu
    required property Item ghost

    readonly property var cfg: Plasmoid.configuration
    property int extraCols: 0     // Wide and Large sizes add columns
    property int fixedCols: 0     // > 0: the style decides (Pro 3, Launcher 6)
    property int fixedRows: 0     // > 0: the style decides (fits its height)
    readonly property int cols: fixedCols > 0 ? fixedCols : Math.max(3, cfg.pinnedColumns) + extraCols
    readonly property int rows: fixedRows > 0 ? fixedRows : Math.max(1, cfg.pinnedRows)
    readonly property real cellW: metrics.px(96)
    readonly property real cellH: metrics.px(84)
    readonly property int perPage: cols * rows
    readonly property int pages: Math.max(1, Math.ceil(root.shownPins.length / perPage))
    property int page: 0
    onPagesChanged: page = Math.min(page, pages - 1)

    // Open folder: its index in root.shownPins (-1: closed). Closes when it is no folder any more.
    property int openFolder: -1
    readonly property var folder: openFolder >= 0 ? Tiles.folderOf(root.shownPins[openFolder]) : null
    onFolderChanged: if (!folder) folderPopup.close()
    function showFolder(index, rename) {
        openFolder = index;
        folderPopup.open();
        if (rename) nameField.forceActiveFocus();
    }

    implicitWidth: cols * cellW
    implicitHeight: rows * cellH

    WheelHandler {
        onWheel: event => {
            if (event.angleDelta.y < 0) grid.page = Math.min(grid.pages - 1, grid.page + 1);
            else if (event.angleDelta.y > 0) grid.page = Math.max(0, grid.page - 1);
        }
    }

    // Right-click on empty space: pin a website, file or folder.
    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: point => grid.contextMenu.show(grid, null, -1, root.pinNewItems, point.position.x, point.position.y)
    }

    // Empty grid space: drop to add at the end.
    DropArea {
        anchors.fill: parent
        keys: ["start12-tile"]
        onDropped: drop => root.movePinned(drop.source.favoriteId, grid.cfg.pinnedGrid.length)
    }

    Item {
        id: viewport
        width: grid.cols * grid.cellW
        height: grid.rows * grid.cellH
        clip: true

        Grid {
            id: cells
            columns: grid.cols
            y: -grid.page * viewport.height
            Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

            Repeater {
                model: root.shownPins
                delegate: pinCell
            }
        }
    }

    // One pinned app, website/file/folder shortcut, or pin folder. inFolder: a cell in the popup.
    Component {
        id: pinCell
    PC3.AbstractButton {
        id: cell
        required property string modelData
        required property int index
        readonly property bool inFolder: parent !== cells
        width: grid.cellW
        height: grid.cellH
        hoverEnabled: true

        readonly property var pinFolder: Tiles.folderOf(modelData)
        Kicker.SimpleFavoritesModel {
            id: fav
            favorites: cell.pinFolder ? [] : [cell.modelData]
        }
        // Folder: first 4 app icons (website/file pins have no row here).
        Kicker.SimpleFavoritesModel {
            id: mini
            favorites: cell.pinFolder ? cell.pinFolder.ids.filter(id => !root.missingPins.includes(id)).slice(0, 4) : []
        }
        function role(name) {
            return fav.count > 0 ? fav.data(fav.index(0, 0), fav.KItemModels.KRoleNames.role(name)) : undefined;
        }
        // Pinned website/file/folder instead of an app.
        readonly property var custom: Tiles.custom(modelData)
        readonly property var appIcon: pinFolder ? "folder" : custom ? (custom.icon || "folder") : fav.count > 0 ? role("decoration") : "dialog-question"

        function launch() {
            if (pinFolder) {
                grid.showFolder(index, false);
            } else if (custom) {
                root.openCustom(custom);
            } else {
                if (fav.count > 0) fav.trigger(0, "", null);
                root.close();
            }
        }
        function menu(x, y) {
            const id = modelData;
            if (pinFolder) {
                grid.contextMenu.show(cell, null, -1, [
                    { text: i18n("Rename folder"), icon: "edit-rename", run: () => grid.showFolder(index, true) },
                    { text: i18n("Unpin folder"), icon: "window-unpin", run: () => root.unfoldFolder(id) },
                    { text: i18n("Move to front"), icon: "go-first", enabled: index > 0, run: () => root.movePinned(id, 0) }
                ], x, y);
                return;
            }
            grid.contextMenu.show(cell, fav.count > 0 ? fav : null, 0, [
                { text: i18n("Unpin from Start"), icon: "window-unpin", run: () => root.unpin(id) },
                { text: i18n("Move out of folder"), icon: "go-first", visible: inFolder, enabled: inFolder,
                  run: () => root.movePinned(id, grid.openFolder + 1) },
                { text: i18n("Rename"), icon: "edit-rename", run: () => root.renamePin(id, custom ? custom.name : role("display")) },
                { text: i18n("Hide from apps"), icon: "hint", visible: !custom, run: () => root.hideApp(id) },
                { text: i18n("Move to front"), icon: "go-first", enabled: index > 0 || inFolder, run: () => root.movePinned(id, 0) }
            ].concat(root.taskbarItem(id)).filter(m => m.visible !== false), x, y);
        }
        readonly property bool kbNav: !inFolder
        function kbActivate() { launch(); }
        function kbMenu() { menu(width / 2, height / 2); }
        function kbShow() { grid.page = Math.floor(index / grid.perPage); }
        KeyFrame {}

        // Left quarter: insert before; rest: into a folder (folders themselves only move).
        readonly property bool dropBefore: drop.drag.x < width / 4 || Tiles.isFolder(drop.drag.source ? drop.drag.source.favoriteId : "")
        background: Rectangle {
            radius: grid.metrics.px(4)
            color: drop.containsDrag && !cell.dropBefore ? grid.metrics.accent : grid.metrics.text
            opacity: drop.containsDrag && !cell.dropBefore ? 0.3 : mouse.pressed && !mouse.dragging ? 0.12 : (cell.hovered ? 0.07 : 0)
            Rectangle {
                visible: drop.containsDrag && cell.dropBefore
                width: Math.max(2, grid.metrics.px(3))
                height: parent.height
                color: grid.metrics.accent
            }
        }
        opacity: mouse.dragging ? 0.3 : 1

        contentItem: Column {
            spacing: grid.metrics.px(6)
            topPadding: grid.metrics.px(10)
            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                width: grid.metrics.px(32)
                height: width
                Kirigami.Icon {
                    anchors.fill: parent
                    visible: !cell.pinFolder
                    source: cell.appIcon
                }
                // Folder: 2x2 mini icons on a soft square, like Windows 11.
                Rectangle {
                    anchors.fill: parent
                    visible: !!cell.pinFolder
                    radius: grid.metrics.px(4)
                    color: Qt.alpha(grid.metrics.text, 0.1)
                    Grid {
                        anchors.centerIn: parent
                        columns: 2
                        spacing: grid.metrics.px(2)
                        Repeater {
                            model: mini
                            delegate: Kirigami.Icon {
                                required property var decoration
                                width: grid.metrics.px(13)
                                height: width
                                source: decoration
                            }
                        }
                    }
                }
            }
            PC3.Label {
                width: cell.width - grid.metrics.px(8)
                anchors.horizontalCenter: parent.horizontalCenter
                horizontalAlignment: Text.AlignHCenter
                text: cell.pinFolder ? cell.pinFolder.name : root.capOf(cell.modelData) ? root.capOf(cell.modelData) : cell.custom ? cell.custom.name : fav.count > 0 ? cell.role("display") : cell.modelData
                elide: Text.ElideRight
                maximumLineCount: 1
                color: grid.metrics.text
                font.family: grid.metrics.font
                font.pixelSize: Math.round(grid.metrics.fontSize * 0.9)
            }
        }

        DropArea {
            id: drop
            anchors.fill: parent
            enabled: !cell.inFolder
            keys: ["start12-tile"]
            onDropped: d => {
                if (cell.dropBefore) root.movePinned(d.source.favoriteId, cell.index);
                else root.folderPins(d.source.favoriteId, cell.modelData);
            }
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            preventStealing: true
            property point pressPos
            property bool dragging: false
            onPressed: m => pressPos = Qt.point(m.x, m.y)
            onPositionChanged: m => {
                if (!dragging && pressed && Math.hypot(m.x - pressPos.x, m.y - pressPos.y) > Qt.styleHints.startDragDistance) {
                    dragging = true;
                    grid.ghost.favoriteId = cell.modelData;
                    grid.ghost.icon = cell.appIcon;
                    grid.ghost.Drag.active = true;
                }
                if (dragging) {
                    const p = mapToItem(grid.ghost.parent, m.x, m.y);
                    grid.ghost.x = p.x - grid.ghost.width / 2;
                    grid.ghost.y = p.y - grid.ghost.height / 2;
                }
            }
            onReleased: m => {
                if (dragging) {
                    grid.ghost.Drag.drop();
                    grid.ghost.Drag.active = false;
                    dragging = false;
                } else if (m.button === Qt.LeftButton && containsMouse) {
                    cell.launch();
                } else if (m.button === Qt.RightButton) {
                    cell.menu(m.x, m.y);
                }
            }
            onCanceled: {
                grid.ghost.Drag.active = false;
                dragging = false;
            }
        }
    }
    }

    // Open pin folder: name field + its apps. Drag an app out onto the grid to take it out.
    PC3.Popup {
        id: folderPopup
        x: (grid.width - width) / 2
        y: grid.metrics.px(12)
        padding: grid.metrics.px(10)
        onClosed: grid.openFolder = -1
        contentItem: Column {
            spacing: grid.metrics.px(8)
            PC3.TextField {
                id: nameField
                width: parent.width
                text: grid.folder ? grid.folder.name : ""
                horizontalAlignment: Text.AlignHCenter
                onEditingFinished: if (grid.folder && text !== grid.folder.name) root.renameFolder(root.shownPins[grid.openFolder], text)
            }
            Grid {
                columns: Math.min(4, Math.max(1, folderApps.count))
                Repeater {
                    id: folderApps
                    model: grid.folder ? grid.folder.ids.filter(id => !root.missingPins.includes(id)) : []
                    delegate: pinCell
                }
            }
        }
    }

    // Page dots on the right, like Windows 11.
    Column {
        visible: grid.pages > 1
        anchors.left: viewport.right
        anchors.leftMargin: grid.metrics.px(6)
        anchors.verticalCenter: viewport.verticalCenter
        spacing: grid.metrics.px(6)
        Repeater {
            model: grid.pages
            delegate: Rectangle {
                required property int index
                width: grid.metrics.px(6)
                height: width
                radius: width / 2
                color: grid.metrics.text
                opacity: index === grid.page ? 0.9 : 0.3
                TapHandler { onTapped: grid.page = parent.index }
            }
        }
    }
}
