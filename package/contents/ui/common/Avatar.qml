import QtQuick
import org.kde.kirigami as Kirigami

// Round user picture; a person icon when there is no picture.
Kirigami.ShadowedImage {
    id: avatar
    required property QtObject metrics
    required property var user      // KCoreAddons.KUser (Places.user)
    radius: width / 2
    color: Qt.alpha(metrics.text, 0.15)
    source: user.faceIconUrl
    sourceSize: Qt.size(width * 2, height * 2)
    fillMode: Image.PreserveAspectCrop
    Kirigami.Icon {
        anchors.centerIn: parent
        visible: avatar.status !== Image.Ready
        width: parent.width * 0.6
        height: width
        source: "user-identity"
        color: avatar.metrics.text
        isMask: true
    }
}
