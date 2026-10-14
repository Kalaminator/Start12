pragma ComponentBehavior: Bound

import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PC3
import org.kde.kirigami as Kirigami
import "../win10"
import ".."
import "../common"

// Start11 "Windows App style": top bar (small picture, name, shortcuts, power),
// app canvas (tabs + groups) on the left, the all apps list always open on the right.
// Typing anywhere searches.
FocusScope {
    id: style
    focus: true

    readonly property var cfg: Plasmoid.configuration

    Metrics {
        id: m
    }
    readonly property alias metrics: m
    readonly property real pad: m.px(12)
    readonly property real canvasW: m.px(cfg.menuSize >= 2 ? 420 : 280)

    implicitWidth: canvasW + m.list + pad * 3
    implicitHeight: m.heightFor([520, 600, 520, 700])
    readonly property real minimumWidth: m.px(220) + m.px(220) + pad * 3

    MenuBackground {
        anchors.fill: parent
        metrics: m
    }

    Places {
        id: places
        contextMenu: contextMenu
    }

    // ---- Top bar ----
    Rectangle {
        id: topBar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: m.px(52)
        color: Qt.alpha("black", m.mode === 2 ? 0.05 : 0.2)
        radius: style.cfg.cornerRadius
        Rectangle {   // square off the bottom corners
            anchors.bottom: parent.bottom
            width: parent.width
            height: parent.radius
            color: parent.color
            visible: parent.radius > 0
        }

        PC3.AbstractButton {
            id: userButton
            anchors.left: parent.left
            anchors.leftMargin: m.px(8)
            anchors.verticalCenter: parent.verticalCenter
            height: m.px(40)
            hoverEnabled: true
            leftPadding: m.px(6)
            rightPadding: m.px(10)
            onClicked: places.showUserMenu(userButton)
            background: Rectangle {
                radius: m.px(4)
                color: m.text
                opacity: userButton.pressed ? 0.12 : (userButton.hovered ? 0.07 : 0)
            }
            contentItem: Row {
                spacing: m.px(10)
                Avatar {
                    anchors.verticalCenter: parent.verticalCenter
                    width: m.px(30)
                    height: width
                    metrics: m
                    user: places.user
                }
                PC3.Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: places.user.fullName || places.user.loginName
                    color: m.text
                    font.family: m.font
                    font.pixelSize: Math.round(m.fontSize * 1.05)
                }
            }
        }

        Row {
            anchors.right: parent.right
            anchors.rightMargin: m.px(8)
            anchors.verticalCenter: parent.verticalCenter
            spacing: m.px(2)
            Repeater {
                model: style.cfg.bottomItems.filter(id => places.info(id) !== undefined).concat(["power"])
                delegate: PC3.ToolButton {
                    id: sc
                    required property string modelData
                    readonly property var info: places.info(modelData)
                    icon.name: info.icon
                    onClicked: places.activate(modelData, sc)
                    PC3.ToolTip.text: info.text
                    PC3.ToolTip.visible: hovered
                    PC3.ToolTip.delay: Kirigami.Units.toolTipDelay
                }
            }
        }
    }

    // ---- Body: canvas | all apps ----
    AppCanvas {
        id: canvas
        visible: !root.searching
        anchors.top: topBar.bottom
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: style.pad
        width: Math.min(style.canvasW, parent.width / 2)
        metrics: m
        contextMenu: contextMenu
    }

    Rectangle {
        visible: !root.searching
        anchors.left: canvas.right
        anchors.leftMargin: style.pad / 2
        anchors.top: canvas.top
        anchors.bottom: canvas.bottom
        width: 1
        color: Qt.alpha(m.text, 0.12)
    }

    AppList {
        id: appList
        visible: !root.searching
        anchors.top: topBar.bottom
        anchors.left: canvas.right
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: style.pad
        metrics: m
        contextMenu: contextMenu
        ghost: ghost
    }

    SearchView {
        id: search
        visible: root.searching
        anchors.top: topBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: style.pad
        metrics: m
        contextMenu: contextMenu
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
        panes: [canvas, appList]
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
        function onExpandedChanged() {
            if (root.expanded) {
                canvas.reset();
                appList.reset();
                style.forceActiveFocus();
            }
        }
    }
}
