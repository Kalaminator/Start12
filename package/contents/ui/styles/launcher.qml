pragma ComponentBehavior: Bound

import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PC3
import ".."
import "../common"

// Start11 "Windows Launcher style": big user picture and name on top, power at the top right,
// a wide search box, then a large Pinned grid ("All apps" swaps in the A-Z list).
FocusScope {
    id: style
    focus: true

    readonly property var cfg: Plasmoid.configuration

    Metrics {
        id: m
    }
    readonly property alias metrics: m
    readonly property real side: m.px(24)

    implicitWidth: m.px(6 * 96 + 16) + side * 2
    implicitHeight: m.heightFor([620, 720, 620, 780])
    readonly property real minimumWidth: m.px(4 * 96 + 16) + side * 2

    MenuBackground {
        anchors.fill: parent
        metrics: m
    }

    Places {
        id: places
        contextMenu: contextMenu
    }

    // Darker band behind the user and the search box.
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: searchField.bottom
        anchors.bottomMargin: -m.px(18)
        color: Qt.alpha("black", m.mode === 2 ? 0.05 : 0.2)
        radius: style.cfg.cornerRadius
    }

    Avatar {
        id: avatar
        anchors.horizontalCenter: parent.horizontalCenter
        y: m.px(18)
        width: m.px(64)
        height: width
        metrics: m
        user: places.user
        TapHandler { onTapped: places.showUserMenu(avatar) }
    }
    PC3.Label {
        id: userName
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: avatar.bottom
        anchors.topMargin: m.px(6)
        text: places.user.fullName || places.user.loginName
        color: m.text
        font.family: m.font
        font.pixelSize: Math.round(m.fontSize * 1.3)
        font.weight: Font.DemiBold
    }

    PC3.ToolButton {
        id: powerButton
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: m.px(14)
        icon.name: "system-shutdown-symbolic"
        onClicked: places.showPowerMenu(powerButton)
        PC3.ToolTip.text: i18n("Power")
        PC3.ToolTip.visible: hovered
    }

    SearchBox {
        id: searchField
        focus: true
        anchors.top: userName.bottom
        anchors.topMargin: m.px(14)
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: style.side
        anchors.rightMargin: style.side
        height: m.px(34)
        metrics: m
        results: pane.search
        nav: nav
        onCancel: pane.view !== "home" ? pane.view = "home" : root.close()
    }

    PinnedPane {
        id: pane
        anchors.top: searchField.bottom
        anchors.topMargin: m.px(30)
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: style.side
        anchors.rightMargin: style.side
        anchors.bottomMargin: m.px(12)
        metrics: m
        contextMenu: contextMenu
        ghost: ghost
    }

    DragGhost {
        id: ghost
        metrics: m
    }

    ContextMenu {
        id: contextMenu
        onActionDone: root.close()
    }

    KeyNav {
        id: nav
        panes: [pane]
        main: pane
    }

    Connections {
        target: root
        function onMenuOpenChanged() {
            if (root.menuOpen) {
                pane.reset();
                searchField.forceActiveFocus();
            }
        }
    }
}
