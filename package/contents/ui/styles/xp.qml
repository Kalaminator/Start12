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

// Windows XP style (Luna blue). Blue header with picture + name, white left column (pinned, most used,
// "All Programs"), light blue places column, blue bottom bar with Log Off / Turn Off Computer.
// Substyle key xpSubstyle: "classic" = XP as it was, "modern" = same palette, rounded and soft.
// Typing anywhere searches (the left column turns into the search results).
FocusScope {
    id: style
    focus: true

    readonly property var cfg: Plasmoid.configuration
    readonly property bool modern: cfg.xpSubstyle === "modern"
    property bool allPrograms: cfg.openAllApps
    property int rev: 0             // bump to re-read the models

    Metrics {
        id: m
    }
    readonly property alias metrics: m
    // XP is always light: white and light blue columns with dark text.
    Metrics {
        id: pm
        mode: 2
    }

    // XP colour schemes (key xpColor): Luna blue, Olive Green, Silver, or custom (derived from
    // xpCustomColor). [classic, modern] per entry; modern softens it. Green All Programs and the
    // orange/red power buttons stay in every scheme, like XP.
    readonly property var schemes: ({
        blue: {
            headTop: ["#1c5ad8", "#3a7bea"], headBottom: ["#3e88ee", "#6aa6f6"], headText: ["#ffffff", "#ffffff"],
            barTop: ["#3b81ea", "#e9f1fd"], barBottom: ["#1a52c8", "#dbe8fb"], barText: ["#ffffff", "#14306e"],
            right: ["#d3e5fa", "#e3eefc"], rightBorder: ["#95bdee", "#95bdee"], placeText: ["#00136b", "#14306e"],
            hover: ["#316ac5", "#dce9fc"], hoverText: ["#ffffff", "#0d3fa6"], line: ["#d6d3ce", "#dfe6f1"]
        },
        olive: {
            headTop: ["#8ba169", "#8ba169"], headBottom: ["#b4c68e", "#c2d19f"], headText: ["#ffffff", "#ffffff"],
            barTop: ["#a7b97f", "#f6f4ea"], barBottom: ["#7a924f", "#ece9d8"], barText: ["#ffffff", "#3a4a1a"],
            right: ["#f1efe2", "#f6f4ea"], rightBorder: ["#c5cfa5", "#c5cfa5"], placeText: ["#3a4a1a", "#3a4a1a"],
            hover: ["#93a070", "#e4ead2"], hoverText: ["#ffffff", "#4e6328"], line: ["#d6d3ce", "#e3e0d0"]
        },
        silver: {
            headTop: ["#a5a5bd", "#b9b9cc"], headBottom: ["#d4d4e2", "#e2e2ec"], headText: ["#1f2440", "#1f2440"],
            barTop: ["#eeeef4", "#f4f4f8"], barBottom: ["#c9c9d9", "#e8e8f0"], barText: ["#1f2440", "#2b2b4a"],
            right: ["#eeeef4", "#f2f2f7"], rightBorder: ["#b6b6c8", "#c9c9d9"], placeText: ["#2b2b4a", "#2b2b4a"],
            hover: ["#8e94b2", "#e4e4ee"], hoverText: ["#ffffff", "#2b2b4a"], line: ["#d6d3ce", "#e2e2ea"]
        }
    })
    function customScheme(k) {
        const tint = a => Qt.tint("#ffffff", Qt.alpha(k, a));
        const ink = Qt.darker(k, 2.2);
        return {
            headTop: [Qt.darker(k, 1.15), k], headBottom: [Qt.lighter(k, 1.35), Qt.lighter(k, 1.4)],
            headText: ["#ffffff", "#ffffff"], barTop: [Qt.lighter(k, 1.2), tint(0.1)],
            barBottom: [Qt.darker(k, 1.2), tint(0.16)], barText: ["#ffffff", ink],
            right: [tint(0.18), tint(0.12)], rightBorder: [tint(0.45), tint(0.4)], placeText: [ink, ink],
            hover: [k, tint(0.16)], hoverText: ["#ffffff", Qt.darker(k, 1.5)], line: ["#d6d3ce", tint(0.1)]
        };
    }
    readonly property var scheme: cfg.xpColor === "custom" ? customScheme(cfg.xpCustomColor)
                                                           : (schemes[cfg.xpColor] || schemes.blue)
    readonly property int si: modern ? 1 : 0
    QtObject {
        id: c
        readonly property color headTop: style.scheme.headTop[style.si]
        readonly property color headBottom: style.scheme.headBottom[style.si]
        readonly property color headText: style.scheme.headText[style.si]
        readonly property color barTop: style.scheme.barTop[style.si]
        readonly property color barBottom: style.scheme.barBottom[style.si]
        readonly property color barText: style.scheme.barText[style.si]
        readonly property color orange: "#f39a32"
        readonly property color orangeLight: "#fcc77b"
        readonly property color green: "#3aa238"
        readonly property color greenDark: "#25801f"
        readonly property color red: "#d8412c"
        readonly property color left: "#ffffff"
        readonly property color right: style.scheme.right[style.si]
        readonly property color rightBorder: style.scheme.rightBorder[style.si]
        readonly property color text: "#000000"
        readonly property color placeText: style.scheme.placeText[style.si]
        readonly property color hover: style.scheme.hover[style.si]
        readonly property color hoverText: style.scheme.hoverText[style.si]
        readonly property color line: style.scheme.line[style.si]
    }

    readonly property real pad: m.px(modern ? 12 : 0)
    readonly property real radius: m.px(modern ? 14 : 8)
    readonly property real headH: m.px(modern ? 72 : 60)
    readonly property real barH: m.px(modern ? 52 : 42)
    readonly property real rowH: m.px(modern ? 44 : 40)
    readonly property real sepH: m.px(modern ? 13 : 9)
    readonly property real placeH: m.px(modern ? 34 : 30)
    readonly property real rightW: m.px(190 + (cfg.menuSize >= 2 ? 30 : 0))

    implicitWidth: m.px(400 + (cfg.menuSize >= 2 ? 80 : 0))
    implicitHeight: m.heightFor([480, 560, 480, 640])
    readonly property real minimumWidth: m.px(360)

    MenuBackground {
        anchors.fill: parent
        metrics: m
    }

    Places {
        id: places
        contextMenu: contextMenu
    }

    // XP hover: solid blue with white text. Modern: soft blue pill.
    component HoverBox: Rectangle {
        property bool hot: false
        property bool down: false
        visible: hot || down
        radius: style.modern ? m.px(8) : 0
        color: down && style.modern ? Qt.darker(c.hover, 1.06) : c.hover
    }
    // Thin separator line, XP fades it at both ends.
    component Sep: Rectangle {
        height: 1
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: "transparent" }
            GradientStop { position: 0.15; color: c.line }
            GradientStop { position: 0.85; color: c.line }
            GradientStop { position: 1; color: "transparent" }
        }
    }

    // ---- Pinned + most used ----
    function roleData(model, row, name) {
        return model.data(model.index(row, 0), model.KItemModels.KRoleNames.role(name));
    }
    // RecentUsageModel ids are "applications:x.desktop"; pins are plain "x.desktop".
    function appId(model, row) {
        return (roleData(model, row, "favoriteId") || "").replace(/^applications:/, "");
    }
    readonly property var entries: {
        rev;
        // ponytail: folders (Win11 pinned folders) open up into plain pins here, like Win7/Modern.
        const pins = Tiles.allPins(root.shownPins).filter(id => !root.missingPins.includes(id)).map((id, i) => ({ kind: "pin", id: id, index: i }));
        const free = Math.floor((home.height - (pins.length ? sepH : 0)) / rowH) - pins.length;
        const fm = root.frequentAppsModel;
        const freq = [];
        for (let r = 0; r < fm.count && freq.length < free; r++) {
            const id = appId(fm, r);
            if (id && !cfg.pinnedGrid.includes(id) && !root.isHidden(id)) freq.push({ kind: "freq", row: r });
        }
        return pins.concat(pins.length && freq.length ? [{ kind: "sep" }] : [], freq);
    }

    // ---- Header: picture in a white frame + bold name ----
    Rectangle {
        id: header
        x: style.pad
        y: style.pad
        width: parent.width - style.pad * 2
        height: style.headH
        topLeftRadius: style.radius
        topRightRadius: style.radius
        bottomLeftRadius: style.modern ? style.radius : 0
        bottomRightRadius: style.modern ? style.radius : 0
        gradient: Gradient {
            GradientStop { position: 0; color: c.headTop }
            GradientStop { position: 1; color: c.headBottom }
        }
        // XP: light top edge.
        Rectangle {
            visible: !style.modern
            x: style.radius / 2
            width: parent.width - style.radius
            height: 1
            color: Qt.alpha("#ffffff", 0.45)
        }

        PC3.AbstractButton {
            id: userButton
            x: m.px(style.modern ? 14 : 8)
            anchors.verticalCenter: parent.verticalCenter
            height: frame.height + m.px(4)
            width: Math.min(parent.width - x * 2, implicitWidth)
            hoverEnabled: true
            onClicked: places.showUserMenu(userButton)
            readonly property bool kbNav: true
            KeyFrame {}
            leftPadding: m.px(2)
            rightPadding: m.px(10)
            background: Rectangle {
                radius: style.modern ? height / 2 : m.px(3)
                color: Qt.alpha("#ffffff", userButton.pressed ? 0.25 : userButton.hovered ? 0.15 : 0)
            }
            contentItem: Row {
                spacing: m.px(style.modern ? 14 : 10)
                Rectangle {
                    id: frame
                    anchors.verticalCenter: parent.verticalCenter
                    width: m.px(style.modern ? 50 : 46)
                    height: width
                    radius: style.modern ? width / 2 : m.px(3)
                    color: "#ffffff"
                    border.color: style.modern ? Qt.alpha("#ffffff", 0.6) : Qt.lighter(c.headBottom, 1.3)
                    border.width: m.px(style.modern ? 3 : 2)
                    Kirigami.ShadowedImage {
                        id: face
                        anchors.fill: parent
                        anchors.margins: frame.border.width
                        radius: style.modern ? width / 2 : m.px(2)
                        visible: status === Image.Ready
                        source: places.user.faceIconUrl
                        sourceSize: Qt.size(width * 2, height * 2)
                        fillMode: Image.PreserveAspectCrop
                    }
                    Kirigami.Icon {
                        anchors.centerIn: parent
                        visible: !face.visible
                        width: parent.width * 0.7
                        height: width
                        source: "user-identity"
                        // No picture set: a blue person on the white frame (the theme icon may be white).
                        isMask: true
                        color: c.placeText
                    }
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    PC3.Label {
                        text: places.user.fullName || places.user.loginName
                        color: c.headText
                        font.family: m.font
                        font.pixelSize: Math.round(m.fontSize * (style.modern ? 1.35 : 1.25))
                        font.bold: true
                        style: Text.Raised
                        styleColor: Qt.alpha("#000000", style.modern ? 0.15 : 0.35)
                    }
                    PC3.Label {
                        visible: style.modern
                        text: places.user.loginName
                        color: Qt.alpha(c.headText, 0.8)
                        font.family: m.font
                        font.pixelSize: Math.round(m.fontSize * 0.85)
                    }
                }
            }
        }
    }

    // XP: orange glow line under the header. Modern: a thin soft accent.
    Rectangle {
        id: glow
        x: style.modern ? style.pad + style.radius : 0
        anchors.top: header.bottom
        anchors.topMargin: style.modern ? m.px(6) : 0
        width: parent.width - x * 2
        height: m.px(style.modern ? 3 : 2)
        radius: height / 2
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: style.modern ? "transparent" : c.orange }
            GradientStop { position: 0.5; color: c.orangeLight }
            GradientStop { position: 1; color: style.modern ? "transparent" : c.orange }
        }
    }

    // ---- Body: white left column, light blue right column ----
    Rectangle {
        id: body
        x: style.pad
        anchors.top: glow.bottom
        anchors.topMargin: style.modern ? m.px(6) : 0
        anchors.bottom: bar.top
        anchors.bottomMargin: style.modern ? style.pad : 0
        width: parent.width - style.pad * 2
        radius: style.modern ? style.radius : 0
        color: c.left
        border.color: style.modern ? Qt.alpha(c.rightBorder, 0.5) : "transparent"
        clip: true

        Item {
            id: leftCol
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.right: rightCol.left
            anchors.margins: m.px(style.modern ? 8 : 4)

            Item {
                id: home
                visible: !style.allPrograms && !root.searching
                anchors.fill: parent
                anchors.bottomMargin: allButton.height + m.px(10)
                clip: true

                Column {
                    width: parent.width
                    Repeater {
                        model: style.entries
                        delegate: PC3.AbstractButton {
                            id: app
                            required property var modelData
                            readonly property var e: modelData
                            readonly property bool sep: e.kind === "sep"
                            readonly property var custom: e.kind === "pin" ? Tiles.custom(e.id) : null
                            // One model per pin (like PinnedGrid), the frequent list shares root's model.
                            readonly property var src: e.kind === "freq" ? root.frequentAppsModel : fav.count > 0 ? fav : null
                            readonly property int row: e.kind === "freq" ? e.row : 0
                            Kicker.SimpleFavoritesModel {
                                id: fav
                                favorites: app.e.kind === "pin" && !app.custom ? [app.e.id] : []
                            }
                            function role(name) {
                                return src ? style.roleData(src, row, name) : undefined;
                            }
                            readonly property bool hot: hovered || root.kbCurrent === app
                            width: parent.width
                            height: sep ? style.sepH : style.rowH
                            enabled: !sep
                            hoverEnabled: true
                            padding: m.px(4)
                            leftPadding: m.px(6)
                            onClicked: {
                                if (custom) {
                                    root.openCustom(custom);
                                } else if (src) {
                                    src.trigger(row, "", null);
                                    root.close();
                                }
                            }
                            function menu(x, y) {
                                let own;
                                if (e.kind === "pin") {
                                    const id = e.id;
                                    const n = style.cfg.pinnedGrid.length;
                                    own = [
                                        { text: i18n("Unpin from Start menu"), icon: "window-unpin", run: () => root.unpin(id) },
                                        { text: i18n("Move up"), icon: "go-up", enabled: e.index > 0, run: () => root.movePinned(id, e.index - 1) },
                                        { text: i18n("Move down"), icon: "go-down", enabled: e.index < n - 1, run: () => root.movePinned(id, e.index + 1) }
                                    ];
                                } else {
                                    const id = style.appId(src, row);
                                    own = id ? [{ text: i18n("Pin to Start menu"), icon: "window-pin", run: () => root.pin(id) }] : [];
                                }
                                contextMenu.show(app, src, src ? row : -1, own, x, y);
                            }
                            readonly property bool kbNav: !sep
                            function kbMenu() { menu(width / 2, height / 2); }
                            KeyFrame {}
                            background: Item {
                                Sep {
                                    visible: app.sep
                                    anchors.centerIn: parent
                                    width: parent.width - m.px(8)
                                }
                                HoverBox {
                                    anchors.fill: parent
                                    hot: app.hot
                                    down: app.pressed
                                }
                            }
                            contentItem: Item {
                                visible: !app.sep
                                Kirigami.Icon {
                                    id: appIcon
                                    width: m.px(32)
                                    height: width
                                    anchors.verticalCenter: parent.verticalCenter
                                    source: app.custom ? (app.custom.icon || "folder") : app.role("decoration") ?? "dialog-question"
                                }
                                PC3.Label {
                                    x: appIcon.width + m.px(8)
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - x
                                    text: app.custom ? app.custom.name : app.role("display") ?? app.e.id ?? ""
                                    elide: Text.ElideRight
                                    color: app.hot ? c.hoverText : c.text
                                    font.family: m.font
                                    font.pixelSize: m.fontSize
                                    font.bold: app.e.kind === "pin"
                                }
                            }
                            TapHandler {
                                acceptedButtons: Qt.RightButton
                                onTapped: point => app.menu(point.position.x, point.position.y)
                            }
                        }
                    }
                }
            }

            AppList {
                id: appList
                visible: style.allPrograms && !root.searching
                anchors.fill: parent
                anchors.bottomMargin: allButton.height + m.px(10)
                metrics: pm
                contextMenu: contextMenu
                ghost: ghost
            }

            SearchView {
                id: search
                visible: root.searching
                anchors.fill: parent
                metrics: pm
                contextMenu: contextMenu
            }

            // "All Programs ▸" (green arrow) / "◂ Back"
            Sep {
                visible: allButton.visible
                anchors.bottom: allButton.top
                anchors.bottomMargin: m.px(5)
                width: parent.width
            }
            PC3.AbstractButton {
                id: allButton
                visible: !root.searching
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                width: style.modern ? implicitWidth : parent.width
                height: m.px(style.modern ? 34 : 30)
                hoverEnabled: true
                onClicked: style.allPrograms = !style.allPrograms
                readonly property bool kbNav: true
                KeyFrame {}
                readonly property bool hot: hovered || root.kbCurrent === allButton
                leftPadding: m.px(style.modern ? 16 : 8)
                rightPadding: m.px(style.modern ? 10 : 8)
                background: Rectangle {
                    radius: style.modern ? height / 2 : 0
                    visible: style.modern || allButton.hot
                    color: style.modern ? (allButton.hot ? c.greenDark : c.green) : c.hover
                    gradient: style.modern ? greenGrad : null
                    Gradient {
                        id: greenGrad
                        GradientStop { position: 0; color: allButton.hot ? Qt.lighter(c.green, 1.05) : Qt.lighter(c.green, 1.2) }
                        GradientStop { position: 1; color: allButton.pressed ? c.greenDark : c.green }
                    }
                }
                contentItem: Row {
                    spacing: m.px(8)
                    layoutDirection: style.allPrograms ? Qt.RightToLeft : Qt.LeftToRight
                    Item {   // XP centres the label, the arrow follows it
                        visible: !style.modern
                        width: Math.max(0, (allButton.availableWidth - allLabel.implicitWidth - arrow.width) / 2 - m.px(8))
                        height: 1
                    }
                    PC3.Label {
                        id: allLabel
                        anchors.verticalCenter: parent.verticalCenter
                        text: style.allPrograms ? i18n("Back") : i18n("All Programs")
                        color: style.modern || allButton.hot ? "#ffffff" : c.text
                        font.family: m.font
                        font.pixelSize: m.fontSize
                        font.bold: true
                    }
                    // Green round arrow.
                    Rectangle {
                        id: arrow
                        anchors.verticalCenter: parent.verticalCenter
                        width: m.px(18)
                        height: width
                        radius: width / 2
                        color: style.modern ? Qt.alpha("#ffffff", 0.25) : c.green
                        border.color: style.modern ? "transparent" : c.greenDark
                        Kirigami.Icon {
                            anchors.centerIn: parent
                            width: m.px(12)
                            height: width
                            source: style.allPrograms ? "go-previous" : "go-next"
                            color: "#ffffff"
                            isMask: true
                        }
                    }
                }
            }
        }

        // Places: bold folders first, a thin line, then the rest.
        Rectangle {
            id: rightCol
            readonly property var ids: style.cfg.railItems.filter(id => id !== "user" && id !== "power" && places.info(id) !== undefined)
            readonly property var folders: ["home", "documents", "downloads", "pictures", "music", "videos", "files", "network"]
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.margins: style.modern ? m.px(6) : 0
            width: style.rightW
            radius: style.modern ? style.radius - m.px(4) : 0
            color: c.right
            // XP: blue line on the left edge.
            Rectangle {
                visible: !style.modern
                width: 1
                height: parent.height
                color: c.rightBorder
            }

            Column {
                id: placeCol
                anchors.fill: parent
                anchors.margins: m.px(style.modern ? 8 : 6)
                clip: true
                Repeater {
                    model: [{ id: "home", main: true }]
                        .concat(rightCol.ids.filter(id => rightCol.folders.includes(id) && id !== "home").map(id => ({ id: id, main: true })))
                        .concat([{ id: "", main: false }])
                        .concat(rightCol.ids.filter(id => !rightCol.folders.includes(id)).map(id => ({ id: id, main: false })))
                    delegate: PC3.AbstractButton {
                        id: pb
                        required property var modelData
                        readonly property bool sep: modelData.id === ""
                        readonly property var info: sep ? null : places.info(modelData.id)
                        readonly property bool hot: hovered || root.kbCurrent === pb
                        width: placeCol.width
                        height: sep ? style.sepH : style.placeH
                        enabled: !sep
                        hoverEnabled: true
                        leftPadding: m.px(6)
                        onClicked: places.activate(modelData.id, pb)
                        readonly property bool kbNav: !sep
                        KeyFrame {}
                        background: Item {
                            Sep {
                                visible: pb.sep
                                anchors.centerIn: parent
                                width: parent.width
                            }
                            HoverBox {
                                anchors.fill: parent
                                hot: pb.hot
                                down: pb.pressed
                            }
                        }
                        contentItem: Row {
                            visible: !pb.sep
                            spacing: m.px(8)
                            Kirigami.Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                width: m.px(pb.modelData.main ? 24 : 22)
                                height: width
                                // The theme's place icons are white (dark theme): draw them black on the light
                                // blue pane and white on the blue hover, so they always stand out.
                                source: pb.info ? pb.info.icon : ""
                                isMask: true
                                color: pb.hot ? c.hoverText : "#000000"
                            }
                            PC3.Label {
                                anchors.verticalCenter: parent.verticalCenter
                                width: pb.availableWidth - x
                                text: pb.info ? pb.info.text : ""
                                elide: Text.ElideRight
                                color: pb.hot ? c.hoverText : c.placeText
                                font.family: m.font
                                font.pixelSize: m.fontSize
                                font.bold: pb.modelData.main
                            }
                        }
                    }
                }
            }
        }
    }

    // ---- Bottom bar: Log Off / Turn Off Computer ----
    component BarButton: PC3.AbstractButton {
        id: bb
        property string iconName
        property color chip
        readonly property bool hot: hovered || root.kbCurrent === bb
        anchors.verticalCenter: parent.verticalCenter
        height: style.barH - m.px(style.modern ? 14 : 10)
        hoverEnabled: true
        leftPadding: m.px(4)
        rightPadding: m.px(10)
        readonly property bool kbNav: true
        KeyFrame {}
        background: Rectangle {
            radius: style.modern ? height / 2 : m.px(3)
            color: style.modern ? (bb.hot ? "#ffffff" : "transparent")
                 : Qt.alpha("#ffffff", bb.pressed ? 0.3 : bb.hot ? 0.18 : 0)
            border.color: style.modern && bb.hot ? Qt.alpha(c.rightBorder, 0.7) : "transparent"
        }
        contentItem: Row {
            spacing: m.px(6)
            // Coloured square (XP) / circle (modern) with a white symbol.
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: m.px(style.modern ? 26 : 24)
                height: width
                radius: style.modern ? width / 2 : m.px(4)
                gradient: Gradient {
                    GradientStop { position: 0; color: Qt.lighter(bb.chip, 1.35) }
                    GradientStop { position: 1; color: bb.chip }
                }
                border.color: style.modern ? "transparent" : Qt.alpha("#ffffff", 0.8)
                Kirigami.Icon {
                    anchors.centerIn: parent
                    width: parent.width * 0.62
                    height: width
                    source: bb.iconName
                    color: "#ffffff"
                    isMask: true
                }
            }
            PC3.Label {
                anchors.verticalCenter: parent.verticalCenter
                text: bb.text
                color: c.barText
                font.family: m.font
                font.pixelSize: m.fontSize
            }
        }
    }

    Rectangle {
        id: bar
        x: style.pad
        anchors.bottom: parent.bottom
        anchors.bottomMargin: style.pad
        width: parent.width - style.pad * 2
        height: style.barH
        radius: style.modern ? style.radius : 0
        gradient: Gradient {
            GradientStop { position: 0; color: c.barTop }
            GradientStop { position: 1; color: c.barBottom }
        }
        border.color: style.modern ? Qt.alpha(c.rightBorder, 0.5) : "transparent"

        Row {
            id: barRow
            anchors.right: parent.right
            anchors.rightMargin: m.px(style.modern ? 8 : 6)
            height: parent.height
            spacing: m.px(style.modern ? 6 : 4)
            BarButton {
                id: logOff
                text: i18n("Log Off")
                iconName: "system-log-out-symbolic"
                chip: c.orange
                onClicked: contextMenu.show(logOff, null, -1, places.powerItems(["lock-screen", "logout", "switch-user"]))
            }
            BarButton {
                id: turnOff
                text: i18n("Turn Off Computer")
                iconName: "system-shutdown-symbolic"
                chip: c.red
                onClicked: contextMenu.show(turnOff, null, -1, places.powerItems(style.cfg.powerItems))
            }
        }
    }

    DragGhost {
        id: ghost
        metrics: m
    }

    ContextMenu {
        id: contextMenu
        onActionDone: root.close()
    }

    KeyNav {
        id: nav
        panes: [style.allPrograms ? appList : leftCol, rightCol, barRow]
        main: panes[0]
    }

    // Arrows/Tab/Enter move through the menu; typing anywhere starts a search.
    Keys.onPressed: event => {
        if (nav.handle(event)) {
            event.accepted = true;
        } else if (event.key === Qt.Key_Escape) {
            if (root.searching) {
                root.searchText = "";
            } else if (style.allPrograms) {
                style.allPrograms = false;
            } else {
                root.close();
            }
            event.accepted = true;
        } else if (event.text.length > 0 && event.text.trim().length > 0
                   && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) {
            root.searchText += event.text;
            search.focusField();
            event.accepted = true;
        }
    }

    Connections {
        target: root
        function onExpandedChanged() {
            if (root.expanded) {
                style.allPrograms = style.cfg.openAllApps;
                style.rev++;
                appList.reset();
                style.forceActiveFocus();
            }
        }
        function onSearchingChanged() {
            if (!root.searching) style.forceActiveFocus();
        }
    }
}
