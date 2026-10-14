pragma ComponentBehavior: Bound

import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PC3
import org.kde.plasma.private.kicker as Kicker
import org.kde.kirigami as Kirigami
import org.kde.kitemmodels as KItemModels
import "../code/tiles.js" as Tiles

// Windows 11 "Pinned": pages of icons with names. Drag to reorder; wheel or dots change page.
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
    readonly property int pages: Math.max(1, Math.ceil(cfg.pinnedGrid.length / perPage))
    property int page: 0
    onPagesChanged: page = Math.min(page, pages - 1)

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
                model: grid.cfg.pinnedGrid
                delegate: PC3.AbstractButton {
                    id: cell
                    required property string modelData
                    required property int index
                    width: grid.cellW
                    height: grid.cellH
                    hoverEnabled: true

                    Kicker.SimpleFavoritesModel {
                        id: fav
                        favorites: [cell.modelData]
                    }
                    function role(name) {
                        return fav.count > 0 ? fav.data(fav.index(0, 0), fav.KItemModels.KRoleNames.role(name)) : undefined;
                    }
                    // Pinned website/file/folder instead of an app.
                    readonly property var custom: Tiles.custom(modelData)
                    readonly property var appIcon: custom ? (custom.icon || "folder") : fav.count > 0 ? role("decoration") : "dialog-question"

                    background: Rectangle {
                        radius: grid.metrics.px(4)
                        color: grid.metrics.text
                        opacity: mouse.pressed && !mouse.dragging ? 0.12 : (cell.hovered ? 0.07 : 0)
                        Rectangle {
                            visible: drop.containsDrag
                            width: Math.max(2, grid.metrics.px(3))
                            height: parent.height
                            color: grid.metrics.accent
                        }
                    }
                    opacity: mouse.dragging ? 0.3 : 1

                    contentItem: Column {
                        spacing: grid.metrics.px(6)
                        topPadding: grid.metrics.px(10)
                        Kirigami.Icon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: grid.metrics.px(32)
                            height: width
                            source: cell.appIcon
                        }
                        PC3.Label {
                            width: cell.width - grid.metrics.px(8)
                            anchors.horizontalCenter: parent.horizontalCenter
                            horizontalAlignment: Text.AlignHCenter
                            text: cell.custom ? cell.custom.name : fav.count > 0 ? cell.role("display") : cell.modelData
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
                        keys: ["start12-tile"]
                        onDropped: d => root.movePinned(d.source.favoriteId, cell.index)
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
                                if (cell.custom) {
                                    root.openCustom(cell.custom);
                                } else {
                                    if (fav.count > 0) fav.trigger(0, "", null);
                                    root.close();
                                }
                            } else if (m.button === Qt.RightButton) {
                                const id = cell.modelData;
                                grid.contextMenu.show(cell, fav.count > 0 ? fav : null, 0, [
                                    { text: i18n("Unpin from Start"), icon: "window-unpin", run: () => root.unpin(id) },
                                    { text: i18n("Move to front"), icon: "go-first", enabled: cell.index > 0, run: () => root.movePinned(id, 0) }
                                ], m.x, m.y);
                            }
                        }
                        onCanceled: {
                            grid.ghost.Drag.active = false;
                            dragging = false;
                        }
                    }
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
