import QtQuick
import org.kde.plasma.components as PC3
import org.kde.kirigami as Kirigami

// Search box bound to root.searchText; arrows and Enter drive the given SearchView.
PC3.TextField {
    id: box
    required property QtObject metrics
    required property Item results
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

    Keys.onDownPressed: results.step(1)
    Keys.onUpPressed: results.step(-1)
    Keys.onReturnPressed: results.activateCurrent()
    Keys.onEnterPressed: results.activateCurrent()
    Keys.onEscapePressed: root.searching ? root.searchText = "" : cancel()
}
