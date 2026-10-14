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
    Layout.preferredWidth: vertical ? -1 : (cfg.buttonMode === 0 && sheet.status === Image.Ready
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
        visible: button.cfg.buttonMode === 0
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
        visible: button.cfg.buttonMode === 1
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
        visible: button.cfg.buttonMode !== 0
        radius: 4
        color: Kirigami.Theme.textColor
        opacity: button.containsMouse || root.expanded ? 0.1 : 0
    }

    // Mode 2: any icon.
    Kirigami.Icon {
        visible: button.cfg.buttonMode === 2
        anchors.fill: parent
        anchors.margins: Math.round(button.side * (1 - button.cfg.buttonIconScale / 100) / 2)
        source: button.cfg.buttonIcon === "" ? Qt.resolvedUrl("../images/StartIcon.svg")
              : button.cfg.buttonIcon.startsWith("/") ? "file://" + button.cfg.buttonIcon
              : button.cfg.buttonIcon
        active: button.containsMouse
    }
}
