pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import QtQuick.Dialogs as Dialogs
import Qt.labs.folderlistmodel
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.kquickcontrols as KQuickControls
import org.kde.iconthemes as KIconThemes

// Start11Config "Start Button" page.
KCM.SimpleKCM {
    id: page
    property int cfg_buttonMode
    property string cfg_buttonImage
    property string cfg_buttonIcon
    property alias cfg_buttonIconScale: iconScale.value
    property alias cfg_squaresColor: squaresColor.color
    property alias cfg_squaresAccent: squaresAccent.color
    property var cfg_buttonMenuItems: []

    readonly property var menuChoices: [
        ["settings", i18n("Settings")], ["files", i18n("File Explorer")], ["monitor", i18n("System Monitor")],
        ["terminal", i18n("Terminal")], ["run", i18n("Run…")], ["desktop", i18n("Show desktop")], ["editpanel", i18n("Edit panel")], ["autohide", i18n("Auto-hide panel")], ["power", i18n("Lock, sign out, sleep, restart, shut down")]
    ]

    FolderListModel {
        id: buttons
        folder: Qt.resolvedUrl("../../images/StartButtons/")
        nameFilters: ["*.png"]
        showDirs: false
    }

    KIconThemes.IconDialog {
        id: iconDialog
        onIconNameChanged: name => page.cfg_buttonIcon = name
    }
    Dialogs.FileDialog {
        id: imageFile
        title: i18n("Pick custom image…")
        nameFilters: [i18n("Images (*.png *.svg *.jpg *.webp)")]
        onAccepted: {
            const path = decodeURIComponent(selectedFile.toString().replace("file://", ""));
            if (page.cfg_buttonMode === 0) page.cfg_buttonImage = path;
            else page.cfg_buttonIcon = path;
        }
    }

    Kirigami.FormLayout {
        ColumnLayout {
            Kirigami.FormData.label: i18n("What should the Start button look like?")
            QQC2.RadioButton { text: i18n("Icon"); checked: page.cfg_buttonMode === 2; onToggled: page.cfg_buttonMode = 2 }
            QQC2.RadioButton { text: i18n("Start11 button image"); checked: page.cfg_buttonMode === 0; onToggled: page.cfg_buttonMode = 0 }
            QQC2.RadioButton { text: i18n("Four squares"); checked: page.cfg_buttonMode === 1; onToggled: page.cfg_buttonMode = 1 }
        }

        // ---- Icon ----
        RowLayout {
            visible: page.cfg_buttonMode === 2
            Kirigami.FormData.label: i18n("Icon:")
            QQC2.Button {
                icon.source: page.cfg_buttonIcon === "" ? Qt.resolvedUrl("../../images/StartIcon.svg")
                    : page.cfg_buttonIcon.startsWith("/") ? "file://" + page.cfg_buttonIcon : page.cfg_buttonIcon
                text: page.cfg_buttonIcon === "" ? i18n("Arch Linux (default)") : page.cfg_buttonIcon.split("/").pop()
                onClicked: iconDialog.open()
            }
            QQC2.Button { text: i18n("Pick custom image…"); icon.name: "document-open"; onClicked: imageFile.open() }
            QQC2.Button {
                visible: page.cfg_buttonIcon !== ""
                text: i18n("Reset icon")
                icon.name: "edit-undo"
                onClicked: page.cfg_buttonIcon = ""
            }
        }
        RowLayout {
            visible: page.cfg_buttonMode === 2
            Kirigami.FormData.label: i18n("Icon size:")
            QQC2.Slider { id: iconScale; from: 30; to: 100; stepSize: 1 }
            QQC2.Label { text: Math.round(iconScale.value) + " %" }
        }

        // ---- Image sheet: shows frame 0 (normal) of each 3-frame image ----
        GridLayout {
            visible: page.cfg_buttonMode === 0
            Kirigami.FormData.label: i18n("Image:")
            columns: 6
            Repeater {
                model: buttons
                delegate: QQC2.Button {
                    id: b
                    required property string fileName
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 3.5
                    Layout.preferredHeight: Kirigami.Units.gridUnit * 3.5
                    checkable: true
                    checked: page.cfg_buttonImage === fileName
                    onClicked: page.cfg_buttonImage = fileName
                    QQC2.ToolTip.text: fileName.replace(".png", "")
                    QQC2.ToolTip.visible: hovered
                    contentItem: Item {
                        clip: true
                        Image {
                            anchors.horizontalCenter: parent.horizontalCenter
                            source: Qt.resolvedUrl("../../images/StartButtons/" + b.fileName)
                            readonly property real k: Math.min(parent.width / Math.max(1, sourceSize.width),
                                                               parent.height / Math.max(1, sourceSize.height / 3))
                            width: sourceSize.width * k
                            height: sourceSize.height * k
                            y: (parent.height - height / 3) / 2
                            smooth: true
                            mipmap: true
                        }
                    }
                }
            }
        }
        QQC2.Button {
            visible: page.cfg_buttonMode === 0
            text: page.cfg_buttonImage.startsWith("/") ? page.cfg_buttonImage.split("/").pop() : i18n("Use a custom start button image…")
            icon.name: "document-open"
            onClicked: imageFile.open()
        }
        QQC2.Label {
            visible: page.cfg_buttonMode === 0
            text: i18n("Custom images hold 3 pictures stacked top to bottom: normal, mouse over, pressed.")
            opacity: 0.7
            font: Kirigami.Theme.smallFont
            wrapMode: Text.WordWrap
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
        }

        // ---- Squares ----
        RowLayout {
            visible: page.cfg_buttonMode === 1
            Kirigami.FormData.label: i18n("Colours:")
            KQuickControls.ColorButton { id: squaresAccent; showAlphaChannel: false }
            KQuickControls.ColorButton { id: squaresColor; showAlphaChannel: false }
        }

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Right click menu") }

        Repeater {
            model: page.menuChoices
            delegate: QQC2.CheckBox {
                required property var modelData
                text: modelData[1]
                checked: page.cfg_buttonMenuItems.includes(modelData[0])
                onToggled: {
                    const set = new Set(page.cfg_buttonMenuItems);
                    checked ? set.add(modelData[0]) : set.delete(modelData[0]);
                    page.cfg_buttonMenuItems = page.menuChoices.map(c => c[0]).filter(x => set.has(x));
                }
            }
        }
    }
}
