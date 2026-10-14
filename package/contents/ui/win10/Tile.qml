pragma ComponentBehavior: Bound

import QtQuick
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

    signal nameKnown(string name)

    readonly property bool valid: fav.count > 0
    // Pinned website/file/folder instead of an app.
    readonly property var custom: Tiles.custom(tile.tile.id)
    readonly property var appIcon: custom ? (custom.icon || "folder") : valid ? role("decoration") : "dialog-question"
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
    readonly property string appName: custom ? custom.name : valid ? role("display") : tile.tile.id
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
        border.width: tile.hovered ? Math.max(1, Math.round(tile.metrics.s)) : 0
        border.color: Qt.alpha(tile.metrics.text, 0.35)
        // Drop marker: a bar on the left edge.
        Rectangle {
            visible: drop.containsDrag
            width: Math.max(2, Math.round(3 * tile.metrics.s))
            height: parent.height
            color: tile.metrics.accent
        }
    }
    scale: mouse.pressed && !mouse.dragging ? 0.96 : 1
    Behavior on scale { NumberAnimation { duration: 80 } }
    opacity: mouse.dragging ? 0.3 : 1

    contentItem: Item {
        Kirigami.Icon {
            readonly property real side: Math.round(Math.min(tile.width, tile.height)
                * Plasmoid.configuration.tileIconScale / 100 * (tile.tile.size === "large" ? 0.8 : 1))
            anchors.centerIn: parent
            anchors.verticalCenterOffset: label.visible ? -Math.round(label.height / 3) : 0
            width: side
            height: side
            source: tile.tile.icon ? (tile.tile.icon.startsWith("/") ? "file://" + tile.tile.icon : tile.tile.icon)
                  : tile.appIcon
        }
        PC3.Label {
            id: label
            visible: tile.showCaption && !tile.small
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: Math.round(5 * tile.metrics.s)
            text: tile.appName
            elide: Text.ElideRight
            color: tile.metrics.text
            font.family: tile.metrics.font
            font.pixelSize: Math.round(tile.metrics.fontSize * 0.85)
        }
    }

    function launch() {
        if (custom) {
            root.openCustom(custom);
        } else if (valid) {
            fav.trigger(0, "", null);
            root.close();
        }
    }

    function menuItems() {
        const id = tile.tile.id;
        const items = [{ text: i18n("Unpin from Start"), icon: "window-unpin", run: () => root.unpin(id) }];
        const set = (key, value) => root.saveGroups(Tiles.setProp(root.groups, id, key, value));
        items.push(
            { text: i18n("Set icon…"), icon: "preferences-desktop-icons", run: () => root.pickTileIcon(id) },
            { text: i18n("Reset custom icon"), icon: "edit-undo", enabled: !!tile.tile.icon, run: () => set("icon", "") },
            { text: tile.showCaption ? i18n("Hide icon text") : i18n("Show icon text"), icon: "format-text-bold",
              run: () => set("caption", tile.showCaption ? "hide" : "show") },
            { text: i18n("Tile colour…"), icon: "color-management", run: () => root.pickTileColor(id, tile.tile.color) },
            { text: i18n("Reset tile colour"), icon: "edit-undo", enabled: !!tile.tile.color, run: () => set("color", "") });
        if (!Plasmoid.configuration.tilesLocked) {
            items.push({ text: i18n("Resize"), icon: "transform-scale", subActions: [
                ["small", i18n("Small")], ["medium", i18n("Medium")], ["wide", i18n("Wide")], ["large", i18n("Large")]
            ].map(s => ({
                text: s[1], checkable: true, checked: tile.tile.size === s[0],
                run: () => root.saveGroups(Tiles.resize(root.groups, id, s[0]))
            })) });
        }
        return items;
    }

    // Drop another tile/app here: insert before this tile.
    DropArea {
        id: drop
        anchors.fill: parent
        keys: ["start12-tile"]
        onDropped: d => {
            if (d.source.favoriteId !== tile.tile.id) {
                root.saveGroups(Tiles.place(root.groups, d.source.favoriteId, tile.groupIndex, tile.tileIndex));
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
