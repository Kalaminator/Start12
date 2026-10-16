pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PC3
import org.kde.kirigami as Kirigami
import ".."
import "../common"
import "../win10"

// "KDE Plasma" card: a Kickoff-like menu in Plasma's own colours (the popup's standard background, no
// MenuBackground). Header: avatar, name, search. Left: Favorites / All Applications / categories; right:
// pinned grid, A-Z list or the category's apps. Footer: Applications / Places tabs and power buttons.
// ponytail: category and place rows have no context menu or drag; add when users ask.
FocusScope {
    id: style
    focus: true

    readonly property var cfg: Plasmoid.configuration

    Metrics {
        id: m
        mode: 0             // always the Plasma colour scheme
        accentStart: false
    }
    readonly property alias metrics: m

    implicitWidth: m.px(660)
    implicitHeight: m.heightFor([540, 640, 540, 700])

    property string tab: "apps"         // apps | places
    property string section: "favorites"  // favorites | all | <rootModel row of a category>
    property var categories: []         // [{ row, name, icon }]

    function rebuild() {
        const rm = root.rootModel, out = [];
        for (let r = 2; r < rm.count; r++) {
            if (!rm.modelForRow(r)) continue;
            const i = rm.index(r, 0);
            out.push({ row: String(r), name: rm.data(i, Qt.DisplayRole), icon: rm.data(i, Qt.DecorationRole) });
        }
        categories = out;
    }
    readonly property var sideItems: [{ row: "favorites", name: i18n("Favorites"), icon: "bookmarks" },
                                      { row: "all", name: i18n("All Applications"), icon: "applications-all" }].concat(categories)

    Places {
        id: places
        contextMenu: contextMenu
    }

    // One clickable row (sidebar, category apps, places).
    component SideRow: PC3.ItemDelegate {
        id: row
        property bool kbNav: true
        property bool current: false
        property var iconSource
        function kbActivate() { clicked(); }
        width: ListView.view ? ListView.view.width : implicitWidth
        height: m.px(34)
        highlighted: current || root.kbCurrent === row
        contentItem: RowLayout {
            spacing: m.px(8)
            Kirigami.Icon { source: row.iconSource; Layout.preferredWidth: m.px(22); Layout.preferredHeight: m.px(22) }
            PC3.Label { text: row.text; color: m.text; elide: Text.ElideRight; Layout.fillWidth: true }
        }
    }

    // ---- Header ----
    RowLayout {
        id: header
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: m.px(10)
        spacing: m.px(10)
        Avatar {
            id: avatar
            Layout.preferredWidth: m.px(36)
            Layout.preferredHeight: m.px(36)
            metrics: m
            user: places.user
            TapHandler { onTapped: places.showUserMenu(avatar) }
        }
        PC3.Label {
            text: places.user.fullName || places.user.loginName
            color: m.text
            font.weight: Font.DemiBold
        }
        SearchBox {
            id: searchField
            focus: true
            Layout.fillWidth: true
            Layout.preferredHeight: m.px(32)
            metrics: m
            results: search
            nav: nav
            onCancel: root.close()
        }
    }
    Kirigami.Separator {
        id: topLine
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: header.bottom
        anchors.topMargin: m.px(10)
    }

    // ---- Body ----
    Item {
        id: body
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: topLine.bottom
        anchors.bottom: bottomLine.top
        anchors.margins: m.px(6)

        ListView {
            id: side
            visible: style.tab === "apps" && !root.searching
            width: m.px(200)
            height: parent.height
            clip: true
            model: style.sideItems
            delegate: SideRow {
                required property var modelData
                text: modelData.name
                iconSource: modelData.icon
                current: style.section === modelData.row
                onClicked: style.section = modelData.row
            }
        }
        Kirigami.Separator {
            id: sideLine
            visible: side.visible
            anchors.left: side.right
            height: parent.height
        }
        Item {
            id: content
            visible: side.visible
            anchors.left: sideLine.right
            anchors.leftMargin: m.px(6)
            anchors.right: parent.right
            height: parent.height
            readonly property Item kbPane: style.section === "favorites" ? grid : style.section === "all" ? appList : catList

            PinnedGrid {
                id: grid
                visible: style.section === "favorites"
                width: implicitWidth
                height: implicitHeight
                metrics: m
                contextMenu: contextMenu
                ghost: ghost
                fixedCols: Math.max(2, Math.floor((content.width - m.px(16)) / cellW))
                fixedRows: Math.max(1, Math.floor(content.height / cellH))
            }
            AppList {
                id: appList
                visible: style.section === "all"
                anchors.fill: parent
                metrics: m
                contextMenu: contextMenu
                ghost: ghost
            }
            ListView {
                id: catList
                visible: style.section !== "favorites" && style.section !== "all"
                anchors.fill: parent
                clip: true
                model: visible ? root.rootModel.modelForRow(Number(style.section)) : null
                delegate: SideRow {
                    required property int index
                    required property var model
                    text: model.display
                    iconSource: model.decoration
                    onClicked: { catList.model.trigger(index, "", null); root.close(); }
                }
            }
        }

        ListView {
            id: placeList
            visible: style.tab === "places" && !root.searching
            anchors.fill: parent
            clip: true
            model: ["home", "documents", "downloads", "pictures", "music", "videos", "recent", "network", "computer", "trash"]
            delegate: SideRow {
                id: placeRow
                required property string modelData
                text: places.info(modelData).text
                iconSource: places.info(modelData).icon
                onClicked: places.activate(modelData, placeRow)
            }
        }

        SearchView {
            id: search
            anchors.fill: parent
            visible: root.searching
            showField: false
            metrics: m
            contextMenu: contextMenu
        }
    }

    // ---- Footer ----
    Kirigami.Separator {
        id: bottomLine
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: footer.top
    }
    RowLayout {
        id: footer
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: m.px(6)
        PC3.TabBar {
            id: tabs
            Layout.preferredWidth: m.px(260)
            currentIndex: style.tab === "places" ? 1 : 0
            PC3.TabButton { text: i18n("Applications"); icon.name: "applications-all-symbolic"; onClicked: style.tab = "apps" }
            PC3.TabButton { text: i18n("Places"); icon.name: "compass"; onClicked: style.tab = "places" }
        }
        Item { Layout.fillWidth: true }
        Repeater {
            model: places.powerItems(["lock-screen", "logout", "suspend", "reboot", "shutdown"])
            PC3.ToolButton {
                required property var modelData
                icon.name: modelData.icon
                onClicked: modelData.run()
                PC3.ToolTip.text: modelData.text
                PC3.ToolTip.visible: hovered
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
        panes: style.tab === "places" ? [placeList] : [side, content]
        main: style.tab === "places" ? placeList : content
    }

    Connections {
        target: root
        function onMenuOpenChanged() {
            if (root.menuOpen) {
                style.tab = "apps";
                style.section = style.cfg.openAllApps ? "all" : "favorites";
                style.rebuild();
                appList.reset();
                searchField.forceActiveFocus();
            }
        }
    }
    Component.onCompleted: rebuild()
}
