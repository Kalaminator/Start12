pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PC3
import "../win10"

// "Pinned  [All apps >]" + pinned grid sized to fit; "All apps" swaps in the A-Z list;
// search results while typing (the style owns the search box). Used by Launcher and Pro.
Item {
    id: pane

    required property QtObject metrics
    required property var contextMenu
    required property Item ghost
    readonly property QtObject m: metrics
    readonly property var cfg: Plasmoid.configuration
    property string view: "home"    // home | all
    property int maxCols: 6
    readonly property alias search: search
    readonly property Item kbPane: view === "all" ? appList : grid   // for KeyNav

    function reset() {
        view = cfg.openAllApps ? "all" : "home";
        appList.reset();
    }

    component SectionTitle: PC3.Label {
        color: pane.m.text
        font.family: pane.m.font
        font.weight: Font.DemiBold
        font.pixelSize: Math.round(pane.m.fontSize * 1.05)
    }

    Item {
        anchors.fill: parent
        visible: pane.view === "home" && !root.searching
        RowLayout {
            id: homeHeader
            width: parent.width
            SectionTitle { text: i18n("Pinned"); Layout.fillWidth: true; Layout.leftMargin: pane.m.px(8) }
            SmallButton { metrics: pane.m; text: i18n("All apps"); iconName: "go-next"; onClicked: pane.view = "all" }
        }
        PinnedGrid {
            id: grid
            anchors.top: homeHeader.bottom
            anchors.topMargin: pane.m.px(8)
            anchors.horizontalCenter: parent.horizontalCenter
            width: implicitWidth
            height: implicitHeight
            metrics: pane.m
            contextMenu: pane.contextMenu
            ghost: pane.ghost
            // room for the page dots on the right
            fixedCols: Math.max(2, Math.min(pane.maxCols, Math.floor((pane.width - pane.m.px(16)) / cellW)))
            fixedRows: Math.max(1, Math.floor((pane.height - homeHeader.height - pane.m.px(8)) / cellH))
        }
    }

    Item {
        anchors.fill: parent
        visible: pane.view === "all" && !root.searching
        RowLayout {
            id: allHeader
            width: parent.width
            SectionTitle { text: i18n("All apps"); Layout.fillWidth: true; Layout.leftMargin: pane.m.px(8) }
            SmallButton { metrics: pane.m; text: i18n("Back"); iconName: "go-previous"; iconFirst: true; onClicked: pane.view = "home" }
        }
        AppList {
            id: appList
            anchors.top: allHeader.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            metrics: pane.m
            contextMenu: pane.contextMenu
            ghost: pane.ghost
        }
    }

    SearchView {
        id: search
        anchors.fill: parent
        visible: root.searching
        showField: false
        metrics: pane.m
        contextMenu: pane.contextMenu
    }
}
