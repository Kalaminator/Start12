pragma ComponentBehavior: Bound

import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PC3
import org.kde.plasma.private.kicker as Kicker
import org.kde.kirigami as Kirigami
import org.kde.kitemmodels as KItemModels
import "../win10"
import ".."
import "../common"

// Start11 "Windows 7 style": left pane (pinned, most used, "All Programs"), search box under it,
// places column on the right (user picture on top, power button with arrow at the bottom).
// Substyles (Win7StyleSub): 0 plain, 1 with icons, 2 compact, 3 grid, 4 grid with icons, 5 compact grid.
// Also the "Modern style" (same layout, flat look, own substyle key ModernStyleSub).
FocusScope {
    id: style
    focus: true

    readonly property var cfg: Plasmoid.configuration
    property bool allPrograms: cfg.openAllApps
    property var hoverIcon: ""      // the user picture shows the hovered place, like Windows 7
    property int rev: 0             // bump to re-read the models

    Metrics {
        id: m
    }
    readonly property alias metrics: m
    // Windows 7: the left pane is white with dark text (forced light colours). Modern keeps the theme.
    Metrics {
        id: pm
        mode: style.modern ? m.mode : 2
    }

    readonly property bool modern: cfg.menuStyle === "modern"
    readonly property int sub: modern ? cfg.modernSubstyle : cfg.win7Substyle
    readonly property bool compact: sub === 2 || sub === 5
    readonly property bool grid: sub >= 3
    readonly property bool placeIcons: sub === 1 || sub === 4

    readonly property real pad: m.px(8)
    readonly property real rightW: m.px(compact ? 136 : 156)
    readonly property real rowH: m.px(compact ? 28 : 40)
    readonly property real iconSize: m.px(compact ? 16 : 32)
    readonly property real cellW: m.px(compact ? 64 : 80)
    readonly property real cellH: m.px(compact ? 60 : 76)
    readonly property real sepH: m.px(9)
    readonly property real placeH: m.px(compact ? 26 : 31)

    // Left pane 380 px: the size the user picked by dragging (whole menu ~565 px at 100%).
    implicitWidth: pad * 3 + m.px((compact ? 340 : 380) + (cfg.menuSize >= 2 ? 80 : 0)) + rightW
    implicitHeight: m.heightFor([480, 560, 480, 640])
    readonly property real minimumWidth: pad * 3 + m.px(200) + rightW

    MenuBackground {
        anchors.fill: parent
        metrics: m
    }

    Places {
        id: places
        contextMenu: contextMenu
    }

    // Win7 hover: soft accent box with a border.
    component HoverBox: Rectangle {
        property bool hot: false
        property bool down: false
        visible: hot || down
        radius: style.modern ? 0 : m.px(3)
        color: style.modern ? Qt.alpha(m.text, down ? 0.15 : 0.08) : Qt.alpha(m.accent, down ? 0.35 : 0.2)
        border.color: style.modern ? "transparent" : Qt.alpha(m.accent, 0.6)
    }

    // One entry of the places column.
    component PlaceButton: PC3.AbstractButton {
        id: pb
        property string pid
        readonly property var info: places.info(pid)
        property string label: info ? info.text : ""
        width: parent.width
        height: style.placeH
        hoverEnabled: true
        onHoveredChanged: style.hoverIcon = hovered && info ? info.icon : ""
        onClicked: places.activate(pid, pb)
        leftPadding: m.px(8)
        background: HoverBox {
            hot: pb.hovered
            down: pb.pressed
        }
        contentItem: Row {
            spacing: m.px(8)
            Kirigami.Icon {
                visible: style.placeIcons
                anchors.verticalCenter: parent.verticalCenter
                width: m.px(16)
                height: width
                source: pb.info ? pb.info.icon : ""
                color: m.text
                isMask: String(source).endsWith("-symbolic")
            }
            PC3.Label {
                anchors.verticalCenter: parent.verticalCenter
                width: pb.width - x - pb.leftPadding
                text: pb.label
                elide: Text.ElideRight
                color: m.text
                font.family: m.font
                font.pixelSize: m.fontSize
                font.bold: pb.font.bold
            }
        }
    }

    // Half of the split power button.
    component PowerPart: PC3.AbstractButton {
        id: pp
        height: searchField.height
        hoverEnabled: true
        leftPadding: m.px(10)
        rightPadding: m.px(10)
        background: Rectangle {
            radius: style.modern ? 0 : m.px(3)
            color: style.modern ? Qt.alpha(m.text, pp.pressed ? 0.15 : pp.hovered ? 0.08 : 0)
                 : pp.pressed ? Qt.alpha(m.accent, 0.35) : pp.hovered ? Qt.alpha(m.accent, 0.2) : Qt.alpha(m.text, 0.08)
            border.color: style.modern ? "transparent" : pp.hovered ? Qt.alpha(m.accent, 0.6) : Qt.alpha(m.text, 0.25)
        }
    }

    // ---- Pinned + most used ----
    Kicker.SimpleFavoritesModel {
        id: pinnedModel
        favorites: style.cfg.pinnedGrid
    }
    function roleData(model, row, name) {
        return model.data(model.index(row, 0), model.KItemModels.KRoleNames.role(name));
    }
    // RecentUsageModel ids are "applications:x.desktop"; pins are plain "x.desktop".
    function appId(model, row) {
        return (roleData(model, row, "favoriteId") || "").replace(/^applications:/, "");
    }

    readonly property int perRow: grid ? Math.max(1, Math.floor(home.width / cellW)) : 1
    readonly property var entries: {
        rev;
        const out = [];
        for (let r = 0; r < pinnedModel.count; r++) out.push({ kind: "app", model: pinnedModel, row: r, pinned: true });
        const pinnedRows = Math.ceil(out.length / perRow);
        const free = Math.floor((home.height - (out.length ? sepH : 0)) / (grid ? cellH : rowH)) - pinnedRows;
        const fm = root.frequentAppsModel;
        const freq = [];
        for (let r = 0; r < fm.count && freq.length < free * perRow; r++) {
            const id = appId(fm, r);
            if (id && !cfg.pinnedGrid.includes(id)) freq.push({ kind: "app", model: fm, row: r, pinned: false });
        }
        if (out.length && freq.length) out.push({ kind: "sep" });
        return out.concat(freq);
    }

    // ---- Modern: user picture and name in a header at the top ----
    PC3.AbstractButton {
        id: header
        visible: style.modern
        x: style.pad
        y: style.pad
        height: style.modern ? m.px(36) : 0
        hoverEnabled: true
        leftPadding: m.px(6)
        rightPadding: m.px(10)
        onClicked: places.showUserMenu(header)
        background: HoverBox {
            hot: header.hovered
            down: header.pressed
        }
        contentItem: Row {
            spacing: m.px(10)
            Avatar {
                anchors.verticalCenter: parent.verticalCenter
                width: m.px(26)
                height: width
                metrics: m
                user: places.user
            }
            PC3.Label {
                anchors.verticalCenter: parent.verticalCenter
                text: places.user.fullName || places.user.loginName
                color: m.text
                font.family: m.font
                font.pixelSize: m.fontSize
            }
        }
    }

    // ---- Left pane ----
    Rectangle {
        id: leftPane
        x: style.pad
        anchors.top: style.modern ? header.bottom : parent.top   // not "y": with anchors.bottom, y alone leaves the height at 0
        anchors.topMargin: style.pad
        width: parent.width - style.rightW - style.pad * 3
        anchors.bottom: searchField.top
        anchors.bottomMargin: style.pad
        radius: m.px(4)
        color: style.modern ? "transparent" : Qt.alpha(pm.bg, 0.96)
        border.color: style.modern ? "transparent" : Qt.alpha(pm.text, 0.25)

        Item {
            id: home
            visible: !style.allPrograms && !root.searching
            anchors.fill: parent
            anchors.margins: m.px(4)
            anchors.bottomMargin: allButton.height + m.px(8)
            clip: true

            Flow {
                id: flow
                width: parent.width
                Repeater {
                    model: style.entries
                    delegate: PC3.AbstractButton {
                        id: app
                        required property var modelData
                        readonly property var e: modelData
                        readonly property bool sep: e.kind === "sep"
                        function role(name) {
                            return sep ? undefined : style.roleData(e.model, e.row, name);
                        }
                        width: sep || !style.grid ? flow.width : style.cellW
                        height: sep ? style.sepH : style.grid ? style.cellH : style.rowH
                        enabled: !sep
                        hoverEnabled: true
                        padding: m.px(4)
                        onClicked: {
                            e.model.trigger(e.row, "", null);
                            root.close();
                        }
                        background: Item {
                            Rectangle {
                                visible: app.sep
                                anchors.centerIn: parent
                                width: parent.width - m.px(16)
                                height: 1
                                color: Qt.alpha(pm.text, 0.15)
                            }
                            HoverBox {
                                anchors.fill: parent
                                hot: app.hovered
                                down: app.pressed
                            }
                        }
                        contentItem: Item {
                            visible: !app.sep
                            Kirigami.Icon {
                                id: appIcon
                                width: style.iconSize
                                height: width
                                x: style.grid ? (parent.width - width) / 2 : 0
                                y: style.grid ? m.px(4) : (parent.height - height) / 2
                                source: app.role("decoration") ?? ""
                            }
                            PC3.Label {
                                x: style.grid ? 0 : appIcon.width + m.px(8)
                                y: style.grid ? appIcon.y + appIcon.height + m.px(4) : (parent.height - height) / 2
                                width: parent.width - x
                                horizontalAlignment: style.grid ? Text.AlignHCenter : Text.AlignLeft
                                text: app.role("display") ?? ""
                                elide: Text.ElideRight
                                color: pm.text
                                font.family: m.font
                                font.pixelSize: Math.round(m.fontSize * (style.grid ? 0.85 : 1))
                            }
                        }
                        TapHandler {
                            acceptedButtons: Qt.RightButton
                            onTapped: point => {
                                const id = style.appId(app.e.model, app.e.row);
                                const own = !id ? [] : app.e.pinned
                                    ? [{ text: i18n("Unpin from Start menu"), icon: "window-unpin", run: () => root.unpin(id) }]
                                    : [{ text: i18n("Pin to Start menu"), icon: "window-pin", run: () => root.pin(id) }];
                                contextMenu.show(app, app.e.model, app.e.row, own, point.position.x, point.position.y);
                            }
                        }
                    }
                }
            }
        }

        AppList {
            id: appList
            visible: style.allPrograms && !root.searching
            anchors.fill: parent
            anchors.margins: m.px(4)
            anchors.bottomMargin: allButton.height + m.px(8)
            metrics: pm
            contextMenu: contextMenu
            ghost: ghost
        }

        SearchView {
            id: search
            visible: root.searching
            anchors.fill: parent
            anchors.margins: m.px(4)
            showField: false
            metrics: pm
            contextMenu: contextMenu
        }

        // "All Programs ▸" / "◂ Back"
        PC3.AbstractButton {
            id: allButton
            visible: !root.searching
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: m.px(4)
            height: m.px(compact ? 26 : 30)
            hoverEnabled: true
            onClicked: style.allPrograms = !style.allPrograms
            background: Item {
                Rectangle {
                    width: parent.width
                    height: 1
                    y: -m.px(2)
                    color: Qt.alpha(pm.text, 0.15)
                }
                HoverBox {
                    anchors.fill: parent
                    hot: allButton.hovered
                    down: allButton.pressed
                }
            }
            contentItem: Row {
                leftPadding: m.px(6)
                spacing: m.px(8)
                layoutDirection: style.allPrograms ? Qt.RightToLeft : Qt.LeftToRight
                PC3.Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: style.allPrograms ? i18n("Back") : i18n("All Programs")
                    color: pm.text
                    font.family: m.font
                    font.pixelSize: m.fontSize
                }
                Kirigami.Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    width: m.px(12)
                    height: width
                    source: style.allPrograms ? "go-previous" : "go-next"
                    color: pm.text
                    isMask: true
                }
            }
        }
    }

    // ---- Search box (always focused, like Windows 7) ----
    PC3.TextField {
        id: searchField
        focus: true
        anchors.left: leftPane.left
        anchors.right: leftPane.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: style.pad
        text: root.searchText
        onTextEdited: root.searchText = text
        placeholderText: i18n("Search programs and files")
        font.family: m.font
        font.pixelSize: m.fontSize

        Keys.onDownPressed: search.step(1)
        Keys.onUpPressed: search.step(-1)
        Keys.onReturnPressed: search.activateCurrent()
        Keys.onEnterPressed: search.activateCurrent()
        Keys.onEscapePressed: {
            if (root.searching) {
                root.searchText = "";
            } else if (style.allPrograms) {
                style.allPrograms = false;
            } else {
                root.close();
            }
        }
    }

    // ---- Right column: user picture, places, power ----
    Item {
        id: rightPane
        anchors.left: leftPane.right
        anchors.leftMargin: style.pad
        anchors.right: parent.right
        anchors.rightMargin: style.pad
        anchors.top: parent.top
        anchors.bottom: parent.bottom

        Rectangle {
            id: avatar
            visible: !style.modern
            anchors.horizontalCenter: parent.horizontalCenter
            y: style.pad
            width: m.px(compact ? 44 : 56)
            height: width
            radius: style.modern ? width / 2 : m.px(5)
            color: Qt.alpha(m.text, 0.1)
            border.color: style.modern ? "transparent" : Qt.alpha(m.text, 0.3)
            Kirigami.ShadowedImage {
                id: face
                radius: style.modern ? width / 2 : 0
                anchors.fill: parent
                anchors.margins: m.px(3)
                visible: !style.hoverIcon && status === Image.Ready
                source: places.user.faceIconUrl
                sourceSize: Qt.size(width * 2, height * 2)
                fillMode: Image.PreserveAspectCrop
            }
            Kirigami.Icon {
                anchors.centerIn: parent
                visible: !face.visible
                width: parent.width * 0.6
                height: width
                source: style.hoverIcon || "user-identity"
                color: m.text
                isMask: String(source).endsWith("-symbolic")
            }
        }

        Column {
            anchors.top: parent.top
            anchors.topMargin: style.modern ? header.y + header.height + style.pad : avatar.y + avatar.height + style.pad
            anchors.bottom: powerRow.top
            width: parent.width
            clip: true
            // Top entry is the user's name; it opens the personal folder.
            PlaceButton {
                pid: "home"
                label: places.user.fullName || places.user.loginName
                font.bold: true
            }
            Repeater {
                // "user" and "power" have their own spots here.
                model: style.cfg.railItems.filter(id => id !== "user" && id !== "power" && places.info(id) !== undefined)
                delegate: PlaceButton {
                    required property string modelData
                    pid: modelData
                }
            }
        }

        // Power button with an arrow for the other power actions.
        Row {
            id: powerRow
            anchors.right: parent.right
            y: searchField.y   // rightPane starts at the top, so same coordinates
            readonly property string act: style.cfg.powerButtonAction === "menu" ? "shutdown" : style.cfg.powerButtonAction
            PowerPart {
                id: powerMain
                text: places.powerCatalog[powerRow.act]?.text ?? i18n("Shut down")
                onClicked: root.runSystemAction(powerRow.act)
                contentItem: PC3.Label {
                    text: powerMain.text
                    color: m.text
                    font.family: m.font
                    font.pixelSize: m.fontSize
                    verticalAlignment: Text.AlignVCenter
                }
            }
            PowerPart {
                id: powerArrow
                leftPadding: m.px(6)
                rightPadding: m.px(6)
                onClicked: contextMenu.show(powerArrow, null, -1, places.powerItems(style.cfg.powerItems.filter(id => id !== powerRow.act)))
                contentItem: Kirigami.Icon {
                    implicitWidth: m.px(12)
                    implicitHeight: m.px(12)
                    source: "go-next"
                    color: m.text
                    isMask: true
                }
            }
        }
    }

    // AppList needs a drag ghost; Windows 7 style has no drop targets, so it only shows the icon.
    Item {
        id: ghost
        property string favoriteId: ""
        property var icon: null
        width: m.px(32)
        height: width
        z: 100
        visible: Drag.active
        Kirigami.Icon {
            anchors.fill: parent
            source: ghost.icon
        }
    }

    ContextMenu {
        id: contextMenu
        onActionDone: root.close()
    }

    Connections {
        target: root
        function onExpandedChanged() {
            if (root.expanded) {
                style.allPrograms = style.cfg.openAllApps;
                style.hoverIcon = "";
                style.rev++;
                appList.reset();
                searchField.forceActiveFocus();
            }
        }
    }
}
