import QtQuick
import QtQuick.Effects
import QtQuick.Window
import org.kde.plasma.plasmoid

// Menu background for every style: colour, transparency, texture, round corners.
// It hides Plasma's own popup frame so the transparency is real (KWin still blurs behind).
// Put it as the first child of the style and anchor it to fill the style.
Item {
    id: bgRoot

    required property QtObject metrics
    readonly property var cfg: Plasmoid.configuration

    readonly property var win: Window.window
    function hideThemeFrame() {
        if (!win || !win.contentItem) return;
        for (const child of win.contentItem.children) {
            const type = child.toString();
            if (type.indexOf("DialogBackground") >= 0 || type.indexOf("FrameSvgItem") === 0) child.opacity = 0;
        }
    }
    onWinChanged: Qt.callLater(hideThemeFrame)
    Connections {
        target: root
        function onExpandedChanged() { bgRoot.hideThemeFrame(); }
    }

    // Grow over the (now invisible) popup frame.
    readonly property real frameL: win && win.leftPadding !== undefined ? win.leftPadding : 0
    readonly property real frameR: win && win.rightPadding !== undefined ? win.rightPadding : 0
    readonly property real frameT: win && win.topPadding !== undefined ? win.topPadding : 0
    readonly property real frameB: win && win.bottomPadding !== undefined ? win.bottomPadding : 0
    anchors.leftMargin: -frameL
    anchors.rightMargin: -frameR
    anchors.topMargin: -frameT
    anchors.bottomMargin: -frameB

    Rectangle {
        anchors.fill: parent
        radius: bgRoot.cfg.cornerRadius
        color: Qt.alpha(bgRoot.metrics.bg, bgRoot.metrics.bgAlpha)
        border.width: 1
        border.color: Qt.alpha(bgRoot.metrics.text, 0.08)
    }

    // Texture, clipped to the rounded shape.
    Item {
        id: texture
        anchors.fill: parent
        visible: false
        layer.enabled: true
        Image {
            anchors.fill: parent
            source: bgRoot.cfg.texture === "" ? ""
                : bgRoot.cfg.texture.startsWith("/") ? "file://" + bgRoot.cfg.texture
                : Qt.resolvedUrl("../../images/MenuTextures/" + bgRoot.cfg.texture)
            fillMode: [Image.Tile, Image.Stretch, Image.PreserveAspectFit, Image.PreserveAspectCrop][bgRoot.cfg.textureMode] ?? Image.Tile
        }
        Rectangle {
            anchors.fill: parent
            visible: bgRoot.cfg.darkenTexture
            color: "black"
            opacity: 0.45
        }
    }
    Rectangle {
        id: mask
        anchors.fill: parent
        radius: bgRoot.cfg.cornerRadius
        visible: false
        layer.enabled: true
    }
    MultiEffect {
        anchors.fill: parent
        visible: bgRoot.cfg.texture !== ""
        source: texture
        maskEnabled: true
        maskSource: mask
        opacity: bgRoot.metrics.bgAlpha * bgRoot.cfg.textureOpacity / 100
        colorization: bgRoot.cfg.colorizeTexture ? 0.7 : 0
        colorizationColor: bgRoot.metrics.bg
    }
}
