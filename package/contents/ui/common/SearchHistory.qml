import QtQuick
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PC3

// Recent searches (T18) under (or above) a search field; a click puts the query back.
// Empty field: the whole history. suggest: also while typing, the entries that start with the text.
QQC2.Popup {
    id: pop
    required property Item field
    property bool above: false      // field at the bottom of the menu (Win7)
    property bool suggest: false    // SearchView field: it only shows while something is typed

    readonly property string typed: field.text.toLowerCase()
    readonly property var items: Plasmoid.configuration.searchHistoryEnabled
        ? Array.from(Plasmoid.configuration.searchHistory).filter(q =>
              typed === "" || (suggest && q.toLowerCase().startsWith(typed) && q.toLowerCase() !== typed))
        : []

    y: above ? -height : field.height
    width: field.width
    padding: 0
    focus: false
    closePolicy: QQC2.Popup.NoAutoClose
    visible: field.visible && field.activeFocus && items.length > 0 && (suggest || typed === "")
    contentItem: Column {
        Repeater {
            model: pop.items
            delegate: PC3.ItemDelegate {
                required property string modelData
                width: pop.width
                text: modelData
                icon.name: "search"
                onClicked: { root.searchText = modelData; pop.field.forceActiveFocus(); }
            }
        }
    }
}
