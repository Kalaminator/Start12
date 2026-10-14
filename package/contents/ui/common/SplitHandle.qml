import QtQuick
import org.kde.kirigami as Kirigami

// Divider grip for design mode (T40). Normal mode: nothing (the style draws its own divider, if any).
// Design mode: a grip bar; dragging changes the width `value` of the section the style sizes, saved
// as root.setSplit(name). `reversed`: that section is right of the divider (dragging right shrinks it).
// Place it centred on the divider: x = dividerX - width / 2, top/bottom like the sections.
Item {
    id: h
    required property string name
    required property real value
    property real minimum: 120
    property real maximum: 800
    property bool reversed: false
    property bool shown: true

    visible: shown && root.designMode && !root.searching
    width: Kirigami.Units.gridUnit
    z: 50

    Rectangle {
        anchors.centerIn: parent
        width: Math.round(Kirigami.Units.smallSpacing * 1.5)
        height: Math.min(parent.height, Kirigami.Units.gridUnit * 6)
        radius: width / 2
        color: Kirigami.Theme.highlightColor
        opacity: drag.pressed || drag.containsMouse ? 1 : 0.7
    }
    MouseArea {
        id: drag
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.SplitHCursor
        property real pressX: 0
        onPressed: mouse => pressX = mouse.x
        // The handle follows the divider, so each move adds the offset from the press point.
        onPositionChanged: mouse => {
            if (!pressed) return;
            const dx = mouse.x - pressX;
            const w = Math.max(h.minimum, Math.min(h.maximum, h.value + (h.reversed ? -dx : dx)));
            if (Math.round(w) !== Math.round(h.value)) root.setSplit(h.name, w);
        }
    }
}
