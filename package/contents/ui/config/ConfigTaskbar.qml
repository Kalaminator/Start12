import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import QtQuick.Dialogs as Dialogs
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.kquickcontrols as KQuickControls
import org.kde.plasma.plasma5support as P5Support

// Taskbar page: the generated Plasma Style keys (T29-T35) plus shortcuts to what stock Plasma covers.
KCM.SimpleKCM {
    id: page
    property string cfg_menuStyle   // read only, to show the XP option
    property alias cfg_xpTaskbarTheme: xpTaskbarBox.checked
    property alias cfg_taskbarFollowsStyle: followBox.checked
    property string cfg_taskbarTheme
    property alias cfg_taskbarColor: tbColor.color
    property alias cfg_taskbarAlpha: tbAlpha.value
    property alias cfg_taskbarRadius: tbRadius.value
    property alias cfg_taskbarLine: tbLine.checked
    property string cfg_taskbarImage
    property string cfg_taskbarImageMode
    property alias cfg_taskbarImageAlpha: tbImageAlpha.value
    property alias cfg_taskbarImageTint: tbImageTint.checked
    property alias cfg_taskbarSearch: searchBox.checked
    property alias cfg_taskbarSearchWidth: searchWidth.value

    P5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []
        onNewData: sourceName => disconnectSource(sourceName)
    }
    function run(cmd) { executable.connectSource(cmd); }

    Dialogs.FileDialog {
        id: tbImageFile
        title: i18n("Pick taskbar texture…")
        nameFilters: [i18n("Images (*.png *.jpg *.jpeg)")]
        onAccepted: page.cfg_taskbarImage = decodeURIComponent(selectedFile.toString().replace("file://", ""))
    }

    Kirigami.FormLayout {
        QQC2.CheckBox {
            id: xpTaskbarBox
            visible: page.cfg_menuStyle === "xp"
            text: i18n("Apply matching XP taskbar theme")
        }
        QQC2.CheckBox {
            id: followBox
            text: i18n("Taskbar follows the menu style")
        }
        QQC2.CheckBox {
            id: customBox
            enabled: !followBox.checked
            text: i18n("Override the taskbar colour")
            checked: page.cfg_taskbarTheme === "custom"
            onToggled: page.cfg_taskbarTheme = checked ? "custom" : "off"
        }
        ColumnLayout {
            enabled: customBox.checked && !followBox.checked
            Kirigami.FormData.label: i18n("Custom taskbar:")
            KQuickControls.ColorButton { id: tbColor; showAlphaChannel: false }
            RowLayout {
                QQC2.Slider { id: tbAlpha; from: 0; to: 100; stepSize: 1 }
                QQC2.Label { text: i18n("%1% opaque", Math.round(tbAlpha.value)) }
            }
            QQC2.SpinBox {
                id: tbRadius
                from: 2
                to: 24
                textFromValue: v => v <= 2 ? i18n("Square") : v + " px"
                valueFromText: t => parseInt(t) || 2
            }
            QQC2.CheckBox { id: tbLine; text: i18n("Light line on the taskbar edge") }
        }
        // T33: texture drawn inside the generated panel background (xptheme.py image=...)
        ColumnLayout {
            enabled: customBox.checked && !followBox.checked
            Kirigami.FormData.label: i18n("Texture:")
            RowLayout {
                QQC2.Label { text: page.cfg_taskbarImage ? page.cfg_taskbarImage.split("/").pop() : i18n("None") }
                QQC2.Button { text: i18n("Pick image…"); icon.name: "document-open"; onClicked: tbImageFile.open() }
                QQC2.Button { icon.name: "edit-clear"; visible: page.cfg_taskbarImage !== ""; onClicked: page.cfg_taskbarImage = "" }
            }
            ColumnLayout {
                enabled: page.cfg_taskbarImage !== ""
                QQC2.ComboBox {
                    textRole: "text"
                    valueRole: "value"
                    model: [{ value: "tile", text: i18n("Tile") }, { value: "stretch", text: i18n("Stretch") },
                            { value: "top", text: i18n("Align top") }, { value: "middle", text: i18n("Align middle") },
                            { value: "bottom", text: i18n("Align bottom") }]
                    Component.onCompleted: currentIndex = Math.max(0, indexOfValue(page.cfg_taskbarImageMode))
                    onActivated: page.cfg_taskbarImageMode = currentValue
                }
                RowLayout {
                    QQC2.Slider { id: tbImageAlpha; from: 0; to: 100; stepSize: 1 }
                    QQC2.Label { text: i18n("%1% opaque", Math.round(tbImageAlpha.value)) }
                }
                QQC2.CheckBox { id: tbImageTint; text: i18n("Tint with the accent colour") }
            }
        }

        Item { Kirigami.FormData.isSection: true }
        QQC2.CheckBox {
            id: searchBox
            Kirigami.FormData.label: i18n("Search:")
            text: i18n("Show search on taskbar")
        }
        QQC2.SpinBox {
            id: searchWidth
            enabled: searchBox.checked
            Kirigami.FormData.label: i18n("Search box width:")
            from: 100
            to: 600
            stepSize: 10
            textFromValue: v => v + " px"
            valueFromText: t => parseInt(t) || 220
        }

        Item { Kirigami.FormData.isSection: true }
        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            text: i18n("Panel height, position, floating, auto-hide and task grouping are handled by Plasma itself.")
        }
        QQC2.Button {
            Kirigami.FormData.label: i18n("Plasma settings:")
            icon.name: "configure-toolbars"
            text: i18n("Edit panel…")
            // Plasma 6.7 has no "edit mode" shortcut; the shell's editMode D-Bus property works.
            // (Task manager settings can't be opened by script: right-click the taskbar for them.)
            onClicked: page.run("qdbus6 org.kde.plasmashell /PlasmaShell org.freedesktop.DBus.Properties.Set org.kde.PlasmaShell editMode true")
        }
    }
}
