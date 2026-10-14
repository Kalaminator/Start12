pragma ComponentBehavior: Bound

import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PC3
import org.kde.kirigami as Kirigami
import "../common"

// Windows 10 left strip. Modes (RightIconMode): icons only, expand on hover, always show names.
Item {
    id: rail

    required property QtObject metrics
    required property var contextMenu
    property color background: "transparent"

    readonly property var cfg: Plasmoid.configuration
    readonly property bool expanded: cfg.railMode === 2 || (cfg.railMode === 1 && (hoverTimer.done || pinned))
    property bool pinned: false

    width: expanded ? Math.max(metrics.rail, metrics.railExpanded) : metrics.rail
    Behavior on width { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
    clip: true

    Places {
        id: places
        contextMenu: rail.contextMenu
    }
    readonly property var kuser: places.user
    function info(id) { return places.info(id); }

    // Hover expansion waits a moment, like Windows 10.
    HoverHandler {
        id: hover
        enabled: rail.cfg.railMode === 1
    }
    Timer {
        id: hoverTimer
        property bool done: false
        interval: 450
        running: hover.hovered && !done
        onTriggered: done = true
    }
    Connections {
        target: hover
        function onHoveredChanged() {
            if (!hover.hovered) {
                hoverTimer.done = false;
                rail.pinned = false;
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        visible: rail.expanded && rail.cfg.railMode === 1
        color: rail.background
    }

    // "Hamburger" at the top in hover mode: click to open the names at once.
    PC3.AbstractButton {
        id: hamburger
        visible: rail.cfg.railMode === 1
        anchors.top: parent.top
        anchors.topMargin: rail.metrics.px(4)
        width: rail.width
        height: rail.metrics.px(46)
        hoverEnabled: true
        onClicked: rail.pinned = !rail.pinned
        contentItem: Item {}
        background: Rectangle {
            color: rail.metrics.text
            opacity: hamburger.hovered ? 0.08 : 0
        }
        Kirigami.Icon {
            x: Math.round((rail.metrics.rail - width) / 2)
            anchors.verticalCenter: parent.verticalCenter
            width: rail.metrics.railIcon
            height: width
            source: "application-menu-symbolic"
            color: rail.metrics.text
            isMask: true
        }
    }

    Column {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: rail.metrics.px(4)
        width: parent.width

        Repeater {
            model: rail.cfg.railItems.filter(id => rail.info(id) !== undefined)

            delegate: PC3.AbstractButton {
                id: btn
                required property string modelData
                readonly property var item: rail.info(modelData)
                width: rail.width
                height: rail.metrics.px(46)
                hoverEnabled: true
                onClicked: places.activate(modelData, btn)

                PC3.ToolTip.text: item.text
                PC3.ToolTip.visible: hovered && !rail.expanded
                PC3.ToolTip.delay: Kirigami.Units.toolTipDelay

                contentItem: Item {}
                background: Rectangle {
                    color: rail.metrics.text
                    opacity: btn.pressed ? 0.16 : (btn.hovered ? 0.08 : 0)
                }

                Kirigami.Icon {
                    id: glyph
                    x: Math.round((rail.metrics.rail - width) / 2)
                    anchors.verticalCenter: parent.verticalCenter
                    width: rail.metrics.railIcon
                    height: width
                    visible: btn.modelData !== "user" || avatar.status !== Image.Ready
                    source: btn.item.icon
                    color: rail.metrics.text
                    isMask: btn.item.icon.endsWith("-symbolic")
                }

                Kirigami.ShadowedImage {
                    id: avatar
                    x: Math.round((rail.metrics.rail - width) / 2)
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.round(rail.metrics.railIcon * 1.35)
                    height: width
                    radius: width / 2
                    color: "transparent"
                    visible: btn.modelData === "user" && status === Image.Ready
                    source: btn.modelData === "user" ? rail.kuser.faceIconUrl : ""
                    sourceSize: Qt.size(width * 2, height * 2)
                    fillMode: Image.PreserveAspectCrop
                }

                PC3.Label {
                    visible: rail.expanded
                    x: rail.metrics.rail
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - x - rail.metrics.px(8)
                    text: btn.item.text
                    elide: Text.ElideRight
                    color: rail.metrics.text
                    font.family: rail.metrics.font
                    font.pixelSize: rail.metrics.fontSize
                }
            }
        }
    }
}
