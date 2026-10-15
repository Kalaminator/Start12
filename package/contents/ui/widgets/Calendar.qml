import QtQuick

// Calendar: month grid on big sizes (today in the accent colour); day number + weekday on small/medium/wide.
Item {
    id: w
    required property QtObject metrics
    required property string size
    required property bool active

    property date now: new Date()
    // Re-read the date every minute while the menu is open (midnight rollover).
    Timer { interval: 60000; repeat: true; running: w.active; triggeredOnStart: true; onTriggered: w.now = new Date() }

    readonly property bool grid: ["large", "wideLargeH", "wideLargeV", "hugeH", "hugeV"].includes(size)
    readonly property real u: Math.min(width, height)
    readonly property var loc: Qt.locale()
    readonly property int first: loc.firstDayOfWeek % 7                 // 0 = Sunday
    readonly property int lead: (new Date(now.getFullYear(), now.getMonth(), 1).getDay() - first + 7) % 7
    readonly property int days: new Date(now.getFullYear(), now.getMonth() + 1, 0).getDate()

    // Simple view
    Column {
        visible: !w.grid
        anchors.centerIn: parent
        width: parent.width - w.metrics.px(8)
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: w.now.getDate()
            color: w.metrics.accent
            font.family: w.metrics.font
            font.bold: true
            font.pixelSize: Math.round(w.u * (w.size === "small" ? 0.6 : 0.42))
        }
        Text {
            visible: w.size !== "small"
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: w.loc.dayName(w.now.getDay(), Locale.LongFormat)
            color: w.metrics.text
            font.family: w.metrics.font
            font.pixelSize: Math.round(w.u * 0.13)
            fontSizeMode: Text.Fit
            minimumPixelSize: 6
            elide: Text.ElideRight
        }
    }

    // Month grid
    Column {
        visible: w.grid
        anchors.fill: parent
        anchors.margins: w.metrics.px(8)
        spacing: w.metrics.px(2)
        Text {
            width: parent.width
            text: w.now.toLocaleDateString(w.loc, "MMMM yyyy")
            color: w.metrics.text
            font.family: w.metrics.font
            font.bold: true
            font.capitalization: Font.Capitalize
            font.pixelSize: Math.max(8, Math.round(w.u * 0.075))
            elide: Text.ElideRight
        }
        Grid {
            id: g
            columns: 7
            width: parent.width
            readonly property real cw: width / 7
            readonly property real ch: Math.max(1, (parent.height - w.metrics.px(10) - w.u * 0.09) / 7)
            Repeater {
                model: 49
                delegate: Item {
                    id: cell
                    required property int index
                    readonly property int row: Math.floor(index / 7)
                    readonly property int day: row === 0 ? 0 : index - 7 - w.lead + 1
                    readonly property bool today: row > 0 && day === w.now.getDate()
                    width: g.cw
                    height: g.ch
                    Rectangle {
                        visible: cell.today
                        anchors.centerIn: parent
                        width: Math.min(parent.width, parent.height)
                        height: width
                        radius: width / 2
                        color: w.metrics.accent
                    }
                    Text {
                        anchors.centerIn: parent
                        text: cell.row === 0 ? w.loc.dayName((w.first + cell.index) % 7, Locale.NarrowFormat)
                            : cell.day >= 1 && cell.day <= w.days ? cell.day : ""
                        color: cell.today ? "#ffffff" : w.metrics.text
                        opacity: cell.row === 0 ? 0.6 : 1
                        font.family: w.metrics.font
                        font.pixelSize: Math.max(7, Math.min(Math.round(w.u * 0.07), cell.height * 0.7))
                    }
                }
            }
        }
    }
}
