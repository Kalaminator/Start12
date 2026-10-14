import QtQuick
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PC3
import org.kde.kirigami as Kirigami

// Search box bound to root.searchText; arrows and Enter drive the given SearchView.
PC3.TextField {
    id: box
    required property QtObject metrics
    required property Item results
    property Item nav: null     // common/KeyNav of the style
    signal cancel()     // Esc with nothing typed ("escape" is not a legal signal name)

    text: root.searchText
    onTextEdited: root.searchText = text
    placeholderText: i18n("Search apps and files")
    font.family: metrics.font
    font.pixelSize: metrics.fontSize
    leftPadding: metrics.px(34)

    Kirigami.Icon {
        anchors.left: parent.left
        anchors.leftMargin: box.metrics.px(10)
        anchors.verticalCenter: parent.verticalCenter
        width: box.metrics.px(16)
        height: width
        source: "search"
        color: box.metrics.text
        isMask: true
    }

    // Recent searches under the empty, focused box; a click puts the query back.
    QQC2.Popup {
        y: box.height
        width: box.width
        padding: 0
        focus: false
        closePolicy: QQC2.Popup.NoAutoClose
        visible: box.activeFocus && box.text === "" && Plasmoid.configuration.searchHistoryEnabled && Plasmoid.configuration.searchHistory.length > 0
        contentItem: Column {
            Repeater {
                model: Plasmoid.configuration.searchHistory
                delegate: PC3.ItemDelegate {
                    required property string modelData
                    width: box.width
                    text: modelData
                    icon.name: "search"
                    onClicked: { root.searchText = modelData; box.forceActiveFocus(); }
                }
            }
        }
    }

    Keys.onPressed: event => {
        event.accepted = true;
        if (nav && nav.handle(event)) {
            // nothing typed: arrows/Tab/Enter move through the menu
        } else if (event.key === Qt.Key_Down || event.key === Qt.Key_Up) {
            results.step(event.key === Qt.Key_Down ? 1 : -1);
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            results.activateCurrent();
        } else if (event.key === Qt.Key_Escape) {
            root.searching ? root.searchText = "" : cancel();
        } else {
            event.accepted = false;
        }
    }
}
