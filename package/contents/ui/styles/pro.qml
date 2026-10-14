pragma ComponentBehavior: Bound

import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PC3
import org.kde.kirigami as Kirigami
import ".."
import "../common"

// Start11 "Windows Pro style", two-tone: left = search box + Pinned grid (3 columns, "All apps"),
// right = darker panel with user picture and name, places with icons, power at the bottom.
FocusScope {
    id: style
    focus: true

    readonly property var cfg: Plasmoid.configuration

    Metrics {
        id: m
    }
    readonly property alias metrics: m
    readonly property real side: m.px(20)
    readonly property real rightW: m.px(cfg.menuSize >= 2 ? 240 : 200)

    implicitWidth: m.px(3 * 96 + 16) + side * 2 + rightW
    implicitHeight: m.heightFor([560, 640, 560, 720])
    readonly property real minimumWidth: m.px(2 * 96 + 16) + side * 2 + rightW

    MenuBackground {
        anchors.fill: parent
        metrics: m
    }

    Places {
        id: places
        contextMenu: contextMenu
    }

    // ---- Left: search + pinned ----
    SearchBox {
        id: searchField
        focus: true
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: rightPanel.left
        anchors.margins: style.side
        height: m.px(32)
        metrics: m
        results: pane.search
        onCancel: pane.view !== "home" ? pane.view = "home" : root.close()
    }

    PinnedPane {
        id: pane
        anchors.top: searchField.bottom
        anchors.topMargin: m.px(16)
        anchors.left: parent.left
        anchors.right: rightPanel.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: style.side
        anchors.rightMargin: style.side
        anchors.bottomMargin: m.px(12)
        maxCols: style.cfg.menuSize >= 2 ? 4 : 3
        metrics: m
        contextMenu: contextMenu
        ghost: ghost
    }

    // ---- Right: the second tone ----
    Rectangle {
        id: rightPanel
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: style.rightW
        color: Qt.alpha("black", m.mode === 2 ? 0.06 : 0.22)
        radius: style.cfg.cornerRadius
        Rectangle {   // square off the left corners
            width: parent.radius
            height: parent.height
            color: parent.color
            visible: parent.radius > 0
        }

        Avatar {
            id: avatar
            anchors.horizontalCenter: parent.horizontalCenter
            y: m.px(18)
            width: m.px(56)
            height: width
            metrics: m
            user: places.user
            TapHandler { onTapped: places.showUserMenu(avatar) }
        }
        PC3.Label {
            id: userName
            anchors.top: avatar.bottom
            anchors.topMargin: m.px(8)
            anchors.left: parent.left
            anchors.right: parent.right
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: places.user.fullName || places.user.loginName
            color: m.text
            font.family: m.font
            font.pixelSize: Math.round(m.fontSize * 1.25)
        }

        Column {
            anchors.top: userName.bottom
            anchors.topMargin: m.px(14)
            anchors.bottom: powerButton.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: m.px(12)
            anchors.rightMargin: m.px(12)
            clip: true
            Repeater {
                model: style.cfg.railItems.filter(id => id !== "user" && id !== "power" && places.info(id) !== undefined)
                delegate: PC3.AbstractButton {
                    id: place
                    required property string modelData
                    readonly property var info: places.info(modelData)
                    width: parent.width
                    height: m.px(36)
                    hoverEnabled: true
                    leftPadding: m.px(10)
                    onClicked: places.activate(modelData, place)
                    background: Rectangle {
                        radius: m.px(4)
                        color: m.text
                        opacity: place.pressed ? 0.14 : place.hovered ? 0.08 : 0
                    }
                    contentItem: Row {
                        spacing: m.px(12)
                        Kirigami.Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            width: m.px(16)
                            height: width
                            source: place.info.icon
                            color: m.text
                            isMask: place.info.icon.endsWith("-symbolic")
                        }
                        PC3.Label {
                            anchors.verticalCenter: parent.verticalCenter
                            width: place.width - x - place.leftPadding
                            text: place.info.text
                            elide: Text.ElideRight
                            color: m.text
                            font.family: m.font
                            font.pixelSize: Math.round(m.fontSize * 0.95)
                        }
                    }
                }
            }
        }

        PC3.ToolButton {
            id: powerButton
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: m.px(12)
            icon.name: "system-shutdown-symbolic"
            onClicked: places.showPowerMenu(powerButton)
            PC3.ToolTip.text: i18n("Power")
            PC3.ToolTip.visible: hovered
        }
    }

    DragGhost {
        id: ghost
        metrics: m
    }

    ContextMenu {
        id: contextMenu
        onActionDone: root.close()
    }

    Connections {
        target: root
        function onExpandedChanged() {
            if (root.expanded) {
                pane.reset();
                searchField.forceActiveFocus();
            }
        }
    }
}
