import QtQuick
import org.kde.kirigami as Kirigami

// Tiny drawing of each menu style for the style picker.
Rectangle {
    id: pv
    property string styleId
    readonly property color fg: Qt.alpha("white", 0.55)
    readonly property color dim: Qt.alpha("white", 0.18)
    color: "#1c1b22"
    radius: 4

    // Lines of an app list.
    component Lines: Column {
        property int count: 6
        spacing: 3
        Repeater {
            model: parent.count
            Rectangle { width: 30 + (index * 7) % 14; height: 3; radius: 1; color: pv.fg }
        }
    }
    // A block of squares (tiles or a pinned grid).
    component Squares: Grid {
        property int cols: 3
        property int count: 6
        property int side: 10
        spacing: 3
        columns: cols
        Repeater {
            model: parent.count
            Rectangle { width: parent.side; height: parent.side; radius: 1; color: pv.dim }
        }
    }

    // Windows 10: rail | list | tiles
    Item {
        anchors.fill: parent
        anchors.margins: 6
        visible: pv.styleId === "windows10"
        Column { spacing: 6; anchors.bottom: parent.bottom; Repeater { model: 5; Rectangle { width: 5; height: 5; color: pv.fg } } }
        Lines { x: 14; y: 2; count: 9 }
        Squares { x: 66; y: 2; cols: 4; count: 12 }
    }
    // Windows 7 / Modern: list | places, search at the bottom
    Item {
        anchors.fill: parent
        anchors.margins: 6
        visible: pv.styleId === "windows7" || pv.styleId === "modern" || pv.styleId === "xp"
        Lines { y: 2; count: 9 }
        Rectangle { x: parent.width * 0.6 - 4; width: 1; height: parent.height; color: pv.dim }
        Lines { x: parent.width * 0.6 + 4; y: 2; count: 7 }
        Rectangle { y: parent.height - 8; width: parent.width * 0.55; height: 7; radius: 3; color: pv.dim }
    }
    // Windows 11: search, pinned grid, recommended
    Item {
        anchors.fill: parent
        anchors.margins: 6
        visible: pv.styleId === "windows11"
        Rectangle { width: parent.width; height: 7; radius: 3; color: pv.dim }
        Squares { anchors.horizontalCenter: parent.horizontalCenter; y: 13; cols: 6; count: 12; side: 9 }
        Lines { y: 42; count: 3 }
        Lines { x: parent.width / 2; y: 42; count: 3 }
    }
    // App: top bar, groups on the left, all apps list on the right
    Item {
        anchors.fill: parent
        anchors.margins: 6
        visible: pv.styleId === "app"
        Rectangle { width: parent.width; height: 8; radius: 2; color: pv.dim }
        Rectangle { y: 12; width: parent.width * 0.48; height: 22; radius: 2; color: pv.dim }
        Rectangle { y: 38; width: parent.width * 0.48; height: 22; radius: 2; color: pv.dim }
        Lines { x: parent.width * 0.55; y: 13; count: 8 }
    }
    // Pro: search + pinned on the left, darker places panel on the right
    Item {
        anchors.fill: parent
        anchors.margins: 6
        visible: pv.styleId === "pro"
        Rectangle { width: parent.width * 0.6; height: 7; radius: 3; color: pv.dim }
        Squares { y: 13; cols: 3; count: 9; side: 12 }
        Rectangle { anchors.right: parent.right; width: parent.width * 0.35; height: parent.height; radius: 2; color: pv.dim }
        Lines { x: parent.width * 0.7; y: 16; count: 6 }
    }
    // Launcher: big picture, search, large pinned grid
    Item {
        anchors.fill: parent
        anchors.margins: 6
        visible: pv.styleId === "launcher"
        Rectangle { anchors.horizontalCenter: parent.horizontalCenter; width: 12; height: 12; radius: 6; color: pv.fg }
        Rectangle { y: 16; width: parent.width; height: 6; radius: 3; color: pv.dim }
        Squares { anchors.horizontalCenter: parent.horizontalCenter; y: 27; cols: 6; count: 18; side: 9 }
    }
}
