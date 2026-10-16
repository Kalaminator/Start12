pragma ComponentBehavior: Bound

import QtQuick
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami
import "../win10"
import ".."
import "../common"

// Start11 "Windows 10 style": left rail | A-Z app list | tile groups.
FocusScope {
    id: style
    focus: true

    readonly property var cfg: Plasmoid.configuration

    Metrics {
        id: m
    }
    readonly property alias metrics: m
    // App list width; design mode drags it (common/SplitHandle), the tiles keep their size.
    readonly property real listW: style.cfg.hideAppList ? 0 : root.splitFor(root.menuKind, m.list)

    implicitWidth: m.rail + listW + m.pad * 2 + m.groupCols * m.groupWidth + (m.groupCols - 1) * m.pad * 2
    // No custom height yet (first open, or style just changed): tall enough for the tile groups, so the tile
    // area needs no scroll bar. Once the user drags the height (saved as menuHeight), their size wins.
    implicitHeight: style.cfg.menuHeight > 0 ? m.heightFor([480, 600, 480, 640])
                  : Math.max(m.heightFor([480, 600, 480, 640]), tiles.neededHeight)
    // Narrowest: rail + list + one tile group.
    readonly property real minimumWidth: m.rail + listW + m.pad * 2 + m.groupWidth

    MenuBackground {
        anchors.fill: parent
        metrics: m
    }

    // ---- Layout ----
    Item {
        id: body
        anchors.left: parent.left
        anchors.leftMargin: m.rail
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom

        AppList {
            id: appList
            metrics: m
            visible: !root.searching && !style.cfg.hideAppList
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: style.listW
            contextMenu: contextMenu
            ghost: ghost
        }

        TileArea {
            id: tiles
            metrics: m
            visible: !root.searching
            anchors.left: appList.visible ? appList.right : parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            contextMenu: contextMenu
            ghost: ghost
        }

        SplitHandle {
            shown: appList.visible
            name: root.menuKind
            value: style.listW
            minimum: m.px(180)
            maximum: m.px(600)
            x: (LayoutMirroring.enabled ? appList.x : appList.x + appList.width) - width / 2
            anchors.top: parent.top
            anchors.bottom: parent.bottom
        }

        SearchView {
            id: search
            metrics: m
            visible: root.searching
            anchors.fill: parent
            contextMenu: contextMenu
        }
    }

    // On top of the list, so "expand on hover" can overlay it.
    LeftRail {
        id: rail
        metrics: m
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        contextMenu: contextMenu
        background: Qt.alpha(m.bg, Math.max(0.97, m.bgAlpha))
    }

    // Shared drag "ghost": app list rows and tiles drag this onto tile drop areas.
    Item {
        id: ghost
        property string kind: "tile"      // "tile" or "group"
        property string favoriteId: ""
        property int groupIndex: -1
        property string label: ""
        property var icon: null
        width: kind === "group" ? groupLabel.implicitWidth + m.px(24) : m.unit * 2
        height: kind === "group" ? m.px(30) : m.unit * 2
        z: 100
        visible: Drag.active
        Drag.keys: [kind === "group" ? "win12-group" : "win12-tile"]
        Drag.hotSpot.x: width / 2
        Drag.hotSpot.y: height / 2
        Rectangle {
            anchors.fill: parent
            color: Qt.alpha(m.text, 0.2)
            radius: 3
        }
        Kirigami.Icon {
            anchors.centerIn: parent
            visible: ghost.kind === "tile"
            width: parent.width * 0.6
            height: width
            source: ghost.icon
        }
        Text {
            id: groupLabel
            anchors.centerIn: parent
            visible: ghost.kind === "group"
            text: ghost.label
            color: m.text
            font.family: m.font
            font.pixelSize: m.fontSize
        }
    }

    ContextMenu {
        id: contextMenu
        onActionDone: root.close()
    }

    KeyNav {
        id: nav
        panes: [rail, appList, tiles]
        main: appList
    }

    // Arrows/Tab/Enter move through the menu; typing anywhere starts a search.
    Keys.onPressed: event => {
        if (nav.handle(event)) {
            event.accepted = true;
        } else if (event.key === Qt.Key_Escape) {
            if (root.searching) {
                root.searchText = "";
            } else {
                root.close();
            }
            event.accepted = true;
        } else if (event.text.length > 0 && event.text.trim().length > 0
                   && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) {
            root.searchText += event.text;
            search.focusField();
            event.accepted = true;
        }
    }

    Connections {
        target: root
        function onMenuOpenChanged() {
            if (root.menuOpen) {
                style.forceActiveFocus();
                appList.reset();
            }
        }
    }
}
