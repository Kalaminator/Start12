import QtQuick
import QtQuick.Controls as QQC2

// A plain-text note on the tile. Saved into the tile prop "note" when the field loses focus or the menu closes
// (saving rewrites the tile list, which would drop focus mid-typing). The tile's drag area sits below this
// widget (z -1), so clicks reach the text; the margin around it still drags / opens the tile menu.
Item {
    id: w
    required property QtObject metrics
    required property string size
    required property bool active
    property var tdata: ({})
    property var save: function (key, value) {}

    function commit() { if (ta.text !== (w.tdata.note || "")) w.save("note", ta.text); }
    onActiveChanged: if (!active) commit()

    QQC2.TextArea {
        id: ta
        anchors.fill: parent
        anchors.margins: w.metrics.px(8)
        padding: 0
        background: null
        wrapMode: TextEdit.Wrap
        placeholderText: i18n("Write a note…")
        placeholderTextColor: Qt.alpha(w.metrics.text, 0.6)
        color: w.metrics.text
        selectionColor: w.metrics.text
        selectedTextColor: w.metrics.bg
        font.family: w.metrics.font
        font.pixelSize: Math.max(9, Math.round(w.metrics.px(w.size === "small" ? 9 : 12)))
        Component.onCompleted: text = w.tdata.note || ""
        onActiveFocusChanged: if (!activeFocus) w.commit()
        Keys.onEscapePressed: focus = false
    }
}
