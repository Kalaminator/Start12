import QtQuick
import QtQuick.Layouts

// Digital clock: time big, date under (not on small). Follows the locale's 12/24 h setting.
Item {
    id: w
    required property QtObject metrics
    required property string size
    required property bool active

    property date now: new Date()
    Timer { interval: 1000; repeat: true; running: w.active; triggeredOnStart: true; onTriggered: w.now = new Date() }

    readonly property bool tiny: size === "small"
    readonly property real u: Math.min(width, height)
    readonly property bool wideShape: width > height * 1.5
    Column {
        anchors.centerIn: parent
        width: parent.width - w.metrics.px(8)
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: w.now.toLocaleTimeString(Qt.locale(), Locale.ShortFormat).replace(/\s?(AM|PM)/i, m => w.tiny ? "" : m)
            color: w.metrics.text
            font.family: w.metrics.font
            font.pixelSize: Math.max(8, Math.round(w.tiny ? w.u * 0.34 : Math.min(w.u * 0.3, w.width * 0.2)))
            fontSizeMode: Text.Fit
            minimumPixelSize: 6
            elide: Text.ElideNone
        }
        Text {
            visible: !w.tiny
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: w.now.toLocaleDateString(Qt.locale(), w.wideShape || w.size.startsWith("huge") ? Locale.LongFormat : "ddd d MMM")
            color: w.metrics.text
            opacity: 0.8
            font.family: w.metrics.font
            font.pixelSize: Math.max(8, Math.round(w.u * 0.11))
            fontSizeMode: Text.Fit
            minimumPixelSize: 6
            elide: Text.ElideRight
        }
    }
}
