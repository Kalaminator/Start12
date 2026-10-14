import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami

// The start button in the panel. Start11 button images hold 3 frames stacked
// top to bottom: normal, hover, pressed.
MouseArea {
    id: button

    readonly property var cfg: Plasmoid.configuration
    readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
    readonly property int frame: pressed || root.expanded ? 2 : (containsMouse ? 1 : 0)
    readonly property string imageSource: cfg.buttonImage.startsWith("/")
        ? "file://" + cfg.buttonImage
        : Qt.resolvedUrl("../images/StartButtons/" + cfg.buttonImage)

    readonly property real side: vertical ? width : height
    // XP style in a horizontal panel: the green "start" pill replaces the normal button.
    readonly property bool xp: cfg.menuStyle === "xp" && !vertical
    readonly property string iconSource: cfg.buttonIcon === "" ? Qt.resolvedUrl("../images/StartIcon.svg")
              : cfg.buttonIcon.startsWith("/") ? "file://" + cfg.buttonIcon : cfg.buttonIcon
    Layout.preferredWidth: vertical ? -1 : xp ? xpPill.implicitWidth : (cfg.buttonMode === 0 && sheet.status === Image.Ready
        ? Math.round(side * sheet.sourceSize.width / (sheet.sourceSize.height / 3)) : side)
    Layout.preferredHeight: vertical ? width : -1
    Layout.minimumWidth: Layout.preferredWidth
    Layout.minimumHeight: Layout.preferredHeight

    hoverEnabled: true
    property bool wasExpanded
    onPressed: wasExpanded = root.expanded
    onClicked: root.expanded = !wasExpanded

    Accessible.name: Plasmoid.title
    Accessible.role: Accessible.Button

    // Mode 0: Start11 image sheet.
    Item {
        anchors.fill: parent
        clip: true
        visible: !button.xp && button.cfg.buttonMode === 0
        Image {
            id: sheet
            source: button.imageSource
            width: parent.width
            height: parent.height * 3
            y: -button.frame * parent.height
            fillMode: Image.Stretch
            smooth: true
            mipmap: true
        }
    }

    // Mode 1: four squares, top left one in the accent colour.
    Item {
        id: squares
        visible: !button.xp && button.cfg.buttonMode === 1
        anchors.centerIn: parent
        readonly property real size: Math.round(button.side * 0.42)
        width: size
        height: size
        scale: button.pressed ? 0.88 : 1
        Behavior on scale { NumberAnimation { duration: 90 } }
        Grid {
            columns: 2
            spacing: Math.max(1, Math.round(squares.size * 0.08))
            Repeater {
                model: 4
                Rectangle {
                    required property int index
                    width: (squares.size - parent.spacing) / 2
                    height: width
                    color: index === 0 ? button.cfg.squaresAccent : button.cfg.squaresColor
                }
            }
        }
    }
    Rectangle {
        anchors.fill: parent
        visible: !button.xp && button.cfg.buttonMode !== 0
        radius: 4
        color: Kirigami.Theme.textColor
        opacity: button.containsMouse || root.expanded ? 0.1 : 0
    }

    // Mode 2: any icon.
    Kirigami.Icon {
        visible: !button.xp && button.cfg.buttonMode === 2
        anchors.fill: parent
        anchors.margins: Math.round(button.side * (1 - button.cfg.buttonIconScale / 100) / 2)
        source: button.iconSource
        active: button.containsMouse
    }

    // XP: green pill (classic: square left, round right; modern: fully round, glow on hover).
    // Key xpStartGreen keeps it green in every scheme like XP; off = scheme colour.
    Item {
        id: xpPill
        visible: button.xp
        anchors.fill: parent
        readonly property bool modern: button.cfg.xpSubstyle === "modern"
        readonly property var schemeBase: ({ blue: "#2f6fd8", olive: "#7a924f", silver: "#9a9ab4" })
        readonly property color base: button.cfg.xpStartGreen ? "#3c9a3c"
            : button.cfg.xpColor === "custom" ? button.cfg.xpCustomColor
            : (schemeBase[button.cfg.xpColor] || schemeBase.blue)
        readonly property color tone: button.frame === 2 ? Qt.darker(base, 1.25)
                                    : button.frame === 1 ? Qt.lighter(base, 1.12) : base
        readonly property real r: modern ? height / 2 : height * 0.45
        implicitWidth: xpRow.implicitWidth + Math.round(height * (modern ? 0.7 : 0.75))

        // Soft shadow on the right edge.
        Rectangle {
            anchors.fill: shape
            anchors.leftMargin: 2
            anchors.rightMargin: -2
            radius: xpPill.r
            topLeftRadius: xpPill.modern ? xpPill.r : 0
            bottomLeftRadius: topLeftRadius
            color: "#000000"
            opacity: xpPill.modern ? 0.18 : 0.35
        }
        // Modern hover glow.
        Rectangle {
            visible: xpPill.modern
            anchors.fill: shape
            anchors.margins: -2
            radius: xpPill.r + 2
            color: "transparent"
            border.width: 2
            border.color: Qt.lighter(xpPill.base, 1.7)
            opacity: button.containsMouse ? 0.6 : 0
            Behavior on opacity { NumberAnimation { duration: 120 } }
        }
        Rectangle {
            id: shape
            anchors.fill: parent
            anchors.rightMargin: 2
            anchors.topMargin: xpPill.modern ? 2 : 0
            anchors.bottomMargin: anchors.topMargin
            radius: xpPill.r
            topLeftRadius: xpPill.modern ? xpPill.r : 0
            bottomLeftRadius: topLeftRadius
            border.width: 1
            border.color: Qt.darker(xpPill.tone, xpPill.modern ? 1.25 : 1.5)
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.lighter(xpPill.tone, xpPill.modern ? 1.2 : 1.4) }
                GradientStop { position: xpPill.modern ? 0.4 : 0.15; color: Qt.lighter(xpPill.tone, xpPill.modern ? 1.05 : 1.1) }
                GradientStop { position: 0.6; color: xpPill.tone }
                GradientStop { position: 1; color: Qt.darker(xpPill.tone, xpPill.modern ? 1.15 : 1.4) }
            }
        }
        Row {
            id: xpRow
            anchors.verticalCenter: shape.verticalCenter
            x: Math.round(xpPill.height * (xpPill.modern ? 0.3 : 0.2))
            spacing: Math.round(xpPill.height * 0.12)
            Kirigami.Icon {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.round(xpPill.height * 0.6)
                height: width
                source: button.iconSource
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: i18n("start")
                color: "#ffffff"
                font.bold: true
                font.italic: true
                font.pixelSize: Math.round(xpPill.height * 0.5)
                style: Text.Raised
                styleColor: "#80000000"
            }
        }
    }
}
