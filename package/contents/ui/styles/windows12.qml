pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PC3
import org.kde.kirigami as Kirigami
import "../win10"
import ".."
import "../common"

// "Windows 12 style" (concept art): an app list column (greeting, search, most used, A-Z) beside a
// cards column (folder chips + clock, Pinned grid, recent files), user + power bar at the bottom.
// The list side follows the menu position (Left: list left with greeting; Centre/Right: list right)
// unless win12ListSide forces it; it is applied after the Right-position mirroring.
FocusScope {
    id: style
    focus: true

    readonly property var cfg: Plasmoid.configuration
    property string view: cfg.openAllApps ? "all" : "home"   // home | all | more

    readonly property bool listLeft: cfg.win12ListSide === 1 || (cfg.win12ListSide === 0 && cfg.menuPosition === 0)
    readonly property bool greeting: cfg.win12Greeting === 1 || (cfg.win12Greeting === 0 && listLeft)

    Metrics {
        id: m
    }
    readonly property alias metrics: m
    readonly property real side: m.px(16)
    // List column; design mode drags the divider (common/SplitHandle). implicitWidth keeps the default.
    readonly property real listDef: m.px(cfg.menuSize >= 2 ? 320 : 280)
    readonly property real listW: root.splitFor("win12", listDef)
    readonly property int cols: Math.max(3, Math.min(cfg.pinnedColumns, 5)) + (cfg.menuSize >= 2 ? 1 : 0)
    readonly property real cardsW: m.px(96 * cols + 48)

    implicitWidth: listDef + cardsW + side * 3
    implicitHeight: m.heightFor([640, 726, 640, 726])
    readonly property real minimumWidth: m.px(200 + 3 * 96 + 24) + side * 3

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
        font.family: m.headerFont
        font.weight: Font.DemiBold
        font.pixelSize: Math.round(m.headerFontSize * 1.05)
    }
    component Card: Rectangle {
        radius: m.px(12)
        color: Qt.alpha(m.text, 0.06)
    }

    // ---- Two columns; the side is resolved here, so no mirroring below ----
    Item {
        id: body
        anchors.fill: parent
        anchors.margins: style.side
        anchors.bottomMargin: bottomBar.height + style.side
        LayoutMirroring.enabled: false
        LayoutMirroring.childrenInherit: true

        // List column
        ColumnLayout {
            id: listCol
            width: style.view === "all" ? body.width : style.listW
            height: body.height
            x: style.listLeft || style.view === "all" ? 0 : body.width - width
            spacing: m.px(10)

            Avatar {
                visible: style.greeting
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: m.px(64)
                Layout.preferredHeight: m.px(64)
                metrics: m
                user: places.user
                TapHandler { onTapped: places.showUserMenu(parent) }
            }
            SectionTitle {
                visible: style.greeting
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                font.pixelSize: Math.round(m.headerFontSize * 1.4)
                readonly property int hour: { root.menuOpen; return new Date().getHours(); }
                readonly property string name: places.user.fullName || places.user.loginName
                text: hour < 12 ? i18n("Good morning, %1!", name) : hour < 18 ? i18n("Good afternoon, %1!", name)
                                                                              : i18n("Good evening, %1!", name)
            }
            RowLayout {
                visible: !style.greeting || style.view === "all"
                Layout.fillWidth: true
                Layout.leftMargin: m.px(8)
                SectionTitle { text: i18n("All apps"); Layout.fillWidth: true }
                SmallButton {
                    visible: style.view === "all"
                    metrics: m
                    text: i18n("Back")
                    iconName: "go-previous"
                    iconFirst: true
                    onClicked: style.view = "home"
                }
            }
            SearchBox {
                id: searchField
                focus: true
                Layout.fillWidth: true
                Layout.preferredHeight: m.px(34)
                metrics: m
                results: search
                nav: nav
                onCancel: style.view !== "home" ? style.view = "home" : root.close()
            }
            AppList {
                id: appList
                visible: !root.searching
                Layout.fillWidth: true
                Layout.fillHeight: true
                metrics: m
                contextMenu: contextMenu
                ghost: ghost
                mostUsed: true
                chipHeaders: true
            }
            SearchView {
                id: search
                showField: false
                visible: root.searching
                Layout.fillWidth: true
                Layout.fillHeight: true
                metrics: m
                contextMenu: contextMenu
            }
        }

        SplitHandle {
            name: "win12"
            value: style.listW
            reversed: !style.listLeft
            shown: style.view !== "all"
            minimum: m.px(200)
            maximum: body.width - style.cardsW
            x: (style.listLeft ? listCol.width + style.side / 2 : body.width - listCol.width - style.side / 2) - width / 2
            anchors.top: parent.top
            anchors.bottom: parent.bottom
        }

        // Cards column
        ColumnLayout {
            id: cardsCol
            visible: style.view !== "all"
            width: body.width - style.listW - style.side
            height: body.height
            x: style.listLeft ? style.listW + style.side : 0
            spacing: m.px(12)

            // Folder chips + clock (the 20.png header; list-left layout only)
            RowLayout {
                id: header
                visible: style.listLeft && (style.cfg.win12Chips || style.cfg.win12Clock) && style.view === "home"
                Layout.fillWidth: true
                spacing: m.px(12)
                Card {
                    visible: style.cfg.win12Chips
                    Layout.preferredWidth: chips.implicitWidth + m.px(16)
                    Layout.preferredHeight: chips.implicitHeight + m.px(16)
                    Row {
                        id: chips
                        anchors.centerIn: parent
                        Repeater {
                            model: ["documents", "pictures", "music"]
                            delegate: PC3.AbstractButton {
                                id: chip
                                required property string modelData
                                readonly property var info: places.info(modelData)
                                readonly property bool kbNav: true
                                width: m.px(76)
                                height: m.px(60)
                                hoverEnabled: true
                                onClicked: places.activate(modelData, chip)
                                KeyFrame {}
                                background: Rectangle {
                                    radius: m.px(8)
                                    color: m.text
                                    opacity: chip.pressed ? 0.12 : (chip.hovered || root.kbCurrent === chip ? 0.07 : 0)
                                }
                                contentItem: Column {
                                    spacing: m.px(4)
                                    Kirigami.Icon {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: m.px(28)
                                        height: width
                                        source: chip.info.icon.replace("-symbolic", "")
                                    }
                                    PC3.Label {
                                        width: parent.width
                                        horizontalAlignment: Text.AlignHCenter
                                        elide: Text.ElideRight
                                        text: chip.info.text
                                        color: m.text
                                        font.family: m.font
                                        font.pixelSize: Math.round(m.fontSize * 0.85)
                                    }
                                }
                            }
                        }
                    }
                }
                Item { Layout.fillWidth: true }
                Column {
                    visible: style.cfg.win12Clock
                    Layout.alignment: Qt.AlignTop
                    property date now: new Date()
                    Timer {
                        interval: 10000
                        running: root.menuOpen
                        repeat: true
                        triggeredOnStart: true
                        onTriggered: parent.now = new Date()
                    }
                    PC3.Label {
                        anchors.right: parent.right
                        text: Qt.formatTime(parent.now, Qt.locale().timeFormat(Locale.ShortFormat))
                        color: m.text
                        font.family: m.headerFont
                        font.pixelSize: Math.round(m.headerFontSize * 1.6)
                    }
                    PC3.Label {
                        anchors.right: parent.right
                        text: Qt.formatDate(parent.now, "dddd, MMMM d")
                        color: m.text
                        font.family: m.font
                        font.pixelSize: Math.round(m.fontSize * 0.9)
                    }
                }
            }

            // Pinned card
            Card {
                visible: style.view === "home"
                Layout.fillWidth: true
                Layout.preferredHeight: pinnedCol.implicitHeight + m.px(24)
                ColumnLayout {
                    id: pinnedCol
                    anchors.fill: parent
                    anchors.margins: m.px(12)
                    spacing: m.px(8)
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: m.px(8)
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
                        fixedCols: Math.max(3, Math.min(style.cols, Math.floor((cardsCol.width - m.px(24)) / m.px(96))))
                    }
                }
            }

            // Recent card (Recommended); "More" shows the long list
            Card {
                visible: style.cfg.showRecommended || style.view === "more"
                Layout.fillWidth: true
                Layout.fillHeight: true
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: m.px(12)
                    spacing: m.px(8)
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: m.px(8)
                        SectionTitle { text: i18n("Recent"); Layout.fillWidth: true }
                        SmallButton {
                            metrics: m
                            text: style.view === "more" ? i18n("Back") : i18n("More")
                            iconName: style.view === "more" ? "go-previous" : "go-next"
                            iconFirst: style.view === "more"
                            onClicked: style.view = style.view === "more" ? "home" : "more"
                        }
                    }
                    Recommended {
                        id: recent
                        visible: style.view === "home"
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        fitToHeight: true
                        columns: style.listLeft ? 2 : 1
                        metrics: m
                        contextMenu: contextMenu
                    }
                    Flickable {
                        visible: style.view === "more"
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        contentHeight: moreList.implicitHeight
                        Recommended {
                            id: moreList
                            width: parent.width
                            columns: 2
                            metrics: m
                            contextMenu: contextMenu
                            maxItems: 40
                        }
                    }
                }
            }
            Item { Layout.fillHeight: true; visible: !style.cfg.showRecommended && style.view === "home" }
        }
    }

    // ---- Bottom bar: user left, shortcuts + power right ----
    Rectangle {
        id: bottomBar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: m.px(56)
        color: Qt.alpha("black", m.mode === 2 ? 0.04 : 0.18)
        radius: style.cfg.cornerRadius
        Rectangle {   // square off the top corners
            anchors.top: parent.top
            width: parent.width
            height: parent.radius
            color: parent.color
            visible: parent.radius > 0
        }

        PC3.AbstractButton {
            id: userButton
            readonly property bool kbNav: true
            anchors.left: parent.left
            anchors.leftMargin: m.px(24)
            anchors.verticalCenter: parent.verticalCenter
            height: m.px(40)
            hoverEnabled: true
            leftPadding: m.px(8)
            rightPadding: m.px(12)
            onClicked: places.showUserMenu(userButton)
            KeyFrame {}
            background: Rectangle {
                radius: m.px(4)
                color: m.text
                opacity: userButton.pressed ? 0.12 : (userButton.hovered || root.kbCurrent === userButton ? 0.07 : 0)
            }
            contentItem: Row {
                spacing: m.px(10)
                Avatar {
                    anchors.verticalCenter: parent.verticalCenter
                    width: m.px(28)
                    height: width
                    metrics: m
                    user: places.user
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
            anchors.rightMargin: m.px(24)
            anchors.verticalCenter: parent.verticalCenter
            spacing: m.px(4)
            Repeater {
                model: style.cfg.bottomItems.filter(id => places.info(id) !== undefined && !places.info(id).separator).concat(["power"])
                delegate: PC3.AbstractButton {
                    id: sc
                    required property string modelData
                    readonly property var info: places.info(modelData)
                    readonly property bool kbNav: true
                    width: m.px(40)
                    height: width
                    hoverEnabled: true
                    onClicked: places.activate(modelData, sc)
                    PC3.ToolTip.text: info.text
                    PC3.ToolTip.visible: hovered
                    PC3.ToolTip.delay: Kirigami.Units.toolTipDelay
                    KeyFrame {}
                    background: Rectangle {
                        radius: m.px(4)
                        color: m.text
                        opacity: sc.pressed ? 0.12 : (sc.hovered || root.kbCurrent === sc ? 0.07 : 0)
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
        panes: [appList, style.view === "more" ? moreList : cardsCol, bottomBar]
        main: panes[0]
    }

    Connections {
        target: root
        function onMenuOpenChanged() {
            if (root.menuOpen) {
                style.view = style.cfg.openAllApps ? "all" : "home";
                appList.reset();
                searchField.forceActiveFocus();
            }
        }
    }
}
