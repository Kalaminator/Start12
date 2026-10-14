pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PC3
import org.kde.kirigami as Kirigami
import "../win10"
import ".."
import "../common"

// Start11 "Windows 11 style": search box, Pinned grid, Recommended, user + power bar.
// "All apps" swaps the middle for the A-Z list.
FocusScope {
    id: style
    focus: true

    readonly property var cfg: Plasmoid.configuration
    property string view: cfg.openAllApps ? "all" : "home"   // home | all | more

    Metrics {
        id: m
    }
    readonly property alias metrics: m
    readonly property real side: m.px(32)          // left/right margin

    implicitWidth: pinned.implicitWidth + side * 2 + m.px(16)
    implicitHeight: m.heightFor([600, 726, 600, 726])
    readonly property real minimumWidth: m.px(3 * 96) + side * 2

    MenuBackground {
        anchors.fill: parent
        metrics: m
    }

    Places {
        id: places
        contextMenu: contextMenu
    }

    component SectionTitle: PC3.Label {
        color: m.text
        font.family: m.font
        font.weight: Font.DemiBold
        font.pixelSize: Math.round(m.fontSize * 1.05)
    }

    // ---- Search box (click or type to search) ----
    PC3.AbstractButton {
        id: searchBox
        visible: style.cfg.showSearchBox && !root.searching
        anchors.top: parent.top
        anchors.topMargin: m.px(24)
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: style.side
        anchors.rightMargin: style.side
        height: m.px(34)
        hoverEnabled: true
        onClicked: search.focusField()
        background: Rectangle {
            radius: height / 2
            color: Qt.alpha(m.text, searchBox.hovered ? 0.1 : 0.06)
            border.width: 1
            border.color: Qt.alpha(m.text, 0.12)
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - parent.radius * 2
                height: 2
                color: m.accent
            }
        }
        contentItem: Row {
            leftPadding: m.px(12)
            spacing: m.px(10)
            Kirigami.Icon {
                anchors.verticalCenter: parent.verticalCenter
                width: m.px(16)
                height: width
                source: "search"
                color: m.text
                isMask: true
            }
            PC3.Label {
                anchors.verticalCenter: parent.verticalCenter
                text: i18n("Type here to search")
                color: m.text
                opacity: 0.6
                font.family: m.font
                font.pixelSize: m.fontSize
            }
        }
    }

    // ---- Middle: home (pinned + recommended), all apps, or more recommended ----
    Item {
        id: middle
        visible: !root.searching
        anchors.top: style.cfg.showSearchBox ? searchBox.bottom : parent.top
        anchors.topMargin: m.px(style.cfg.showSearchBox ? 20 : 28)
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: style.side
        anchors.rightMargin: style.side
        anchors.bottom: bottomBar.top
        anchors.bottomMargin: m.px(8)
        clip: true

        // Home
        ColumnLayout {
            anchors.fill: parent
            visible: style.view === "home"
            spacing: m.px(10)

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: m.px(24)
                SectionTitle { text: i18n("Pinned"); Layout.fillWidth: true }
                SmallButton { metrics: m; text: i18n("All apps"); iconName: "go-next"; onClicked: style.view = "all" }
            }
            PinnedGrid {
                id: pinned
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: implicitWidth
                Layout.preferredHeight: implicitHeight
                metrics: m
                contextMenu: contextMenu
                ghost: ghost
                extraCols: style.cfg.menuSize >= 2 ? 2 : 0
            }
            RowLayout {
                visible: style.cfg.showRecommended
                Layout.fillWidth: true
                Layout.leftMargin: m.px(24)
                Layout.topMargin: m.px(12)
                SectionTitle { text: i18n("Recommended"); Layout.fillWidth: true }
                SmallButton { metrics: m; text: i18n("More"); iconName: "go-next"; onClicked: style.view = "more" }
            }
            Recommended {
                visible: style.cfg.showRecommended
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.leftMargin: m.px(14)
                Layout.rightMargin: m.px(14)
                fitToHeight: true
                metrics: m
                contextMenu: contextMenu
            }
            Item { Layout.fillHeight: true; visible: !style.cfg.showRecommended }
        }

        // All apps
        ColumnLayout {
            anchors.fill: parent
            visible: style.view === "all"
            spacing: m.px(6)
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: m.px(24)
                SectionTitle { text: i18n("All apps"); Layout.fillWidth: true }
                SmallButton { metrics: m; text: i18n("Back"); iconName: "go-previous"; iconFirst: true; onClicked: style.view = "home" }
            }
            AppList {
                id: appList
                Layout.fillWidth: true
                Layout.fillHeight: true
                metrics: m
                contextMenu: contextMenu
                ghost: ghost
            }
        }

        // More recommended
        ColumnLayout {
            anchors.fill: parent
            visible: style.view === "more"
            spacing: m.px(6)
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: m.px(24)
                SectionTitle { text: i18n("Recommended"); Layout.fillWidth: true }
                SmallButton { metrics: m; text: i18n("Back"); iconName: "go-previous"; iconFirst: true; onClicked: style.view = "home" }
            }
            Flickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentHeight: moreList.implicitHeight
                Recommended {
                    id: moreList
                    width: parent.width
                    metrics: m
                    contextMenu: contextMenu
                    maxItems: 40
                }
            }
        }
    }

    SearchView {
        id: search
        metrics: m
        visible: root.searching
        anchors.top: parent.top
        anchors.topMargin: m.px(8)
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: m.px(16)
        anchors.rightMargin: m.px(16)
        anchors.bottom: bottomBar.top
        contextMenu: contextMenu
    }

    // ---- Bottom bar: user left, shortcuts + power right ----
    Rectangle {
        id: bottomBar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: m.px(64)
        color: Qt.alpha(m.mode === 2 ? "black" : "black", m.mode === 2 ? 0.04 : 0.18)
        radius: style.cfg.cornerRadius
        Rectangle {   // square off the top corners
            anchors.top: parent.top
            width: parent.width
            height: parent.radius
            color: parent.color
            visible: parent.radius > 0
        }
        Rectangle {
            anchors.top: parent.top
            width: parent.width
            height: 1
            color: Qt.alpha(m.text, 0.08)
        }

        PC3.AbstractButton {
            id: userButton
            anchors.left: parent.left
            anchors.leftMargin: m.px(36)
            anchors.verticalCenter: parent.verticalCenter
            height: m.px(40)
            hoverEnabled: true
            leftPadding: m.px(10)
            rightPadding: m.px(12)
            onClicked: places.showUserMenu(userButton)
            background: Rectangle {
                radius: m.px(4)
                color: m.text
                opacity: userButton.pressed ? 0.12 : (userButton.hovered ? 0.07 : 0)
            }
            contentItem: Row {
                spacing: m.px(10)
                Kirigami.ShadowedImage {
                    id: avatar
                    anchors.verticalCenter: parent.verticalCenter
                    width: m.px(28)
                    height: width
                    radius: width / 2
                    color: Qt.alpha(m.text, 0.15)
                    source: places.user.faceIconUrl
                    sourceSize: Qt.size(width * 2, height * 2)
                    fillMode: Image.PreserveAspectCrop
                    Kirigami.Icon {
                        anchors.centerIn: parent
                        visible: avatar.status !== Image.Ready
                        width: parent.width * 0.6
                        height: width
                        source: "user-identity"
                        color: m.text
                        isMask: true
                    }
                }
                PC3.Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: places.user.fullName || places.user.loginName
                    color: m.text
                    font.family: m.font
                    font.pixelSize: Math.round(m.fontSize * 0.95)
                }
            }
        }

        Row {
            anchors.right: parent.right
            anchors.rightMargin: m.px(36)
            anchors.verticalCenter: parent.verticalCenter
            spacing: m.px(4)
            Repeater {
                model: style.cfg.bottomItems.filter(id => places.info(id) !== undefined).concat(["power"])
                delegate: PC3.AbstractButton {
                    id: sc
                    required property string modelData
                    readonly property var info: places.info(modelData)
                    width: m.px(40)
                    height: width
                    hoverEnabled: true
                    onClicked: places.activate(modelData, sc)
                    PC3.ToolTip.text: info.text
                    PC3.ToolTip.visible: hovered
                    PC3.ToolTip.delay: Kirigami.Units.toolTipDelay
                    background: Rectangle {
                        radius: m.px(4)
                        color: m.text
                        opacity: sc.pressed ? 0.12 : (sc.hovered ? 0.07 : 0)
                    }
                    contentItem: Item {
                        Kirigami.Icon {
                            anchors.centerIn: parent
                            width: m.px(18)
                            height: width
                            source: sc.info.icon
                            color: m.text
                            isMask: sc.info.icon.endsWith("-symbolic")
                        }
                    }
                }
            }
        }
    }

    // Shared drag "ghost" for reordering pinned apps.
    Item {
        id: ghost
        property string favoriteId: ""
        property var icon: null
        width: m.px(48)
        height: width
        z: 100
        visible: Drag.active
        Drag.keys: ["start12-tile"]
        Drag.hotSpot.x: width / 2
        Drag.hotSpot.y: height / 2
        Kirigami.Icon {
            anchors.centerIn: parent
            width: m.px(32)
            height: width
            source: ghost.icon
        }
    }

    ContextMenu {
        id: contextMenu
        onActionDone: root.close()
    }

    // Typing anywhere starts a search.
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            if (root.searching) {
                root.searchText = "";
            } else if (style.view !== "home") {
                style.view = "home";
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
                style.view = style.cfg.openAllApps ? "all" : "home";
                style.forceActiveFocus();
                appList.reset();
            }
        }
    }
}
