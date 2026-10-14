pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PC3
import "../code/tiles.js" as Tiles

// Right side: tile groups. Drop below the last group to make a new group.
Item {
    id: area

    required property QtObject metrics
    required property var contextMenu
    required property Item ghost

    // Right-click on empty space: menu-surface options (Start11 "Configure", "Lock menu", ...).
    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: point => area.contextMenu.show(area, null, -1, [
            { text: i18n("New group"), icon: "list-add",
              run: () => root.saveGroups(root.groups.concat([{ name: i18n("New group"), tiles: [] }])) },
            ...root.pinNewItems,
            { type: "separator" },
            { text: Plasmoid.configuration.tilesLocked ? i18n("Unlock menu") : i18n("Lock menu"),
              icon: Plasmoid.configuration.tilesLocked ? "object-unlocked" : "object-locked",
              run: () => Plasmoid.configuration.tilesLocked = !Plasmoid.configuration.tilesLocked },
            { text: i18n("Refresh icons"), icon: "view-refresh", run: () => root.rootModel.refresh() },
            { type: "separator" },
            { text: i18n("Configure Start12…"), icon: "configure", run: () => { root.close(); root.openSettings(); } }
        ], point.position.x, point.position.y)
    }

    // Scroll while dragging near the top or bottom edge.
    Timer {
        interval: 16
        repeat: true
        running: area.ghost.Drag.active && area.visible
        onTriggered: {
            const y = area.ghost.mapToItem(area, 0, area.ghost.height / 2).y;
            const edge = area.metrics.unit * 2;
            const speed = area.metrics.px(10);
            if (y < edge) {
                flick.contentY = Math.max(0, flick.contentY - speed);
            } else if (y > area.height - edge) {
                flick.contentY = Math.min(Math.max(0, flick.contentHeight - flick.height), flick.contentY + speed);
            }
        }
    }

    Flickable {
        id: flick
        anchors.fill: parent
        anchors.leftMargin: area.metrics.pad
        anchors.topMargin: Math.round(10 * area.metrics.s)
        clip: true
        contentWidth: width
        contentHeight: flow.height + newGroupDrop.height
        boundsBehavior: Flickable.StopAtBounds
        QQC2.ScrollBar.vertical: PC3.ScrollBar {}

        Flow {
            id: flow
            // Groups wrap to more columns when the menu is made wider, like Windows 10.
            width: flick.width - area.metrics.pad
            spacing: area.metrics.pad * 2

            Repeater {
                model: root.groups
                delegate: TileGroup {
                    required property var modelData
                    required property int index
                    group: modelData
                    groupIndex: index
                    metrics: area.metrics
                    contextMenu: area.contextMenu
                    ghost: area.ghost
                }
            }
        }

        // Empty space under the groups: drop here for a new group.
        DropArea {
            id: newGroupDrop
            anchors.top: flow.bottom
            width: flow.width
            height: Math.max(area.metrics.unit * 4, flick.height - flow.height)
            keys: ["start12-tile", "start12-group"]
            onDropped: drop => {
                if (drop.source.kind === "group") {
                    root.saveGroups(Tiles.moveGroup(root.groups, drop.source.groupIndex, root.groups.length));
                } else {
                    root.saveGroups(Tiles.place(root.groups, drop.source.favoriteId, root.groups.length, 0));
                }
            }
            Rectangle {
                anchors.top: parent.top
                anchors.topMargin: area.metrics.pad
                width: area.metrics.groupWidth
                height: area.metrics.unit * 2
                radius: 3
                color: "transparent"
                border.color: area.metrics.text
                border.width: 1
                opacity: newGroupDrop.containsDrag ? 0.5 : 0
            }
        }

        PC3.Label {
            visible: root.groups.length === 0
            width: area.metrics.groupWidth
            wrapMode: Text.WordWrap
            color: area.metrics.text
            opacity: 0.6
            text: i18n("Drag apps here, or right-click an app and choose \"Pin to Start\".")
        }
    }
}
