import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import "common"

// The start button in the panel. Start11 button images hold 3 frames stacked
// top to bottom: normal, hover, pressed.
MouseArea {
    id: button

    readonly property var cfg: Plasmoid.configuration
    readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
    readonly property int frame: pressed || root.expanded ? 2 : (onFace ? 1 : 0)
    readonly property string imageSource: cfg.buttonImage.startsWith("/")
        ? "file://" + cfg.buttonImage
        : Qt.resolvedUrl("../images/StartButtons/" + cfg.buttonImage)

    readonly property real side: vertical ? width : height
    // XP style in a horizontal panel: the green "start" pill replaces the normal button.
    readonly property bool xp: cfg.menuStyle === "xp" && !vertical
    readonly property string iconSource: cfg.buttonIcon === "" ? "start-here-kde"
              : cfg.buttonIcon.startsWith("/") ? "file://" + cfg.buttonIcon : cfg.buttonIcon
    readonly property real buttonWidth: xp ? xpPill.implicitWidth : (cfg.buttonMode === 0 && sheet.status === Image.Ready
        ? Math.round(side * sheet.sourceSize.width / (sheet.sourceSize.height / 3)) : side)
    // Start11 "Show search on taskbar" (T30): a field right of the button, horizontal panels only.
    readonly property bool showSearch: cfg.taskbarSearch && !vertical
    Layout.preferredWidth: vertical ? -1 : buttonWidth + (showSearch ? cfg.taskbarSearchWidth + 4 : 0)
    Layout.preferredHeight: vertical ? width : -1
    Layout.minimumWidth: Layout.preferredWidth
    Layout.minimumHeight: Layout.preferredHeight

    hoverEnabled: true
    readonly property bool onFace: containsMouse && (vertical || mouseX < buttonWidth)
    property bool wasExpanded
    onPressed: wasExpanded = root.expanded
    onClicked: mouse => { if (vertical || mouse.x < buttonWidth) root.expanded = !wasExpanded; }

    // The button's own area; the search field sits to its right.
    Item {
        id: face
        width: button.vertical ? parent.width : button.buttonWidth
        height: parent.height
    }

    // Typing opens the menu on the search results (SearchView); the menu's own search box then
    // carries on (both show root.searchText). Esc or closing the menu empties it.
    Metrics { id: m }
    QQC2.TextField {
        id: field
        visible: button.showSearch
        x: button.buttonWidth + 4
        width: button.cfg.taskbarSearchWidth
        height: Math.min(parent.height - 4, m.px(32))
        anchors.verticalCenter: parent.verticalCenter
        text: root.searchText
        placeholderText: i18n("Type here to search")
        color: m.text
        placeholderTextColor: Qt.rgba(m.text.r, m.text.g, m.text.b, 0.6)
        font.family: m.font
        font.pixelSize: m.fontSize
        leftPadding: height
        verticalAlignment: TextInput.AlignVCenter
        background: Rectangle {
            color: Qt.rgba(m.bg.r, m.bg.g, m.bg.b, m.bgAlpha)
            border.width: 1
            border.color: field.activeFocus ? m.accent : Qt.rgba(m.text.r, m.text.g, m.text.b, 0.25)
            radius: 3
        }
        Kirigami.Icon {
            anchors.left: parent.left
            anchors.leftMargin: Math.round((parent.height - height) / 2)
            anchors.verticalCenter: parent.verticalCenter
            width: Math.round(parent.height * 0.5)
            height: width
            source: "search"
            color: m.text
            isMask: true
        }
        // A panel only takes keyboard focus while an applet asks for input.
        property int oldStatus: PlasmaCore.Types.ActiveStatus
        onPressed: {
            if (Plasmoid.status !== PlasmaCore.Types.AcceptingInputStatus) oldStatus = Plasmoid.status;
            Plasmoid.status = PlasmaCore.Types.AcceptingInputStatus;
            forceActiveFocus();
        }
        onActiveFocusChanged: if (!activeFocus) Plasmoid.status = oldStatus
        onTextEdited: {
            root.searchText = text;
            if (text !== "") root.expanded = true;
        }
        Keys.onReturnPressed: root.expanded = true
        Keys.onEnterPressed: root.expanded = true
        Keys.onEscapePressed: {
            root.searchText = "";
            root.expanded = false;
        }
    }

    // Plasma draws an "expanded" mark (widgets/tabbar active-tab) under the button while the menu is open;
    // XP's button has none (it peeked out at the pill's round corner as a yellow line).
    readonly property Item expandedMark: {
        for (let p = parent; p; p = p.parent)
            if (p.expandedFeedback !== undefined) return p.expandedFeedback;
        return null;
    }
    Binding {
        when: button.xp && button.expandedMark !== null
        target: button.expandedMark
        property: "visible"
        value: false
    }

    // T42 Menu position Center/Right: the popup's visualParent (main.qml full.place() moves and sizes it).
    readonly property Item popupAnchor: popupAnchorItem
    Item { id: popupAnchorItem; height: button.height }

    Accessible.name: Plasmoid.title
    Accessible.role: Accessible.Button

    // Mode 0: Start11 image sheet.
    Item {
        anchors.fill: face
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
        anchors.centerIn: face
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
        anchors.fill: face
        visible: !button.xp && button.cfg.buttonMode !== 0
        radius: 4
        color: Kirigami.Theme.textColor
        opacity: button.onFace || root.expanded ? 0.1 : 0
    }

    // Mode 2: any icon. Pressing squeezes it a little, like the Windows 11 Start button.
    Kirigami.Icon {
        visible: !button.xp && button.cfg.buttonMode === 2
        anchors.fill: face
        anchors.margins: Math.round(button.side * (1 - button.cfg.buttonIconScale / 100) / 2)
        source: button.iconSource
        active: button.onFace
        scale: button.pressed && button.onFace ? 0.82 : 1
        Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutQuad } }
    }

    // XP: green pill (classic: square left, round right; modern: fully round, glow on hover).
    // Colour: xpStartCustom = xpStartColor; else xpStartGreen keeps it green like XP; else scheme colour.
    // It reaches the panel's left edge when the button is the panel's first item.
    Item {
        id: xpPill
        visible: button.xp
        anchors.fill: face
        anchors.leftMargin: -reach
        anchors.topMargin: -reachTop
        anchors.bottomMargin: -reachBottom
        // Gaps between the bar's edges and the button (panel padding): the pill grows into them, so it is
        // as tall as the bar; to the left only when the button is the first thing on the panel.
        property real reach: 0
        property real reachTop: 0
        property real reachBottom: 0
        function measure() {
            const p = button.mapToItem(null, 0, 0);
            const small = v => v > 0 && v < button.height / 2 ? v : 0;
            reach = p.x > 0 && p.x < button.height ? p.x : 0;
            // ponytail: the panel window has invisible room on its inner side (floating/shadow), so only
            // the gap on the screen-edge side is measured; the bar's padding is the same on the other side.
            const win = button.Window.window;
            const edge = Plasmoid.location === PlasmaCore.Types.TopEdge ? small(p.y)
                       : win ? small(win.height - p.y - button.height) : 0;
            reachTop = edge;
            reachBottom = edge;
        }
        Component.onCompleted: Qt.callLater(measure)
        Connections {
            target: button
            function onWidthChanged() { Qt.callLater(xpPill.measure) }
            function onHeightChanged() { Qt.callLater(xpPill.measure) }
            function onXChanged() { Qt.callLater(xpPill.measure) }
        }
        Connections {
            target: button.parent
            function onXChanged() { Qt.callLater(xpPill.measure) }
        }
        // The panel window resizes after the button when the bar gets thinner or thicker.
        Connections {
            target: button.Window.window
            function onHeightChanged() { remeasure.restart() }
            function onWidthChanged() { remeasure.restart() }
        }
        Timer { id: remeasure; interval: 300; onTriggered: xpPill.measure() }
        Timer { interval: 1500; running: button.xp; onTriggered: xpPill.measure() }
        MouseArea {
            width: xpPill.reach
            height: parent.height
            onPressed: button.wasExpanded = root.expanded
            onClicked: root.expanded = !button.wasExpanded
        }
        readonly property bool modern: button.cfg.xpSubstyle === "modern"
        readonly property var schemeBase: ({ blue: "#2f6fd8", olive: "#7a924f", silver: "#9a9ab4" })
        readonly property color base: button.cfg.xpStartCustom ? button.cfg.xpStartColor
            : button.cfg.xpStartGreen ? "#3c9a3c"
            : button.cfg.xpColor === "custom" ? button.cfg.xpCustomColor
            : (schemeBase[button.cfg.xpColor] || schemeBase.blue)
        readonly property color tone: button.frame === 2 ? Qt.darker(base, 1.25)
                                    : button.frame === 1 ? Qt.lighter(base, 1.12) : base
        readonly property real r: modern ? height / 2 : height * 0.45
        implicitWidth: xpRow.implicitWidth + Math.round(height * (modern ? 0.7 : 0.75))
        // Classic: square on the menu's side (T42 menuPosition): Left = square left, Center = round both
        // sides, Right = square right. Modern stays round on both sides.
        readonly property real leftR: modern || button.cfg.menuPosition !== 0 ? r : 0
        readonly property real rightR: modern || button.cfg.menuPosition !== 2 ? r : 0

        // Soft shadow on the right edge.
        Rectangle {
            anchors.fill: shape
            anchors.leftMargin: 2
            anchors.rightMargin: -2
            radius: xpPill.r
            topLeftRadius: xpPill.leftR
            bottomLeftRadius: xpPill.leftR
            topRightRadius: xpPill.rightR
            bottomRightRadius: xpPill.rightR
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
            opacity: button.onFace ? 0.6 : 0
            Behavior on opacity { NumberAnimation { duration: 120 } }
        }
        Rectangle {
            id: shape
            anchors.fill: parent
            anchors.rightMargin: 2
            anchors.topMargin: xpPill.modern ? 2 : 0
            anchors.bottomMargin: anchors.topMargin
            radius: xpPill.r
            topLeftRadius: xpPill.leftR
            bottomLeftRadius: xpPill.leftR
            topRightRadius: xpPill.rightR
            bottomRightRadius: xpPill.rightR
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
            // Pressed: the label sinks 1 px, like XP's pushed-in button.
            transform: Translate { y: button.frame === 2 ? 1 : 0 }
            anchors.verticalCenter: shape.verticalCenter
            x: xpPill.reach + Math.round(xpPill.height * (xpPill.modern ? 0.3 : 0.2))
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
