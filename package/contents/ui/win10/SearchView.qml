pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PC3
import org.kde.kirigami as Kirigami
import org.kde.kitemmodels as KItemModels
import "../code/tiles.js" as Tiles

// Search results (KRunner): "Best match" first, then results, optionally grouped
// by type (Apps, Files, Settings ...). Last row: search the internet.
Item {
    id: search

    required property QtObject metrics
    required property var contextMenu
    property bool showField: true   // false: the style has its own search box

    readonly property var cfg: Plasmoid.configuration
    property var rows: []
    property var watched: []   // runner models we already listen to

    // Filter icons (Start11 search filters): "" = all; keys searchFilterIcons / searchFilter.
    readonly property string filter: cfg.searchFilterIcons ? cfg.searchFilter : ""
    onFilterChanged: rebuildTimer.restart()
    readonly property var filters: [
        ["apps", "applications-all", i18n("Apps")],
        ["settings", "preferences-system", i18n("Settings")],
        ["documents", "x-office-document", i18n("Documents")],
        ["music", "audio-x-generic", i18n("Music")],
        ["pictures", "image-x-generic", i18n("Pictures")],
        ["videos", "video-x-generic", i18n("Videos")],
        ["files", "system-file-manager", i18n("Files")],
        ["web", "internet-web-browser", i18n("Web")]
    ]
    readonly property var extensions: ({
        documents: "pdf doc docx odt ods odp odg xls xlsx ppt pptx txt md rtf csv epub tex html htm xml json",
        music: "mp3 flac ogg oga opus wav m4a aac wma mid",
        pictures: "png jpg jpeg gif bmp svg webp tif tiff heic avif ico kra xcf",
        videos: "mp4 mkv webm avi mov wmv flv m4v mpg mpeg ogv 3gp"
    })

    // Does result row r of a runner model pass the current filter? Plasma 6.7 runner results carry
    // no runner id, so the kind comes from the url: apps are .desktop files, settings kcm_*.desktop.
    function passes(model, r) {
        const f = filter;
        if (root.isHidden(roleData(model, r, "favoriteId"))) return false;
        if (f === "") return true;
        if (f === "web") return false;
        const fav = String(roleData(model, r, "favoriteId") ?? "");
        const urls = roleData(model, r, "urls");
        const url = String((urls && urls.length ? urls[0] : roleData(model, r, "url")) ?? "");
        const desktop = fav.startsWith("applications:") || url.endsWith(".desktop");
        const settings = desktop && (/kcm_|systemsettings/.test(fav + " " + url));
        if (f === "settings") return settings;
        if (f === "apps") return desktop && !settings;
        if (desktop || !(url.startsWith("file:") || url.startsWith("/"))) return false;
        if (f === "files") return true;
        const dot = url.lastIndexOf(".");
        const ext = dot > url.lastIndexOf("/") ? url.slice(dot + 1).toLowerCase() : "";
        return ext !== "" && (extensions[f] ?? "").split(" ").includes(ext);
    }

    function setFilter(id) {
        cfg.searchFilter = cfg.searchFilter === id ? "" : id;
    }

    function focusField() {
        field.forceActiveFocus();
        field.cursorPosition = field.text.length;
    }

    function roleData(model, row, name) {
        return model.data(model.index(row, 0), model.KItemModels.KRoleNames.role(name));
    }

    // Flatten runner models into rows: { kind: "header"|"hit"|"web", model, row, best }
    function rebuild() {
        const rm = root.runnerModel;
        const out = [];
        for (let i = 0; i < rm.count; i++) {
            const model = rm.modelForRow(i);
            if (model && !watched.includes(model)) {
                watched.push(model);
                model.countChanged.connect(rebuildTimer.restart);
            }
            if (!model || model.count === 0) continue;
            const hits = [];
            for (let r = 0; r < model.count; r++) {
                if (passes(model, r)) hits.push({ kind: "hit", model: model, row: r });
            }
            if (hits.length === 0) continue;
            if (cfg.groupResults && !rm.mergeResults) {
                out.push({ kind: "header", name: rm.data(rm.index(i, 0), Qt.DisplayRole) });
            }
            out.push(...hits);
        }
        const first = out.findIndex(e => e.kind === "hit");
        if (first >= 0) {
            out[first].best = true;
            // Best match sits on top, above the first group header.
            if (first > 0) out.unshift(out.splice(first, 1)[0]);
        }
        if ((cfg.showWebSearch || filter === "web") && root.searchText.length > 0) {
            out.push({ kind: "web" });
        }
        rows = out;
        view.currentIndex = rows.findIndex(e => e.kind !== "header");
    }

    Timer {
        id: rebuildTimer
        interval: 60
        onTriggered: search.rebuild()
    }
    Connections {
        target: root.runnerModel
        function onCountChanged() { rebuildTimer.restart(); }
        function onQueryingChanged() { rebuildTimer.restart(); }
    }
    Connections {
        target: root
        function onSearchTextChanged() { rebuildTimer.restart(); }
    }

    function activate(index) {
        const e = rows[index];
        if (!e) return;
        if (e.kind === "hit") {
            if (cfg.searchHistoryEnabled) cfg.searchHistory = Tiles.pushHistory(cfg.searchHistory, root.searchText);
            e.model.trigger(e.row, "", null);
            root.close();
        } else if (e.kind === "web") {
            root.openUrl(cfg.webSearchUrl.replace("%s", encodeURIComponent(root.searchText)));
        }
    }

    function activateCurrent() {
        activate(view.currentIndex);
    }

    function step(delta) {
        let i = view.currentIndex;
        do { i += delta; } while (i >= 0 && i < rows.length && rows[i].kind === "header");
        if (i >= 0 && i < rows.length) view.currentIndex = i;
    }

    PC3.TextField {
        id: field
        visible: search.showField
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: search.metrics.pad
        text: root.searchText
        onTextEdited: root.searchText = text
        placeholderText: i18n("Type here to search")
        font.family: search.metrics.font
        font.pixelSize: Math.round(search.metrics.fontSize * 1.1)

        Keys.onDownPressed: search.step(1)
        Keys.onUpPressed: search.step(-1)
        Keys.onReturnPressed: search.activate(view.currentIndex)
        Keys.onEnterPressed: search.activate(view.currentIndex)
        Keys.onEscapePressed: root.searchText = ""
    }

    Row {
        id: filterRow
        visible: search.cfg.searchFilterIcons
        anchors.top: search.showField ? field.bottom : parent.top
        anchors.topMargin: search.showField ? search.metrics.px(8) : 0
        anchors.left: parent.left
        anchors.leftMargin: search.metrics.pad
        height: visible ? search.metrics.px(32) : 0
        spacing: search.metrics.px(2)
        Repeater {
            model: search.filters
            delegate: PC3.ToolButton {
                required property var modelData
                width: search.metrics.px(32)
                height: width
                icon.name: modelData[1]
                display: PC3.AbstractButton.IconOnly
                text: modelData[2]
                checked: search.filter === modelData[0]
                onClicked: search.setFilter(modelData[0])
                PC3.ToolTip.text: text
                PC3.ToolTip.visible: hovered
                PC3.ToolTip.delay: Kirigami.Units.toolTipDelay
            }
        }
    }

    ListView {
        id: view
        anchors.top: filterRow.visible ? filterRow.bottom : (search.showField ? field.bottom : parent.top)
        anchors.topMargin: filterRow.visible || search.showField ? search.metrics.px(8) : 0
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        clip: true
        model: search.rows
        boundsBehavior: Flickable.StopAtBounds
        highlightMoveDuration: 0
        QQC2.ScrollBar.vertical: PC3.ScrollBar {}

        delegate: PC3.AbstractButton {
            id: hit
            required property int index
            required property var modelData
            readonly property var e: modelData
            readonly property bool isHit: e.kind === "hit"
            readonly property bool current: ListView.isCurrentItem

            width: view.width
            height: e.kind === "header" ? search.metrics.px(30)
                  : e.best ? search.metrics.px(72) : search.metrics.row
            enabled: e.kind !== "header"
            hoverEnabled: true
            onHoveredChanged: if (hovered) view.currentIndex = index
            onClicked: search.activate(index)
            leftPadding: search.metrics.pad
            rightPadding: search.metrics.pad

            background: Rectangle {
                visible: hit.e.kind !== "header"
                color: hit.current ? Qt.alpha(search.metrics.accent, 0.35) : search.metrics.text
                opacity: hit.current ? 1 : (hit.pressed ? 0.15 : 0)
            }

            contentItem: Item {
                Kirigami.Icon {
                    id: hitIcon
                    visible: hit.e.kind !== "header"
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: visible ? search.metrics.px(hit.e.best ? 40 : search.cfg.listIconSize) : 0
                    height: width
                    source: hit.isHit ? search.roleData(hit.e.model, hit.e.row, "decoration") : "internet-web-browser"
                }
                Column {
                    anchors.left: hitIcon.right
                    anchors.leftMargin: hitIcon.visible ? search.metrics.px(12) : 0
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    PC3.Label {
                        visible: !!hit.e.best
                        text: i18n("Best match")
                        color: search.metrics.text
                        opacity: 0.7
                        font.family: search.metrics.font
                        font.pixelSize: Math.round(search.metrics.fontSize * 0.85)
                    }
                    PC3.Label {
                        width: parent.width
                        text: hit.e.kind === "header" ? hit.e.name
                            : hit.e.kind === "web" ? i18n("Search the web for \"%1\"", root.searchText)
                            : (search.roleData(hit.e.model, hit.e.row, "display") ?? "")
                        elide: Text.ElideRight
                        color: search.metrics.text
                        font.family: search.metrics.font
                        font.weight: hit.e.kind === "header" ? Font.DemiBold : Font.Normal
                        font.pixelSize: Math.round(search.metrics.fontSize * (hit.e.best ? 1.25 : 1))
                    }
                    PC3.Label {
                        readonly property string desc: hit.isHit ? (search.roleData(hit.e.model, hit.e.row, "description") ?? "") : ""
                        width: parent.width
                        visible: desc !== ""
                        text: desc
                        elide: Text.ElideRight
                        color: search.metrics.text
                        opacity: 0.6
                        font.family: search.metrics.font
                        font.pixelSize: Math.round(search.metrics.fontSize * 0.85)
                    }
                }
            }

            TapHandler {
                acceptedButtons: Qt.RightButton
                enabled: hit.isHit
                onTapped: point => {
                    const id = search.roleData(hit.e.model, hit.e.row, "favoriteId");
                    const own = id ? [root.isPinned(id)
                        ? { text: i18n("Unpin from Start"), icon: "window-unpin", run: () => root.unpin(id) }
                        : { text: i18n("Pin to Start"), icon: "window-pin", run: () => root.pin(id) }] : [];
                    search.contextMenu.show(hit, hit.e.model, hit.e.row, own, point.position.x, point.position.y);
                }
            }
        }
    }

    PC3.Label {
        anchors.centerIn: view
        visible: search.filter !== "web" && !root.runnerModel.querying && !search.rows.some(e => e.kind === "hit")
        text: i18n("No items match your search")
        color: search.metrics.text
        opacity: 0.6
    }
}
