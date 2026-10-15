import QtQuick
import Qt.labs.folderlistmodel

// One picture, or a slideshow of a folder (tile prop photo = "/file.jpg" or "dir:/folder"); changes every 10 s while the menu is open.
Item {
    id: w
    required property QtObject metrics
    required property string size
    required property bool active
    property var tdata: ({})
    property var save: function (key, value) {}

    readonly property string photo: tdata.photo || ""
    readonly property bool isDir: photo.startsWith("dir:")
    property int index: 0
    readonly property string current: !photo ? "" : !isDir ? "file://" + photo
        : (list.count > 0 ? "file://" + list.get(index % list.count, "filePath") : "")

    FolderListModel {
        id: list
        folder: w.isDir ? "file://" + w.photo.substring(4) : ""
        nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.bmp", "*.gif", "*.PNG", "*.JPG", "*.JPEG", "*.WEBP"]
        showDirs: false
        sortField: FolderListModel.Name
    }
    Timer {
        interval: 10000; repeat: true; running: w.active && w.isDir && list.count > 1
        onTriggered: w.index = (w.index + 1) % list.count
    }

    Image { id: back; anchors.fill: parent; fillMode: Image.PreserveAspectCrop; asynchronous: true }
    Image {
        id: front
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        opacity: 0
        NumberAnimation on opacity { id: fade; running: false; from: 0; to: 1; duration: 700 }
        onStatusChanged: if (status === Image.Ready) { fade.restart(); }
    }
    onCurrentChanged: {
        back.source = front.source;
        front.opacity = 0;
        front.source = current;
    }
    Component.onCompleted: front.source = current

    Text {
        visible: !w.photo
        anchors.centerIn: parent
        width: parent.width - w.metrics.px(12)
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        text: i18n("Right-click to choose a picture or folder")
        color: w.metrics.text
        opacity: 0.85
        font.family: w.metrics.font
        font.pixelSize: Math.max(8, Math.round(Math.min(w.width, w.height) * 0.12))
    }
}
