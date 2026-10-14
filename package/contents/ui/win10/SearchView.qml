pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PC3
import org.kde.kirigami as Kirigami
import org.kde.kitemmodels as KItemModels

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
            if (cfg.groupResults && !rm.mergeResults) {
                out.push({ kind: "header", name: rm.data(rm.index(i, 0), Qt.DisplayRole) });
            }
            for (let r = 0; r < model.count; r++) {
                out.push({ kind: "hit", model: model, row: r });
            }
        }
        const first = out.findIndex(e => e.kind === "hit");
        if (first >= 0) {
            out[first].best = true;
            // Best match sits on top, above the first group header.
            if (first > 0) out.unshift(out.splice(first, 1)[0]);
        }
        if (cfg.showWebSearch && root.searchText.length > 0) {
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

    ListView {
        id: view
        anchors.top: search.showField ? field.bottom : parent.top
        anchors.topMargin: search.showField ? search.metrics.px(8) : 0
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
        visible: !root.runnerModel.querying && !search.rows.some(e => e.kind === "hit")
        text: i18n("No items match your search")
        color: search.metrics.text
        opacity: 0.6
    }
}
