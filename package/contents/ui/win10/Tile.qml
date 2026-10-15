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
    readonly property bool isWidget: Tiles.isWidget(tile.tile.id)
    readonly property string widgetFile: ({ clock: "Clock", calendar: "Calendar", sysmon: "SysMon", drives: "Drives", weather: "Weather", notes: "Notes", photo: "Photo" })[Tiles.widgetKind(tile.tile.id)] || ""

    readonly property bool valid: !isWidget && fav.count > 0
    // Pinned website/file/folder instead of an app.
    readonly property var custom: Tiles.custom(tile.tile.id)
    readonly property var appIcon: isWidget ? "preferences-system-time" : isFolder ? "folder" : custom ? (custom.icon || "folder") : valid ? role("decoration") : "dialog-question"
    readonly property bool big: ["large", "wideLargeH", "wideLargeV", "hugeH", "hugeV"].includes(tile.tile.size)
    readonly property bool small: tile.tile.size === "small"
    readonly property bool showCaption: tile.tile.caption === "show" ? true
        : tile.tile.caption === "hide" ? false : !Plasmoid.configuration.hideTileText

    Kicker.SimpleFavoritesModel {
        id: fav
        favorites: tile.isWidget ? [] : [tile.tile.id]
    }
    function role(name) {
        return fav.count > 0 ? fav.data(fav.index(0, 0), fav.KItemModels.KRoleNames.role(name)) : undefined;
    }
    readonly property string appName: isWidget ? widgetName() : isFolder ? (tile.tile.name || i18n("Folder")) : custom ? custom.name : valid ? role("display") : tile.tile.id
    function widgetName() {
        const k = Tiles.widgetKind(tile.tile.id);
        return k === "clock" ? i18n("Clock") : k === "calendar" ? i18n("Calendar") : k === "sysmon" ? i18n("System monitor")
            : k === "drives" ? i18n("Drives") : k === "weather" ? i18n("Weather") : k === "notes" ? i18n("Notes") : k === "photo" ? i18n("Photo") : k;
    }
    onAppNameChanged: nameKnown(appName)
    Component.onCompleted: nameKnown(appName)

    hoverEnabled: true
    PC3.ToolTip.text: appName
    PC3.ToolTip.visible: hovered && !showCaption && !isWidget && !mouse.dragging
    PC3.ToolTip.delay: Kirigami.Units.toolTipDelay

    background: Rectangle {
        radius: Math.round(2 * tile.metrics.s)
        color: tile.tile.color ? Qt.alpha(tile.tile.color, tile.hovered ? 0.95 : 0.85)
             : Qt.alpha(tile.metrics.tile, tile.metrics.tileAlpha + (tile.hovered ? 0.06 : 0))
        border.width: drop.containsDrag && drop.intoFolder ? Math.max(2, Math.round(2 * tile.metrics.s))
                    : tile.hovered ? Math.max(1, Math.round(tile.metrics.s)) : 0
        border.color: drop.containsDrag && drop.intoFolder ? tile.metrics.accent : Qt.alpha(tile.metrics.text, 0.35)
        Image {
            readonly property string path: tile.tile.image || Plasmoid.configuration.tileImage
            visible: path !== ""
            anchors.fill: parent
            source: visible ? "file://" + path : ""
            fillMode: Image.PreserveAspectCrop
            opacity: tile.tile.image ? 1 : Plasmoid.configuration.tileImageOpacity / 100
            asynchronous: true
            layer.enabled: visible
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: ShaderEffectSource { sourceItem: Rectangle { width: tile.width; height: tile.height; radius: Math.round(2 * tile.metrics.s) } }
            }
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
            readonly property int cols: tile.small ? 2 : tile.tile.size === "wide" ? 6 : tile.tile.size === "wideLargeH" || tile.tile.size === "hugeH" ? 9 : 3
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
            visible: !tile.isFolder && !tile.isWidget && !(tile.big && tile.tile.image && tile.tile.imageIcon === "hide")
            // Big tiles: exactly twice a medium tile's icon (medium = 2 units).
            readonly property real side: Math.round(2 * tile.metrics.unit * (tile.big ? 2 : 1)
                * Plasmoid.configuration.tileIconScale / 100)
            anchors.centerIn: parent
            anchors.verticalCenterOffset: label.visible ? -Math.round(label.height / 3) : 0
            width: side
            height: side
            layer.enabled: Plasmoid.configuration.greyIcons
            layer.effect: MultiEffect { saturation: -1 }
            source: tile.tile.icon ? (tile.tile.icon.startsWith("/") ? "file://" + tile.tile.icon : tile.tile.icon)
                  : tile.appIcon
        }
        Loader {
            id: widgetLoader
            active: tile.isWidget && tile.widgetFile !== ""
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: label.visible ? label.top : parent.bottom
            Component.onCompleted: if (active) setSource("../widgets/" + tile.widgetFile + ".qml",
                { metrics: tile.metrics, size: tile.tile.size, active: root.expanded })
            onLoaded: {
                item.size = Qt.binding(() => tile.tile.size);
                item.active = Qt.binding(() => root.expanded);
                if (item.tdata !== undefined) {
                    item.tdata = Qt.binding(() => tile.tile);
                    item.save = (key, value) => root.saveGroups(Tiles.setProp(root.groups, tile.tile.id, key, value));
                }
            }
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
        } else if (isWidget) {
            return;   // ponytail: widgets do nothing on click (Drives reacts through widgetClick)
        } else if (custom) {
            root.openCustom(custom);
        } else if (valid) {
            fav.trigger(0, "", null);
            root.close();
        }
    }

    // Colour picker columns (rainbow order); shades under each base go light -> dark.
    readonly property var swatches: [
        ["#E81123", i18n("Red")], ["#F7630C", i18n("Orange")], ["#FFB900", i18n("Yellow")], ["#8CBD18", i18n("Lime")],
        ["#107C10", i18n("Green")], ["#008272", i18n("Teal")], ["#00B7C3", i18n("Cyan")], ["#0078D7", i18n("Blue")],
        ["#4B53BC", i18n("Indigo")], ["#8764B8", i18n("Purple")], ["#E3008C", i18n("Pink")], ["#7A574A", i18n("Brown")],
        ["#69797E", i18n("Grey")]]
    readonly property var shadeSteps: [1.9, 1.5, 1.2, -1.3, -1.7]   // >0 Qt.lighter, <0 Qt.darker
    function shade(base, k) {
        const f = shadeSteps[k];
        return String(f > 0 ? Qt.lighter(base, f) : Qt.darker(base, -f)).toLowerCase();
    }
    function setColor(c) { root.saveGroups(Tiles.setProp(root.groups, tile.tile.id, "color", c)); colorPopup.close(); }

    PC3.Popup {
        id: colorPopup
        readonly property real sq: Math.round(22 * tile.metrics.s)
        readonly property real gap: Math.max(2, Math.round(2.5 * tile.metrics.s))
        x: Math.round((tile.width - width) / 2)
        y: Math.round((tile.height - height) / 2)
        padding: tile.metrics.px(8)
        closePolicy: PC3.Popup.CloseOnEscape | PC3.Popup.CloseOnPressOutside
        // Neutral ground, not the menu's accent-tinted one, so no swatch blends into it.
        background: Rectangle {
            color: Kirigami.Theme.backgroundColor
            border.color: Qt.alpha(Kirigami.Theme.textColor, 0.25)
            radius: tile.metrics.px(4)
        }
        contentItem: Column {
            spacing: tile.metrics.px(8)
            Row {
                spacing: colorPopup.gap
                Repeater {
                    model: tile.swatches
                    delegate: Column {
                        id: col
                        required property var modelData
                        spacing: colorPopup.gap
                        Repeater {
                            model: 6
                            delegate: Item {
                              id: cell
                              required property int index
                              width: colorPopup.sq
                              height: colorPopup.sq + (index === 1 ? colorPopup.gap * 2 : 0)   // gap under the base row
                              Rectangle {
                                id: sw
                                readonly property int index: cell.index
                                anchors.bottom: parent.bottom
                                readonly property string hex: index === 0 ? col.modelData[0].toLowerCase() : tile.shade(col.modelData[0], index - 1)
                                width: colorPopup.sq
                                height: colorPopup.sq
                                color: hex
                                border.width: hex === (tile.tile.color || "").toLowerCase() ? Math.max(2, tile.metrics.px(2))
                                           : swArea.containsMouse ? 1 : 0
                                border.color: hex === (tile.tile.color || "").toLowerCase() ? tile.metrics.accent : tile.metrics.text
                                MouseArea {
                                    id: swArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: tile.setColor(sw.hex)
                                    PC3.ToolTip.text: sw.hex.toUpperCase()
                                    PC3.ToolTip.visible: containsMouse
                                }
                              }
                            }
                        }
                    }
                }
            }
            Row {
                spacing: tile.metrics.px(8)
                PC3.Button { text: i18n("Custom colour…"); onClicked: { colorPopup.close(); root.pickTileColor(tile.tile.id, tile.tile.color); } }
                PC3.Button { text: i18n("Reset"); enabled: !!tile.tile.color; onClicked: tile.setColor("") }
            }
        }
    }

    function menuItems() {
        const id = tile.tile.id;
        const set = (key, value) => root.saveGroups(Tiles.setProp(root.groups, id, key, value));
        const items = isFolder ? [
            { text: i18n("Name folder"), icon: "edit-rename", run: () => tile.folderClicked(true) },
            { text: i18n("Unpin folder from Start"), icon: "window-unpin", run: () => root.unpin(id) }
        ] : isWidget ? [{ text: i18n("Remove widget"), icon: "edit-delete", run: () => root.unpin(id) }]
          : [{ text: i18n("Unpin from Start"), icon: "window-unpin", run: () => root.unpin(id) }];
        const wk = Tiles.widgetKind(id);
        if (wk === "weather") items.push(
            { text: i18n("Set location…"), icon: "mark-location", run: () => root.askName(tile.tile.loc, name => set("loc", name)) });
        if (wk === "photo") items.push(
            { text: i18n("Choose picture…"), icon: "viewimage", run: () => root.pickPhoto(id, false) },
            { text: i18n("Choose folder…"), icon: "folder-pictures", run: () => root.pickPhoto(id, true) });
        if (!isFolder && !isWidget) items.push(
            { text: i18n("Set icon…"), icon: "preferences-desktop-icons", run: () => root.pickTileIcon(id) },
            { text: i18n("Reset custom icon"), icon: "edit-undo", enabled: !!tile.tile.icon, run: () => set("icon", "") });
        items.push(
            { text: tile.showCaption ? i18n("Hide icon text") : i18n("Show icon text"), icon: "format-text-bold",
              run: () => set("caption", tile.showCaption ? "hide" : "show") },
            { text: i18n("Tile colour…"), icon: "color-management", run: () => colorPopup.open() });
        if (big && !isWidget) items.push(
            { text: i18n("Set tile image…"), icon: "viewimage", run: () => root.pickTileImage(id) },
            { text: i18n("Remove tile image"), icon: "edit-delete", enabled: !!tile.tile.image, run: () => set("image", "") });
        if (big && !isWidget && tile.tile.image) items.push(
            { text: tile.tile.imageIcon === "hide" ? i18n("Show icon") : i18n("Hide icon"), icon: "view-visible",
              run: () => set("imageIcon", tile.tile.imageIcon === "hide" ? "" : "hide") });
        if (!Plasmoid.configuration.tilesLocked && !folderId) {
            items.push({ text: i18n("Resize"), icon: "transform-scale", subActions: [
                ["small", i18n("Small")], ["medium", i18n("Medium")], ["wide", i18n("Wide")], ["large", i18n("Large")],
                ["wideLargeH", i18n("W. Large H.")], ["wideLargeV", i18n("W. Large V.")],
                ["hugeH", i18n("3x6 H.")], ["hugeV", i18n("3x6 V.")]
            ].map(s => ({
                text: s[1], checkable: true, checked: tile.tile.size === s[0],
                run: () => root.saveGroups(Tiles.resize(root.groups, id, s[0]))
            })) });
        }
        return items.concat(root.taskbarItem(id));
    }

    // Drop another tile/app here: on the left quarter it goes before this tile, elsewhere both
    // become a folder (or it joins this folder). Inside an opened folder it goes after this tile.
    DropArea {
        id: drop
        anchors.fill: parent
        keys: ["start12-tile"]
        readonly property bool intoFolder: !!drag.source && !Tiles.isFolder(drag.source.favoriteId) && !tile.isWidget
            && !Tiles.isWidget(drag.source.favoriteId)
            && (tile.folderId !== "" || drag.x > tile.width / 4)
        onDropped: d => {
            const id = d.source.favoriteId;
            if (id === tile.tile.id) return;
            if (!Tiles.isFolder(id) && !tile.isWidget && !Tiles.isWidget(id) && (tile.folderId !== "" || d.x > tile.width / 4)) {
                root.saveGroups(Tiles.dropOnTile(root.groups, id, tile.tile.id));
            } else if (tile.folderId === "") {
                root.saveGroups(Tiles.place(root.groups, id, tile.groupIndex, tile.tileIndex));
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        z: Tiles.widgetKind(tile.tile.id) === "notes" ? -1 : 0   // Notes: clicks go to the text field above
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
                if (tile.isWidget && widgetLoader.item && widgetLoader.item.click) {
                    const p = mapToItem(widgetLoader.item, m.x, m.y);
                    widgetLoader.item.click(p.x, p.y);
                } else tile.launch();
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
