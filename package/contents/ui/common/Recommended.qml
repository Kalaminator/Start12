pragma ComponentBehavior: Bound

import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PC3
import org.kde.plasma.private.kicker as Kicker
import org.kde.kirigami as Kirigami
import org.kde.kitemmodels as KItemModels

// Windows 11 "Recommended": recent files and apps in two columns.
Item {
    id: rec

    required property QtObject metrics
    required property var contextMenu
    property int maxItems: Plasmoid.configuration.recommendedRows * 2
    // When true, show only the rows that fit in this item's height.
    property bool fitToHeight: false
    property int columns: 2
    readonly property real rowHeight: metrics.px(52)
    readonly property int shown: fitToHeight ? Math.min(maxItems, Math.max(0, Math.floor(height / rowHeight)) * columns) : maxItems

    readonly property alias count: repeater.count

    Kicker.RecentUsageModel {
        id: recent
        favoritesModel: root.rootModel.favoritesModel
        shownItems: [Kicker.RecentUsageModel.AppsAndDocs, Kicker.RecentUsageModel.OnlyDocs,
                     Kicker.RecentUsageModel.OnlyApps][Plasmoid.configuration.recommendedKinds] ?? Kicker.RecentUsageModel.AppsAndDocs
    }
    Connections {
        target: root
        function onMenuOpenChanged() { if (root.menuOpen) recent.refresh(); }
    }

    function roleData(row, name) {
        return recent.data(recent.index(row, 0), recent.KItemModels.KRoleNames.role(name));
    }

    // Source rows to show (folders dropped when recentHideFolders is on).
    readonly property var rows: {
        const out = [];
        for (let i = 0; i < recent.count && out.length < rec.shown; ++i) {
            const ic = String(rec.roleData(i, "decoration") ?? "");
            if (!(Plasmoid.configuration.recentHideFolders && (ic === "folder" || ic.startsWith("inode-directory") || ic.startsWith("folder-")))) out.push(i);
        }
        return out;
    }

    implicitHeight: flow.implicitHeight

    Flow {
        id: flow
        width: parent.width
        Repeater {
            id: repeater
            model: rec.rows.length
            delegate: PC3.AbstractButton {
                id: item
                required property int index
                readonly property int row: rec.rows[index] ?? -1
                width: flow.width / rec.columns
                height: rec.rowHeight
                hoverEnabled: true
                onClicked: {
                    recent.trigger(item.row, "", null);
                    root.close();
                }
                function menu(x, y) {
                    const id = rec.roleData(item.row, "favoriteId");
                    const own = id && !id.startsWith("file:") ? [root.isPinned(id)
                        ? { text: i18n("Unpin from Start"), icon: "window-unpin", run: () => root.unpin(id) }
                        : { text: i18n("Pin to Start"), icon: "window-pin", run: () => root.pin(id) }] : [];
                    rec.contextMenu.show(item, recent, item.row, own, x, y);
                }
                readonly property bool kbNav: true
                function kbMenu() { menu(width / 2, height / 2); }
                KeyFrame {}
                background: Rectangle {
                    radius: rec.metrics.px(4)
                    color: rec.metrics.text
                    opacity: item.pressed ? 0.12 : (item.hovered || root.kbCurrent === item ? 0.07 : 0)
                }
                leftPadding: rec.metrics.px(10)
                contentItem: Item {
                    Kirigami.Icon {
                        id: icon
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: rec.metrics.px(32)
                        height: width
                        source: rec.roleData(item.row, "decoration")
                    }
                    Column {
                        anchors.left: icon.right
                        anchors.leftMargin: rec.metrics.px(12)
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        PC3.Label {
                            width: parent.width
                            text: rec.roleData(item.row, "display") ?? ""
                            elide: Text.ElideRight
                            color: rec.metrics.text
                            font.family: rec.metrics.font
                            font.pixelSize: Math.round(rec.metrics.fontSize * 0.95)
                        }
                        PC3.Label {
                            width: parent.width
                            readonly property string desc: rec.roleData(item.row, "description") ?? ""
                            visible: desc !== ""
                            text: desc
                            elide: Text.ElideMiddle
                            color: rec.metrics.text
                            opacity: 0.6
                            font.family: rec.metrics.font
                            font.pixelSize: Math.round(rec.metrics.fontSize * 0.8)
                        }
                    }
                }
                TapHandler {
                    acceptedButtons: Qt.RightButton
                    onTapped: point => item.menu(point.position.x, point.position.y)
                }
            }
        }
    }

    PC3.Label {
        visible: repeater.count === 0
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: i18n("The more you use your PC, the more we'll show your new apps and recent files here.")
        wrapMode: Text.WordWrap
        color: rec.metrics.text
        opacity: 0.6
        font.family: rec.metrics.font
        font.pixelSize: Math.round(rec.metrics.fontSize * 0.9)
    }
}
