pragma ComponentBehavior: Bound

import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PC3
import org.kde.kirigami as Kirigami
import "../code/tiles.js" as Tiles

// One named group of tiles. Click the title to rename it.
Column {
    id: grp

    required property var group
    required property int groupIndex
    required property QtObject metrics
    required property var contextMenu
    required property Item ghost

    readonly property var layout: Tiles.pack(group.tiles, metrics.columns)
    readonly property real cell: metrics.unit + metrics.gap
    property var names: ({})   // tile id -> app name, for "Sort A-Z"
    // Opened folder tile (id): its tiles show in a row under the group.
    property string openFolder: ""
    readonly property var folder: group.tiles.find(t => t.id === openFolder && t.kind === "folder") || null
    readonly property var folderLayout: folder ? Tiles.pack(folder.tiles, metrics.columns) : null

    width: metrics.groupWidth
    spacing: Math.round(6 * metrics.s)

    function rename(text) {
        const g = Tiles.clone(root.groups);
        g[groupIndex].name = text;
        root.saveGroups(g);
    }

    function startRename() {
        editor.text = group.name;
        editor.visible = true;
        editor.forceActiveFocus();
        editor.selectAll();
    }

    // ---- Title ----
    Item {
        width: parent.width
        height: Math.round(30 * grp.metrics.s)

        // Drop on the group name: a tile goes first in this group, a group goes before this one.
        DropArea {
            id: titleDrop
            anchors.fill: parent
            keys: ["start12-tile", "start12-group"]
            onDropped: drop => {
                if (drop.source.kind === "group") {
                    root.saveGroups(Tiles.moveGroup(root.groups, drop.source.groupIndex, grp.groupIndex));
                } else {
                    root.saveGroups(Tiles.place(root.groups, drop.source.favoriteId, grp.groupIndex, 0));
                }
            }
        }
        Rectangle {   // drop marker for groups
            visible: titleDrop.containsDrag && titleDrop.drag.source && titleDrop.drag.source.kind === "group"
            width: parent.width
            height: Math.max(2, grp.metrics.px(3))
            color: grp.metrics.accent
        }

        // Click the name to rename; drag it to move the whole group.
        MouseArea {
            id: titleMouse
            anchors.fill: parent
            anchors.rightMargin: menuBtn.width
            enabled: !Plasmoid.configuration.tilesLocked && !editor.visible
            preventStealing: true
            cursorShape: dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            property point pressPos
            property bool dragging: false
            onPressed: m => pressPos = Qt.point(m.x, m.y)
            onPositionChanged: m => {
                if (!dragging && pressed && Math.hypot(m.x - pressPos.x, m.y - pressPos.y) > Qt.styleHints.startDragDistance) {
                    dragging = true;
                    grp.ghost.kind = "group";
                    grp.ghost.groupIndex = grp.groupIndex;
                    grp.ghost.label = grp.group.name || i18n("Group");
                    grp.ghost.Drag.active = true;
                }
                if (dragging) {
                    const p = mapToItem(grp.ghost.parent, m.x, m.y);
                    grp.ghost.x = p.x - grp.ghost.width / 2;
                    grp.ghost.y = p.y - grp.ghost.height / 2;
                }
            }
            onReleased: m => {
                if (dragging) {
                    grp.ghost.Drag.drop();
                    grp.ghost.Drag.active = false;
                    grp.ghost.kind = "tile";
                    dragging = false;
                } else if (containsMouse) {
                    grp.startRename();
                }
            }
            onCanceled: {
                grp.ghost.Drag.active = false;
                grp.ghost.kind = "tile";
                dragging = false;
            }
        }

        PC3.Label {
            id: title
            visible: !editor.visible
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - menuBtn.width
            text: grp.group.name !== "" ? grp.group.name : (titleHover.hovered ? i18n("Name group") : "")
            color: grp.metrics.text
            opacity: grp.group.name !== "" ? 1 : 0.6
            font.family: grp.metrics.font
            font.pixelSize: grp.metrics.fontSize
            elide: Text.ElideRight
            HoverHandler { id: titleHover }
        }
        PC3.TextField {
            id: editor
            visible: false
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            placeholderText: i18n("Name group")
            onAccepted: { grp.rename(text); visible = false; }
            onActiveFocusChanged: if (!activeFocus && visible) { grp.rename(text); visible = false; }
            Keys.onEscapePressed: visible = false
        }
        // "=" handle, like Windows 10, opens the group menu.
        PC3.ToolButton {
            id: menuBtn
            visible: titleHover.hovered || hovered
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            icon.name: "application-menu-symbolic"
            onClicked: grp.contextMenu.show(menuBtn, null, -1, [
                { text: i18n("Name group"), icon: "edit-rename", run: () => grp.startRename() },
                { text: i18n("Resort group A-Z"), icon: "view-sort-ascending",
                  run: () => root.saveGroups(Tiles.sortGroup(root.groups, grp.groupIndex, grp.names)) },
                { text: i18n("Move group up"), icon: "go-up", enabled: grp.groupIndex > 0,
                  run: () => root.saveGroups(Tiles.moveGroup(root.groups, grp.groupIndex, grp.groupIndex - 1)) },
                { text: i18n("Move group down"), icon: "go-down", enabled: grp.groupIndex < root.groups.length - 1,
                  run: () => root.saveGroups(Tiles.moveGroup(root.groups, grp.groupIndex, grp.groupIndex + 2)) },
                { text: i18n("Move to previous page"), icon: "go-previous", enabled: root.tilePage > 0,
                  run: () => root.savePages(Tiles.moveGroupToPage(root.pages, root.tilePage, grp.groupIndex, root.tilePage - 1)) },
                { text: i18n("Move to next page"), icon: "go-next", enabled: root.tilePage < root.pages.length - 1,
                  run: () => root.savePages(Tiles.moveGroupToPage(root.pages, root.tilePage, grp.groupIndex, root.tilePage + 1)) },
                { type: "separator" },
                { text: i18n("Unpin group from Start"), icon: "edit-delete",
                  run: () => { const g = Tiles.clone(root.groups); g.splice(grp.groupIndex, 1); root.saveGroups(g); } }
            ])
        }
    }

    // ---- Tiles ----
    Item {
        id: body
        width: parent.width
        height: Math.max(1, grp.layout.rows) * grp.cell - grp.metrics.gap

        // Drop on empty space in the group: a tile goes at the end, a group goes after this one.
        DropArea {
            id: bodyDrop
            anchors.fill: parent
            keys: ["start12-tile", "start12-group"]
            onDropped: drop => {
                if (drop.source.kind === "group") {
                    root.saveGroups(Tiles.moveGroup(root.groups, drop.source.groupIndex, grp.groupIndex + 1));
                } else {
                    root.saveGroups(Tiles.place(root.groups, drop.source.favoriteId, grp.groupIndex, grp.group.tiles.length));
                }
            }
        }
        Rectangle {   // drop marker for groups: under this group
            visible: bodyDrop.containsDrag && bodyDrop.drag.source && bodyDrop.drag.source.kind === "group"
            anchors.top: parent.bottom
            anchors.topMargin: grp.metrics.px(4)
            width: parent.width
            height: Math.max(2, grp.metrics.px(3))
            color: grp.metrics.accent
        }

        Repeater {
            model: grp.group.tiles
            delegate: Tile {
                required property var modelData
                required property int index
                tile: modelData
                tileIndex: index
                groupIndex: grp.groupIndex
                metrics: grp.metrics
                contextMenu: grp.contextMenu
                ghost: grp.ghost
                readonly property var p: grp.layout.pos[index]
                x: p.x * grp.cell
                y: p.y * grp.cell
                width: p.w * grp.cell - grp.metrics.gap
                height: p.h * grp.cell - grp.metrics.gap
                onNameKnown: name => grp.names[tile.id] = name
                onFolderClicked: rename => {
                    grp.openFolder = rename || grp.openFolder !== tile.id ? tile.id : "";
                    if (rename) Qt.callLater(() => { folderName.forceActiveFocus(); folderName.selectAll(); });
                }
            }
        }
    }

    // ---- Opened folder ----
    Rectangle {
        visible: grp.folder !== null
        width: parent.width
        height: visible ? folderBody.y + folderBody.height + grp.metrics.gap * 2 : 0
        radius: Math.round(2 * grp.metrics.s)
        color: Qt.alpha(grp.metrics.tile, grp.metrics.tileAlpha * 0.6)

        PC3.TextField {
            id: folderName
            x: grp.metrics.gap
            y: grp.metrics.gap
            width: parent.width - 2 * grp.metrics.gap - closeFolder.width
            text: grp.folder ? grp.folder.name : ""
            placeholderText: i18n("Name folder")
            background: null
            color: grp.metrics.text
            font.family: grp.metrics.font
            font.pixelSize: grp.metrics.fontSize
            onEditingFinished: if (grp.folder && text !== grp.folder.name)
                root.saveGroups(Tiles.setProp(root.groups, grp.openFolder, "name", text))
        }
        PC3.ToolButton {
            id: closeFolder
            anchors.right: parent.right
            anchors.verticalCenter: folderName.verticalCenter
            icon.name: "go-up"
            onClicked: grp.openFolder = ""
        }
        Item {
            id: folderBody
            y: folderName.y + folderName.height + grp.metrics.gap
            width: parent.width
            height: grp.folderLayout ? Math.max(1, grp.folderLayout.rows) * grp.cell - grp.metrics.gap : 0
            Repeater {
                model: grp.folder ? grp.folder.tiles : []
                delegate: Tile {
                    required property var modelData
                    required property int index
                    tile: modelData
                    tileIndex: index
                    groupIndex: grp.groupIndex
                    folderId: grp.openFolder
                    metrics: grp.metrics
                    contextMenu: grp.contextMenu
                    ghost: grp.ghost
                    readonly property var p: grp.folderLayout.pos[index]
                    x: p.x * grp.cell
                    y: p.y * grp.cell
                    width: p.w * grp.cell - grp.metrics.gap
                    height: p.h * grp.cell - grp.metrics.gap
                }
            }
        }
    }
}
