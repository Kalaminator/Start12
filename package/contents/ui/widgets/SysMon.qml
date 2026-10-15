import QtQuick
import org.kde.plasma.plasma5support as P5Support

// CPU % and RAM % with small bars, read from /proc every 2 s while the menu is open.
Item {
    id: w
    required property QtObject metrics
    required property string size
    required property bool active

    property real cpu: 0
    property real ram: 0
    property var last: null   // [idle, total] of the previous /proc/stat read

    readonly property string cmd: "head -n1 /proc/stat; grep -E '^(MemTotal|MemAvailable):' /proc/meminfo"
    P5Support.DataSource {
        id: src
        engine: "executable"
        connectedSources: []
        onNewData: (name, data) => {
            disconnectSource(name);
            const lines = String(data.stdout).split("\n");
            const c = lines[0].trim().split(/\s+/).slice(1).map(Number);
            const total = c.reduce((a, b) => a + b, 0);
            const idle = c[3] + (c[4] || 0);
            if (w.last && total > w.last[1]) w.cpu = 1 - (idle - w.last[0]) / (total - w.last[1]);
            w.last = [idle, total];
            const kb = k => Number((lines.find(l => l.startsWith(k)) || "0 0").split(/\s+/)[1]);
            const t = kb("MemTotal");
            if (t > 0) w.ram = 1 - kb("MemAvailable") / t;
        }
    }
    Timer {
        interval: 2000; repeat: true; running: w.active; triggeredOnStart: true
        onTriggered: src.connectSource(w.cmd)
    }

    readonly property real u: Math.min(width, height)
    readonly property bool tiny: size === "small"

    component Meter: Item {
        id: m
        property string label
        property real value
        height: col.height
        Column {
            id: col
            width: parent.width
            spacing: w.metrics.px(2)
            Row {
                width: parent.width
                Text {
                    visible: !w.tiny
                    width: parent.width - pct.width
                    text: m.label
                    color: w.metrics.text
                    opacity: 0.8
                    font.family: w.metrics.font
                    font.pixelSize: Math.max(7, Math.round(w.u * 0.15))
                }
                Text {
                    id: pct
                    text: Math.round(m.value * 100) + "%"
                    color: w.metrics.text
                    font.family: w.metrics.font
                    font.bold: true
                    font.pixelSize: Math.max(7, Math.round(w.u * (w.tiny ? 0.3 : 0.17)))
                }
            }
            Rectangle {
                width: parent.width
                height: Math.max(2, w.metrics.px(w.tiny ? 3 : 5))
                radius: height / 2
                color: Qt.alpha(w.metrics.text, 0.2)
                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, m.value))
                    height: parent.height
                    radius: height / 2
                    color: w.metrics.accent
                    Behavior on width { NumberAnimation { duration: 300 } }
                }
            }
        }
    }

    Column {
        anchors.centerIn: parent
        width: parent.width - w.metrics.px(w.tiny ? 6 : 16)
        spacing: w.metrics.px(w.tiny ? 4 : 8)
        Meter { width: parent.width; label: i18n("CPU"); value: w.cpu }
        Meter { visible: !w.tiny; width: parent.width; label: i18n("RAM"); value: w.ram }
    }
}
