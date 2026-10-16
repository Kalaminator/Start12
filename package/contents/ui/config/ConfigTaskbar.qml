import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import QtQuick.Dialogs as Dialogs
import org.kde.kirigami as Kirigami
import "../code/tiles.js" as Tiles
import org.kde.kcmutils as KCM
import org.kde.kquickcontrols as KQuickControls
import org.kde.plasma.plasma5support as P5Support

// Taskbar page: the generated Plasma Style keys (T29-T35) plus shortcuts to what stock Plasma covers.
KCM.SimpleKCM {
    id: page
    property string cfg_menuStyle   // read only, to show the XP option
    property bool cfg_xpTaskbarTheme
    property alias cfg_xpFirefoxTitlebar: ffBox.checked
    property alias cfg_windowTheme: windowBox.checked
    property alias cfg_windowOpacity: winAlpha.value
    property alias cfg_windowBlur: winBlur.checked
    property int cfg_windowRadius
    property int cfg_titleHeight
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
    property alias cfg_taskbarHiding: tbHiding.currentIndex
    property alias cfg_taskbarFloating: w12Float.checked
    property alias cfg_taskbarPopAnim: w12Pop.currentIndex
    property alias cfg_taskbarRound: w12Round.value
    property string cfg_taskbarLayout
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
        QQC2.CheckBox {
            id: ffBox
            visible: page.cfg_menuStyle === "xp"
            text: i18n("Use the system title bar in Firefox with XP themes")
            QQC2.ToolTip.visible: hovered
            QQC2.ToolTip.text: i18n("Firefox draws its own title bar, so the XP one does not show. Restart Firefox for this to take effect.")
        }
        // T41: glass options for the windowTheme decoration (main.qml glassSuffix), every style.
        ColumnLayout {
            enabled: windowBox.checked
            Kirigami.FormData.label: i18n("Window frames:")
            RowLayout {
                QQC2.Slider { id: winAlpha; from: 30; to: 100; stepSize: 5 }
                QQC2.Label { text: i18n("%1% opaque", Math.round(winAlpha.value)) }
            }
            QQC2.CheckBox { id: winBlur; enabled: winAlpha.value < 100; text: i18n("Blur behind translucent frames") }
            RowLayout {
                QQC2.CheckBox {
                    id: ownRadius
                    text: i18n("Corner radius:")
                    checked: page.cfg_windowRadius >= 0
                    onToggled: page.cfg_windowRadius = checked ? radiusSpin.value : -1
                }
                QQC2.SpinBox {
                    id: radiusSpin
                    enabled: ownRadius.checked
                    from: 0
                    to: 12
                    value: Math.max(0, page.cfg_windowRadius < 0 ? 8 : page.cfg_windowRadius)
                    textFromValue: v => v === 0 ? i18n("Square") : v + " px"
                    valueFromText: t => parseInt(t) || 0
                    onValueModified: page.cfg_windowRadius = value
                }
            }
            RowLayout {
                QQC2.CheckBox {
                    id: ownTitle
                    text: i18n("Title bar height:")
                    checked: page.cfg_titleHeight > 0
                    onToggled: page.cfg_titleHeight = checked ? titleSpin.value : 0
                }
                QQC2.SpinBox {
                    id: titleSpin
                    enabled: ownTitle.checked
                    from: 20
                    to: 48
                    value: page.cfg_titleHeight > 0 ? page.cfg_titleHeight : 30
                    textFromValue: v => v + " px"
                    valueFromText: t => parseInt(t) || 30
                    onValueModified: page.cfg_titleHeight = value
                }
            }
        }
        // W4: Windows 12 taskbar group (floating bar, corners, colour, layout)
        ColumnLayout {
            visible: page.cfg_menuStyle === "windows12"
            Kirigami.FormData.label: i18n("Windows 12 taskbar:")
            QQC2.CheckBox { id: w12Float; text: i18n("Floating bar") }
            // W7: floating = auto-hidden over full-screen windows (Auto-hide Off); pop-up animation = KWin effect
            RowLayout {
                enabled: w12Float.checked
                QQC2.Label { text: i18n("Taskbar pop-up animation:") }
                QQC2.ComboBox { id: w12Pop; model: [i18n("Slide (Plasma)"), i18n("Fade"), i18n("Zoom"), i18n("Rise")] }
            }
            RowLayout {
                QQC2.Label { text: i18n("Square") }
                QQC2.Slider { id: w12Round; from: 0; to: 100; stepSize: 1 }
                QQC2.Label { text: i18n("Round") }
            }
            RowLayout {
                enabled: customBox.checked && !page.cfg_taskbarFollowsStyle
                QQC2.Label { text: i18n("Bar colour:") }
                KQuickControls.ColorButton {
                    showAlphaChannel: false
                    color: page.cfg_taskbarColor
                    onColorChanged: if (color != page.cfg_taskbarColor) page.cfg_taskbarColor = color
                }
                QQC2.Slider {
                    from: 0; to: 100; stepSize: 1
                    value: page.cfg_taskbarAlpha
                    onMoved: page.cfg_taskbarAlpha = value
                }
                QQC2.Label { text: i18n("%1% opaque", page.cfg_taskbarAlpha) }
            }
            QQC2.Label {
                text: i18n("Colour and opacity follow \"Override the taskbar colour\" below.")
                enabled: false
            }
            QQC2.ComboBox {
                id: w12Layout
                readonly property var values: ["single", "split-left", "split-right"]
                model: [i18n("One bar"), i18n("Widgets left, tray right"), i18n("Start left, tray right")]
                currentIndex: Math.max(0, values.indexOf(page.cfg_taskbarLayout))
                onActivated: page.cfg_taskbarLayout = values[currentIndex]
            }
            QQC2.Label {
                text: i18n("Islands are extra Plasma panels holding the tray, clock and a new weather widget; One bar puts everything back.")
                enabled: false
            }
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
        // native panel visibility (panel.hiding); Off = the user's own setting is put back
        QQC2.ComboBox {
            id: tbHiding
            Kirigami.FormData.label: i18n("Auto-hide:")
            model: [i18n("Off"), i18n("Hide when a window covers it"), i18n("Always auto-hide")]
        }
        QQC2.Label {
            text: i18n("A hidden taskbar shows again when the mouse touches the screen edge.")
            enabled: false
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
            onClicked: page.run("" + Tiles.QDBUS + " org.kde.plasmashell /PlasmaShell org.freedesktop.DBus.Properties.Set org.kde.PlasmaShell editMode true")
        }
    }
}
