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
    property bool cfg_xpTaskbarTheme
    property alias cfg_windowTheme: windowBox.checked
    property bool cfg_taskbarFollowsStyle
    property string cfg_taskbarTheme
    property alias cfg_taskbarColor: tbColor.color
    property alias cfg_taskbarAlpha: tbAlpha.value
    property alias cfg_taskbarRadius: tbRadius.value
    property alias cfg_taskbarLine: tbLine.checked
    property string cfg_taskbarImage
    property string cfg_taskbarImageMode
    property alias cfg_taskbarImageAlpha: tbImageAlpha.value
    property alias cfg_taskbarImageTint: tbImageTint.checked
    property string cfg_taskbarButtons
    property alias cfg_taskbarFocusedSolid: tbSolid.checked
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
        // T37: the two main switches, the same for every menu style.
        QQC2.CheckBox {
            text: i18n("Apply the theme to the taskbar")
            checked: page.cfg_menuStyle === "xp" ? page.cfg_xpTaskbarTheme : page.cfg_taskbarFollowsStyle
            onToggled: {   // one switch for both keys: XP Plasma Style (xpTaskbarTheme) and the T35 presets
                page.cfg_xpTaskbarTheme = checked;
                page.cfg_taskbarFollowsStyle = checked;
            }
            QQC2.ToolTip.visible: hovered
            QQC2.ToolTip.text: i18n("Taskbar colours and buttons that match the menu style. Your own Plasma Style comes back when this is off.")
        }
        QQC2.CheckBox {
            id: windowBox   // T26a/b, T37: main.qml windowDecoration() picks the theme per menu style
            text: i18n("Apply the theme to windows")
            QQC2.ToolTip.visible: hovered
            QQC2.ToolTip.text: i18n("Title bars and colours of every window. Your own ones come back when this is off.")
        }
        Item { Kirigami.FormData.isSection: true }
        QQC2.CheckBox {
            id: customBox
            enabled: !page.cfg_taskbarFollowsStyle
            text: i18n("Override the taskbar colour")
            checked: page.cfg_taskbarTheme === "custom"
            onToggled: page.cfg_taskbarTheme = checked ? "custom" : "off"
        }
        ColumnLayout {
            enabled: customBox.checked && !page.cfg_taskbarFollowsStyle
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
            enabled: customBox.checked && !page.cfg_taskbarFollowsStyle
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
        // T34: task button look in the generated tasks.svg (presets pick their own; "Plasma" keeps the style's)
        QQC2.ComboBox {
            enabled: customBox.checked && !page.cfg_taskbarFollowsStyle
            Kirigami.FormData.label: i18n("Task buttons:")
            textRole: "text"
            valueRole: "value"
            model: [{ value: "plasma", text: i18n("Plasma Style") }, { value: "win10", text: i18n("Windows 10 (bar under active)") },
                    { value: "win11", text: i18n("Windows 11 (pill under active)") }, { value: "win7", text: i18n("Windows 7 (glass)") }]
            Component.onCompleted: currentIndex = Math.max(0, indexOfValue(page.cfg_taskbarButtons))
            onActivated: page.cfg_taskbarButtons = currentValue
        }
        QQC2.CheckBox {
            id: tbSolid
            enabled: customBox.checked || page.cfg_taskbarFollowsStyle
            text: i18n("Paint the active button less transparent")
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
