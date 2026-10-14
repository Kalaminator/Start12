pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PC3
import org.kde.plasma.private.kicker as Kicker
import org.kde.kirigami as Kirigami
import org.kde.kitemmodels as KItemModels

// Start11 v2 "application canvas": tabs, each with Fences-like groups of icons.
// Tabs: Pinned (Pin to Start lands here), Apps (one group per KDE category), Recent.
// Groups get a colour and a recoloured texture from images/TabTextures, like Start11.
// ponytail: fixed tabs; user-made tabs/groups/pages (Start11 "New tab", "Add group") come later.
Item {
    id: canvas

    required property QtObject metrics
    required property var contextMenu
    readonly property QtObject m: metrics
    readonly property var cfg: Plasmoid.configuration
    property int tab: Math.min(cfg.canvasTab, tabs.length - 1)
    property int rev: 0

    readonly property real pad: m.px(8)
    readonly property real cellW: m.px(76)
    readonly property real cellH: m.px(72)
    readonly property real groupW: 4 * cellW + m.px(8)

    function reset() {
        rev++;
        recentDocs.refresh();
        flick.contentY = 0;
    }

    Kicker.SimpleFavoritesModel {
        id: pinnedModel
        favorites: canvas.cfg.pinnedGrid
    }
    Kicker.RecentUsageModel {
        id: recentDocs
        favoritesModel: root.rootModel.favoritesModel
        shownItems: Kicker.RecentUsageModel.OnlyDocs
    }

    readonly property var tabs: [i18n("Pinned"), i18n("Apps"), i18n("Recent")]
    // Groups of the current tab: { name, src }. ("model" would clash with the Repeater's own.)
    readonly property var groups: {
        rev;
        if (tab === 0) return [{ name: i18n("Pinned"), src: pinnedModel }];
        if (tab === 2) return [{ name: i18n("Most used"), src: root.frequentAppsModel },
                               { name: i18n("Recent files"), src: recentDocs }];
        const rm = root.rootModel;
        const out = [];
        for (let r = 2; r < rm.count; r++) {
            const sub = rm.modelForRow(r);
            if (sub) out.push({ name: rm.data(rm.index(r, 0), Qt.DisplayRole), src: sub });
        }
        return out.sort((a, b) => a.name.localeCompare(b.name));
    }
    Connections {
        target: root.rootModel
        function onRefreshed() { canvas.rev++; }
    }

    function roleData(model, row, name) {
        return model.data(model.index(row, 0), model.KItemModels.KRoleNames.role(name));
    }
    // RecentUsageModel ids are "applications:x.desktop"; pins are plain "x.desktop".
    function appId(model, row) {
        return (roleData(model, row, "favoriteId") || "").replace(/^applications:/, "");
    }
    // Each group gets its own hue, starting from the accent colour.
    function groupColor(i) {
        return Qt.hsla((Math.max(0, m.accent.hslHue) + i * 0.13) % 1, 0.45, 0.42, 1);
    }

    // Tab chips, like Start11's "Notes | Games | Photo".
    Row {
        id: tabRow
        spacing: m.px(2)
        Repeater {
            model: canvas.tabs
            delegate: PC3.AbstractButton {
                id: tabButton
                required property string modelData
                required property int index
                readonly property bool current: canvas.tab === index
                height: m.px(24)
                hoverEnabled: true
                leftPadding: m.px(10)
                rightPadding: m.px(10)
                onClicked: {
                    canvas.tab = index;
                    canvas.cfg.canvasTab = index;
                }
                background: Rectangle {
                    radius: m.px(3)
                    color: Qt.alpha(m.text, tabButton.current ? 0.18 : tabButton.pressed ? 0.15 : tabButton.hovered ? 0.1 : 0.05)
                }
                contentItem: PC3.Label {
                    text: tabButton.modelData
                    color: m.text
                    font.family: m.font
                    font.pixelSize: Math.round(m.fontSize * 0.9)
                    font.weight: tabButton.current ? Font.DemiBold : Font.Normal
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }
    }

    Flickable {
        id: flick
        anchors.top: tabRow.bottom
        anchors.topMargin: canvas.pad
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        clip: true
        contentHeight: flow.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        QQC2.ScrollBar.vertical: PC3.ScrollBar {}

        Flow {
            id: flow
            width: flick.width - m.px(12)
            spacing: canvas.pad
            // As many groups per line as fit; they stretch to fill the line.
            readonly property int lineCount: Math.max(1, Math.floor((width + canvas.pad) / (canvas.groupW + canvas.pad)))
            readonly property real groupWidth: (width - (lineCount - 1) * canvas.pad) / lineCount
            Repeater {
                model: canvas.groups
                delegate: Rectangle {
                    id: group
                    required property var modelData
                    required property int index
                    readonly property var src: modelData?.src ?? null
                    readonly property color tint: canvas.groupColor(index)
                    readonly property int count: src ? src.count : 0
                    readonly property int cols: Math.max(1, Math.floor((width - m.px(8)) / canvas.cellW))
                    width: flow.groupWidth
                    height: header.height + Math.max(1, Math.ceil(count / cols)) * canvas.cellH + m.px(8)
                    radius: m.px(6)
                    color: Qt.alpha(tint, 0.22)
                    border.color: Qt.alpha(tint, 0.6)
                    clip: true

                    // Grey Start11 texture, coloured by the tint under it.
                    Image {
                        anchors.fill: parent
                        visible: canvas.cfg.canvasTextures
                        source: Qt.resolvedUrl("../../images/TabTextures/" + String(group.index % 24 + 1).padStart(2, "0") + ".png")
                        fillMode: Image.Tile
                        opacity: 0.18
                    }

                    Rectangle {
                        id: header
                        width: parent.width
                        height: m.px(26)
                        radius: parent.radius
                        color: Qt.alpha(group.tint, 0.75)
                        PC3.Label {
                            anchors.fill: parent
                            anchors.leftMargin: m.px(10)
                            anchors.rightMargin: m.px(10)
                            text: group.modelData?.name ?? ""
                            elide: Text.ElideRight
                            verticalAlignment: Text.AlignVCenter
                            color: "white"
                            font.family: m.font
                            font.pixelSize: Math.round(m.fontSize * 0.95)
                            font.weight: Font.DemiBold
                        }
                    }

                    PC3.Label {
                        visible: group.count === 0
                        anchors.top: header.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: m.px(10)
                        text: i18n("(Empty)")
                        color: m.text
                        opacity: 0.6
                        font.family: m.font
                        font.pixelSize: m.fontSize
                    }

                    Grid {
                        anchors.top: header.bottom
                        anchors.topMargin: m.px(4)
                        anchors.horizontalCenter: parent.horizontalCenter
                        columns: group.cols
                        Repeater {
                            model: group.count
                            delegate: PC3.AbstractButton {
                                id: cell
                                required property int index
                                function role(name) {
                                    // src is null for a moment while the groups are rebuilt
                                    return group.src ? canvas.roleData(group.src, index, name) : undefined;
                                }
                                width: canvas.cellW
                                height: canvas.cellH
                                hoverEnabled: true
                                onClicked: {
                                    group.src.trigger(index, "", null);
                                    root.close();
                                }
                                PC3.ToolTip.text: role("display") ?? ""
                                PC3.ToolTip.visible: hovered
                                PC3.ToolTip.delay: Kirigami.Units.toolTipDelay
                                background: Rectangle {
                                    radius: m.px(4)
                                    color: m.text
                                    opacity: cell.pressed ? 0.15 : cell.hovered ? 0.1 : 0
                                }
                                contentItem: Column {
                                    topPadding: m.px(6)
                                    spacing: m.px(4)
                                    Kirigami.Icon {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: m.px(28)
                                        height: width
                                        source: cell.role("decoration") ?? ""
                                    }
                                    PC3.Label {
                                        width: cell.width - m.px(8)
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        horizontalAlignment: Text.AlignHCenter
                                        text: cell.role("display") ?? ""
                                        elide: Text.ElideRight
                                        color: m.text
                                        font.family: m.font
                                        font.pixelSize: Math.round(m.fontSize * 0.85)
                                    }
                                }
                                TapHandler {
                                    acceptedButtons: Qt.RightButton
                                    onTapped: point => {
                                        const id = canvas.appId(group.src, cell.index);
                                        const own = !id || id.startsWith("file:") ? [] : root.isPinned(id)
                                            ? [{ text: i18n("Unpin from Start"), icon: "window-unpin", run: () => root.unpin(id) }]
                                            : [{ text: i18n("Pin to Start"), icon: "window-pin", run: () => root.pin(id) }];
                                        canvas.contextMenu.show(cell, group.src, cell.index, own, point.position.x, point.position.y);
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
