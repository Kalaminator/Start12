import QtQuick
import org.kde.kirigami as Kirigami

// Keyboard focus outline; put one inside every item with kbNav: true.
Rectangle {
    anchors.fill: parent
    visible: root.kbCurrent === parent && !root.searching
    color: "transparent"
    border.color: Kirigami.Theme.textColor
    border.width: 2
    z: 10
}
