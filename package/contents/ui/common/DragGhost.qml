import QtQuick
import org.kde.kirigami as Kirigami

// Icon that follows the mouse while a pinned app or list row is dragged.
Item {
    id: ghost
    required property QtObject metrics
    property string favoriteId: ""
    property var icon: null
    width: metrics.px(48)
    height: width
    z: 100
    visible: Drag.active
    Drag.keys: ["start12-tile"]
    Drag.hotSpot.x: width / 2
    Drag.hotSpot.y: height / 2
    Kirigami.Icon {
        anchors.centerIn: parent
        width: ghost.metrics.px(32)
        height: width
        source: ghost.icon
    }
}
