import QtQuick
import org.kde.plasma.components as PC3
import org.kde.kirigami as Kirigami

// Header button like "All apps >" / "< Back".
PC3.AbstractButton {
    id: sb
    required property QtObject metrics
    property string iconName
    property bool iconFirst: false
    hoverEnabled: true
    leftPadding: metrics.px(10)
    rightPadding: metrics.px(10)
    implicitHeight: metrics.px(26)
    background: Rectangle {
        radius: sb.metrics.px(4)
        color: sb.metrics.text
        opacity: sb.pressed ? 0.16 : (sb.hovered ? 0.12 : 0.07)
    }
    contentItem: Row {
        spacing: sb.metrics.px(6)
        layoutDirection: sb.iconFirst ? Qt.LeftToRight : Qt.RightToLeft
        Kirigami.Icon {
            anchors.verticalCenter: parent.verticalCenter
            width: sb.metrics.px(12)
            height: width
            source: sb.iconName
            color: sb.metrics.text
            isMask: true
        }
        PC3.Label {
            anchors.verticalCenter: parent.verticalCenter
            text: sb.text
            color: sb.metrics.text
            font.family: sb.metrics.font
            font.pixelSize: Math.round(sb.metrics.fontSize * 0.9)
        }
    }
}
