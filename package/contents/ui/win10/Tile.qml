pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PC3
import org.kde.plasma.private.kicker as Kicker
import org.kde.kirigami as Kirigami
import org.kde.kitemmodels as KItemModels
import "../code/tiles.js" as Tiles
import "../common"

// One tile. Its own one-row kicker model gives the name, icon, actions and launch.
PC3.AbstractButton {
    id: tile

    required property var tile
    required property int tileIndex
    required property int groupIndex
    required property QtObject metrics
    required property var contextMenu
    required property Item ghost

    // Set on tiles shown inside an opened folder (TileGroup's folder row).
    property string folderId: ""

    signal nameKnown(string name)
    // A folder tile was clicked (or "Name folder" chosen): the group opens its row.
    signal folderClicked(bool rename)

    readonly property bool isFolder: tile.tile.kind === "folder"

    readonly property bool valid: fav.count > 0
    // Pinned website/file/folder instead of an app.
    readonly property var custom: Tiles.custom(tile.tile.id)
    readonly property var appIcon: isFolder ? "folder" : custom ? (custom.icon || "folder") : valid ? role("decoration") : "dialog-question"
    readonly property bool small: tile.tile.size === "small"
    readonly property bool showCaption: tile.tile.caption === "show" ? true
        : tile.tile.caption === "hide" ? false : !Plasmoid.configuration.hideTileText

    Kicker.SimpleFavoritesModel {
        id: fav
        favorites: [tile.tile.id]
    }
    function role(name) {
        return fav.count > 0 ? fav.data(fav.index(0, 0), fav.KItemModels.KRoleNames.role(name)) : undefined;
    }
    readonly property string appName: isFolder ? (tile.tile.name || i18n("Folder")) : custom ? custom.name : valid ? role("display") : tile.tile.id
    onAppNameChanged: nameKnown(appName)
    Component.onCompleted: nameKnown(appName)

    hoverEnabled: true
    PC3.ToolTip.text: appName
    PC3.ToolTip.visible: hovered && !showCaption && !mouse.dragging
    PC3.ToolTip.delay: Kirigami.Units.toolTipDelay

    background: Rectangle {
        radius: Math.round(2 * tile.metrics.s)
        color: tile.tile.color ? Qt.alpha(tile.tile.color, tile.hovered ? 0.95 : 0.85)
             : Qt.alpha(tile.metrics.tile, tile.metrics.tileAlpha + (tile.hovered ? 0.06 : 0))
        border.width: drop.containsDrag && drop.intoFolder ? Math.max(2, Math.round(2 * tile.metrics.s))
                    : tile.hovered ? Math.max(1, Math.round(tile.metrics.s)) : 0
        border.color: drop.containsDrag && drop.intoFolder ? tile.metrics.accent : Qt.alpha(tile.metrics.text, 0.35)
        Image {
            visible: Plasmoid.configuration.tileImage !== ""
            anchors.fill: parent
            source: visible ? "file://" + Plasmoid.configuration.tileImage : ""
            fillMode: Image.PreserveAspectCrop
            opacity: Plasmoid.configuration.tileImageOpacity / 100
            asynchronous: true
        }
        // Drop marker: a bar on the left edge.
        Rectangle {
            visible: drop.containsDrag && !drop.intoFolder
            width: Math.max(2, Math.round(3 * tile.metrics.s))
            height: parent.height
            color: tile.metrics.accent
        }
    }
    scale: mouse.pressed && !mouse.dragging ? 0.96 : 1
    Behavior on scale { NumberAnimation { duration: 80 } }
    opacity: mouse.dragging ? 0.3 : 1

    contentItem: Item {
        // Folder: a grid of mini icons of its tiles.
        Grid {
            id: mini
            visible: tile.isFolder
            readonly property int cols: tile.small ? 2 : tile.tile.size === "wide" ? 6 : 3
            readonly property int rowsMax: tile.small ? 2 : 3
            readonly property real side: Math.floor(Math.min(parent.width / cols, (parent.height - (label.visible ? label.height : 0)) / rowsMax) * 0.7)
            anchors.centerIn: parent
            anchors.verticalCenterOffset: label.visible ? -Math.round(label.height / 2) : 0
            columns: cols
            spacing: Math.round(side * 0.3)
            Repeater {
                model: tile.isFolder ? tile.tile.tiles.slice(0, mini.cols * mini.rowsMax) : []
                delegate: Kirigami.Icon {
                    id: miniIcon
                    required property var modelData
                    readonly property var custom: Tiles.custom(modelData.id)
                    width: mini.side
                    height: mini.side
                    Kicker.SimpleFavoritesModel {
                        id: miniFav
                        favorites: miniIcon.custom ? [] : [miniIcon.modelData.id]
                    }
                    source: modelData.icon ? (modelData.icon.startsWith("/") ? "file://" + modelData.icon : modelData.icon)
                          : custom ? (custom.icon || "folder")
                          : miniFav.count > 0 ? miniFav.data(miniFav.index(0, 0), miniFav.KItemModels.KRoleNames.role("decoration"))
                          : "dialog-question"
                }
            }
        }
        Kirigami.Icon {
            visible: !tile.isFolder
            readonly property real side: Math.round(Math.min(tile.width, tile.height)
                * Plasmoid.configuration.tileIconScale / 100 * (tile.tile.size === "large" ? 0.8 : 1))
            anchors.centerIn: parent
            anchors.verticalCenterOffset: label.visible ? -Math.round(label.height / 3) : 0
            width: side
            height: side
            layer.enabled: Plasmoid.configuration.greyIcons
            layer.effect: MultiEffect { saturation: -1 }
            source: tile.tile.icon ? (tile.tile.icon.startsWith("/") ? "file://" + tile.tile.icon : tile.tile.icon)
                  : tile.appIcon
        }
        PC3.Label {
            id: label
            visible: tile.showCaption && !tile.small && (!tile.isFolder || tile.tile.name !== "")
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: Math.round(5 * tile.metrics.s)
            text: tile.appName
            elide: Text.ElideRight
            color: tile.metrics.text
            font.family: tile.metrics.font
            font.pixelSize: Math.round(tile.metrics.itemFontSize * 0.85)
        }
    }

    function launch() {
        if (isFolder) {
            folderClicked(false);
        } else if (custom) {
            root.openCustom(custom);
        } else if (valid) {
            fav.trigger(0, "", null);
            root.close();
        }
    }

    function menuItems() {
        const id = tile.tile.id;
        const set = (key, value) => root.saveGroups(Tiles.setProp(root.groups, id, key, value));
        const items = isFolder ? [
            { text: i18n("Name folder"), icon: "edit-rename", run: () => tile.folderClicked(true) },
            { text: i18n("Unpin folder from Start"), icon: "window-unpin", run: () => root.unpin(id) }
        ] : [{ text: i18n("Unpin from Start"), icon: "window-unpin", run: () => root.unpin(id) }];
        if (!isFolder) items.push(
            { text: i18n("Set icon…"), icon: "preferences-desktop-icons", run: () => root.pickTileIcon(id) },
            { text: i18n("Reset custom icon"), icon: "edit-undo", enabled: !!tile.tile.icon, run: () => set("icon", "") });
        items.push(
            { text: tile.showCaption ? i18n("Hide icon text") : i18n("Show icon text"), icon: "format-text-bold",
              run: () => set("caption", tile.showCaption ? "hide" : "show") },
            { text: i18n("Tile colour…"), icon: "color-management", run: () => root.pickTileColor(id, tile.tile.color) },
            { text: i18n("Reset tile colour"), icon: "edit-undo", enabled: !!tile.tile.color, run: () => set("color", "") });
        if (!Plasmoid.configuration.tilesLocked && !folderId) {
            items.push({ text: i18n("Resize"), icon: "transform-scale", subActions: [
                ["small", i18n("Small")], ["medium", i18n("Medium")], ["wide", i18n("Wide")], ["large", i18n("Large")]
            ].map(s => ({
                text: s[1], checkable: true, checked: tile.tile.size === s[0],
                run: () => root.saveGroups(Tiles.resize(root.groups, id, s[0]))
            })) });
        }
        return items;
    }

    // Drop another tile/app here: on the left quarter it goes before this tile, elsewhere both
    // become a folder (or it joins this folder). Inside an opened folder it goes after this tile.
    DropArea {
        id: drop
        anchors.fill: parent
        keys: ["start12-tile"]
        readonly property bool intoFolder: !!drag.source && !Tiles.isFolder(drag.source.favoriteId)
            && (tile.folderId !== "" || drag.x > tile.width / 4)
        onDropped: d => {
            const id = d.source.favoriteId;
            if (id === tile.tile.id) return;
            if (!Tiles.isFolder(id) && (tile.folderId !== "" || d.x > tile.width / 4)) {
                root.saveGroups(Tiles.dropOnTile(root.groups, id, tile.tile.id));
            } else if (tile.folderId === "") {
                root.saveGroups(Tiles.place(root.groups, id, tile.groupIndex, tile.tileIndex));
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        // Without this the tile area (a Flickable) steals vertical drags and cancels them.
        preventStealing: true
        property point pressPos
        property bool dragging: false

        onPressed: m => pressPos = Qt.point(m.x, m.y)
        onPositionChanged: m => {
            if (!dragging && pressed && !Plasmoid.configuration.tilesLocked
                && Math.hypot(m.x - pressPos.x, m.y - pressPos.y) > Qt.styleHints.startDragDistance) {
                dragging = true;
                tile.ghost.favoriteId = tile.tile.id;
                tile.ghost.icon = tile.appIcon;
                tile.ghost.Drag.active = true;
            }
            if (dragging) {
                const p = mapToItem(tile.ghost.parent, m.x, m.y);
                tile.ghost.x = p.x - tile.ghost.width / 2;
                tile.ghost.y = p.y - tile.ghost.height / 2;
            }
        }
        onReleased: m => {
            if (dragging) {
                tile.ghost.Drag.drop();
                tile.ghost.Drag.active = false;
                dragging = false;
            } else if (m.button === Qt.LeftButton && containsMouse) {
                tile.launch();
            } else if (m.button === Qt.RightButton) {
                tile.contextMenu.show(tile, tile.valid ? fav : null, 0, tile.menuItems(), m.x, m.y);
            }
        }
        onCanceled: {
            tile.ghost.Drag.active = false;
            dragging = false;
        }
    }

    Keys.onReturnPressed: launch()

    readonly property bool kbNav: true
    function kbActivate() { launch(); }
    function kbMenu() { contextMenu.show(tile, valid ? fav : null, 0, menuItems(), width / 2, height / 2); }
    KeyFrame {}
}
