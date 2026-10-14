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
import "../code/tiles.js" as Tiles

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
        accentStart: style.modern && m.accentStart
    }

    readonly property bool modern: cfg.menuStyle === "modern"
    readonly property int sub: modern ? cfg.modernSubstyle : cfg.win7Substyle
    readonly property bool compact: sub === 2 || sub === 5
    readonly property bool grid: sub >= 3
    readonly property bool placeIcons: sub === 1 || sub === 4

    readonly property real pad: m.px(8)
    // Places column; design mode drags its left edge (common/SplitHandle). implicitWidth keeps the
    // default, so the popup keeps its width and the left pane gives way.
    readonly property real rightDef: m.px(compact ? 136 : 156)
    readonly property real rightW: root.splitFor(cfg.menuStyle, rightDef)
    readonly property real rowH: m.px(compact ? 28 : 40)
    readonly property real iconSize: m.px(compact ? 16 : 32)
    readonly property real cellW: m.px(compact ? 64 : 80)
    readonly property real cellH: m.px(compact ? 60 : 76)
    readonly property real sepH: m.px(9)
    readonly property real placeH: m.px(cfg.smallPlaces ? 22 : compact ? 26 : 31)

    // Left pane 380 px: the size the user picked by dragging (whole menu ~565 px at 100%).
    implicitWidth: pad * 3 + m.px((compact ? 340 : 380) + (cfg.menuSize >= 2 ? 80 : 0)) + rightDef
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
        readonly property bool sep: info?.separator === true
        width: parent.width
        height: sep ? m.px(9) : style.placeH
        enabled: !sep
        hoverEnabled: true
        onHoveredChanged: style.hoverIcon = hovered && info ? info.icon : ""
        onClicked: places.activate(pid, pb)
        readonly property bool kbNav: !sep
        KeyFrame {}
        leftPadding: m.px(8)
        background: HoverBox {
            hot: pb.hovered
            down: pb.pressed
        }
        Rectangle {
            visible: pb.sep
            anchors.centerIn: parent
            width: parent.width - m.px(8)
            height: 1
            color: m.text
            opacity: 0.25
        }
        contentItem: Row {
            visible: !pb.sep
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
        favorites: Tiles.allPins(style.cfg.pinnedGrid)
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
        // Pins in cfg.pinnedGrid order. pinnedModel drops website/file/folder ids (Tiles.custom),
        // so apps are matched to their model row by id; "index" is the place in cfg.pinnedGrid.
        const rowOf = {};
        for (let r = 0; r < pinnedModel.count; r++) rowOf[appId(pinnedModel, r)] = r;
        const out = [];
        cfg.pinnedGrid.forEach((id, i) => {
            const c = Tiles.custom(id);
            if (c) out.push({ kind: "app", custom: c, id: id, index: i, pinned: true });
            else if (rowOf[id] !== undefined) out.push({ kind: "app", model: pinnedModel, row: rowOf[id], id: id, index: i, pinned: true });
        });
        // Rows whose id the model rewrote (e.g. preferred://browser) still show, at the end.
        const shown = out.map(x => x.row);
        for (let r = 0; r < pinnedModel.count; r++)
            if (!shown.includes(r)) out.push({ kind: "app", model: pinnedModel, row: r, id: appId(pinnedModel, r), index: cfg.pinnedGrid.length, pinned: true });
        const pinnedRows = Math.ceil(out.length / perRow);
        const free = Math.floor((home.height - (out.length ? sepH : 0)) / (grid ? cellH : rowH)) - pinnedRows;
        const fm = root.frequentAppsModel;
        const freq = [];
        for (let r = 0; r < fm.count && freq.length < free * perRow; r++) {
            const id = appId(fm, r);
            if (id && !cfg.pinnedGrid.includes(id) && !root.isHidden(id)) freq.push({ kind: "app", model: fm, row: r, pinned: false });
        }
        if (out.length && freq.length) out.push({ kind: "sep" });
        return out.concat(freq);
    }

    // ---- Modern: user picture and name in a header at the top ----
    PC3.AbstractButton {
        id: header
        visible: style.modern
        x: LayoutMirroring.enabled ? parent.width - width - style.pad : style.pad
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

    SplitHandle {
        name: style.cfg.menuStyle
        value: style.rightW
        reversed: true
        minimum: m.px(100)
        maximum: style.width - style.pad * 3 - m.px(200)
        x: (LayoutMirroring.enabled ? leftPane.x - style.pad / 2 : leftPane.x + leftPane.width + style.pad / 2) - width / 2
        anchors.top: leftPane.top
        anchors.bottom: leftPane.bottom
    }

    // ---- Left pane ----
    Rectangle {
        id: leftPane
        x: LayoutMirroring.enabled ? parent.width - width - style.pad : style.pad
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

            // Right-click on empty space: pin a website, file or folder.
            TapHandler {
                acceptedButtons: Qt.RightButton
                onTapped: point => contextMenu.show(home, null, -1, root.pinNewItems, point.position.x, point.position.y)
            }

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
                        readonly property var custom: e.custom ?? null   // pinned website/file/folder
                        function role(name) {
                            return sep || custom ? undefined : style.roleData(e.model, e.row, name);
                        }
                        readonly property var appIcon: custom ? (custom.icon || "folder") : role("decoration") ?? ""
                        // Jump-list arrow (list layout, apps with kicker actions), like Windows 7.
                        readonly property bool hasJump: !sep && !custom && !style.grid
                            && contextMenu.kickerActions(e.model, e.row).length > 0
                        width: sep || !style.grid ? flow.width : style.cellW
                        height: sep ? style.sepH : style.grid ? style.cellH : style.rowH
                        enabled: !sep
                        hoverEnabled: true
                        padding: m.px(4)
                        opacity: mouse.dragging ? 0.3 : 1
                        function launch() {
                            if (custom) {
                                root.openCustom(custom);
                            } else {
                                e.model.trigger(e.row, "", null);
                                root.close();
                            }
                        }
                        function menu(x, y, target) {
                            const id = custom ? e.id : style.appId(e.model, e.row);
                            const own = !id ? [] : e.pinned
                                ? [{ text: i18n("Unpin from Start menu"), icon: "window-unpin", run: () => root.unpin(id) }]
                                : [{ text: i18n("Pin to Start menu"), icon: "window-pin", run: () => root.pin(id) }];
                            if (id && e.pinned) own.splice(1, 0, { text: i18n("Rename"), icon: "edit-rename", run: () => root.renamePin(id, app.custom ? app.custom.name : app.role("display")) });
                            else if (id) own.push({ text: i18n("Hide from apps"), icon: "hint", run: () => root.hideApp(id) });   // most used row
                            contextMenu.show(target ?? app, custom ? null : e.model, custom ? -1 : e.row, own.concat(root.taskbarItem(id)), x, y);
                        }
                        readonly property bool kbNav: !sep
                        function kbActivate() { launch(); }
                        function kbMenu() { menu(width / 2, height / 2); }
                        KeyFrame {}
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
                                down: mouse.pressed && !mouse.dragging
                            }
                            // Drop marker: the dragged pin lands above this row.
                            Rectangle {
                                visible: drop.containsDrag
                                width: style.grid ? Math.max(2, m.px(3)) : parent.width
                                height: style.grid ? parent.height : Math.max(2, m.px(3))
                                color: m.accent
                            }
                        }
                        contentItem: Item {
                            visible: !app.sep
                            Kirigami.Icon {
                                id: appIcon
                                width: style.iconSize
                                height: width
                                x: style.grid ? (parent.width - width) / 2 : LayoutMirroring.enabled ? parent.width - width : 0
                                y: style.grid ? m.px(4) : (parent.height - height) / 2
                                source: app.appIcon
                            }
                            PC3.Label {
                                x: LayoutMirroring.enabled ? (app.hasJump ? jump.width : 0) : (style.grid ? 0 : appIcon.width + m.px(8))
                                y: style.grid ? appIcon.y + appIcon.height + m.px(4) : (parent.height - height) / 2
                                width: parent.width - (style.grid ? 0 : appIcon.width + m.px(8)) - (app.hasJump ? jump.width : 0)
                                horizontalAlignment: style.grid ? Text.AlignHCenter : Text.AlignLeft
                                text: (app.e.pinned ? root.capOf(app.custom ? app.e.id : style.appId(app.e.model, app.e.row)) : "") || (app.custom ? app.custom.name : app.role("display") ?? "")
                                elide: Text.ElideRight
                                color: pm.text
                                font.family: m.font
                                font.pixelSize: Math.round(m.fontSize * (style.grid ? 0.85 : 1))
                            }
                        }
                        DropArea {
                            id: drop
                            anchors.fill: parent
                            enabled: app.e.pinned === true
                            keys: ["start12-tile"]
                            onDropped: d => root.movePinned(d.source.favoriteId, app.e.index)
                        }

                        // Click, right-click, and drag a pin to reorder (same as PinnedGrid).
                        MouseArea {
                            id: mouse
                            anchors.fill: parent
                            enabled: !app.sep
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            preventStealing: true
                            property point pressPos
                            property bool dragging: false
                            onPressed: ev => pressPos = Qt.point(ev.x, ev.y)
                            onPositionChanged: ev => {
                                if (!dragging && pressed && app.e.pinned && Math.hypot(ev.x - pressPos.x, ev.y - pressPos.y) > Qt.styleHints.startDragDistance) {
                                    dragging = true;
                                    ghost.favoriteId = app.e.id;
                                    ghost.icon = app.appIcon;
                                    ghost.Drag.active = true;
                                }
                                if (dragging) {
                                    const p = mapToItem(ghost.parent, ev.x, ev.y);
                                    ghost.x = p.x - ghost.width / 2;
                                    ghost.y = p.y - ghost.height / 2;
                                }
                            }
                            onReleased: ev => {
                                if (dragging) {
                                    ghost.Drag.drop();
                                    ghost.Drag.active = false;
                                    dragging = false;
                                } else if (ev.button === Qt.LeftButton && containsMouse) {
                                    app.launch();
                                } else if (ev.button === Qt.RightButton) {
                                    app.menu(ev.x, ev.y);
                                }
                            }
                            onCanceled: {
                                ghost.Drag.active = false;
                                dragging = false;
                            }
                        }

                        // Jump-list arrow: recent files and app actions, plus Pin/Unpin.
                        PC3.AbstractButton {
                            id: jump
                            visible: app.hasJump
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: m.px(22)
                            hoverEnabled: true
                            onClicked: app.menu(width, 0, jump)
                            background: HoverBox {
                                hot: jump.hovered
                                down: jump.pressed
                            }
                            contentItem: Kirigami.Icon {
                                implicitWidth: m.px(12)
                                implicitHeight: m.px(12)
                                source: "go-next"
                                color: pm.text
                                isMask: true
                                opacity: app.hovered || jump.hovered ? 1 : 0.5
                            }
                        }
                    }
                }
            }
        }

        AppList {
            id: appList
            showFilteredFolders: true
            treeExtras: true
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
            readonly property bool kbNav: true
            function kbStep(cur, dx, dy) { return cur ? null : allButton; }   // a KeyNav pane of its own in All Programs
            KeyFrame {}
            background: Item {
                Rectangle {
                    width: parent.width
                    height: 1
                    y: -m.px(2)
                    color: Qt.alpha(pm.text, 0.15)
                }
                HoverBox {
                    anchors.fill: parent
                    hot: allButton.hovered || root.kbCurrent === allButton
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

        SearchHistory { field: searchField; above: true }

        Keys.onPressed: event => {
            event.accepted = true;
            if (nav.handle(event)) {
                // nothing typed: arrows/Tab/Enter move through the menu
            } else if (event.key === Qt.Key_Down || event.key === Qt.Key_Up) {
                search.step(event.key === Qt.Key_Down ? 1 : -1);
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                search.activateCurrent();
            } else if (event.key !== Qt.Key_Escape) {
                event.accepted = false;
            } else if (root.searching) {
                root.searchText = "";
            } else if (style.allPrograms) {
                style.allPrograms = false;
            } else {
                root.close();
            }
        }
    }

    KeyNav {
        id: nav
        // home view: leftPane holds the pinned/most used rows and the All Programs button
        panes: style.allPrograms ? [allButton, appList, rightPane] : [leftPane, rightPane]
        main: style.allPrograms ? appList : leftPane
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
                contentItem: Row {
                    spacing: m.px(6)
                    Kirigami.Icon {
                        visible: style.cfg.powerButtonIcon
                        anchors.verticalCenter: parent.verticalCenter
                        width: m.px(16)
                        height: width
                        source: "system-shutdown-symbolic"
                        color: m.text
                        isMask: true
                    }
                    PC3.Label {
                        text: powerMain.text
                        color: m.text
                        font.family: m.font
                        font.pixelSize: m.fontSize
                        anchors.verticalCenter: parent.verticalCenter
                    }
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

    // Drag ghost for reordering pins (AppList uses it too).
    DragGhost {
        id: ghost
        metrics: m
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
