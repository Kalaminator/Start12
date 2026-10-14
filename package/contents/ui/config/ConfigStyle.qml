pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.kquickcontrols as KQuickControls

// Start11Config "Start Menu" page: "Which style of Start Menu would you prefer?"
KCM.SimpleKCM {
    id: page
    property string cfg_menuStyle
    property alias cfg_menuSize: sizeBox.currentIndex
    property alias cfg_menuHeight: heightSpin.value
    property real cfg_uiScale
    property alias cfg_win7Substyle: subBox.currentIndex
    property alias cfg_modernSubstyle: modernSubBox.currentIndex
    property string cfg_xpSubstyle
    property alias cfg_xpTaskbarTheme: xpTaskbarBox.checked
    property alias cfg_xpStartGreen: xpStartGreenBox.checked
    property string cfg_xpColor
    property alias cfg_xpCustomColor: xpCustom.color
    property string cfg_resetRequest

    readonly property var built: ["windows7", "modern", "windows10", "windows11", "app", "pro", "launcher", "xp"]
    readonly property var styles: [
        ["windows7", i18n("Windows 7 style"), i18n("The classic Windows 7 menu.")],
        ["modern", i18n("Modern style"), i18n("An updated Windows 7 style.")],
        ["windows10", i18n("Windows 10 style"), i18n("Windows 10 style with improvements.")],
        ["windows11", i18n("Windows 11 style"), i18n("Windows 11 style with improvements.")],
        ["app", i18n("Windows App style"), i18n("Shortcuts at the top, groups and tabs, all apps always open.")],
        ["pro", i18n("Windows Pro style"), i18n("Two-tone: pinned apps, and a places panel on the right.")],
        ["launcher", i18n("Windows Launcher style"), i18n("Big account picture, search, and a large pinned grid.")],
        ["xp", i18n("Windows XP style"), i18n("The blue Luna menu, classic or modernised.")]
    ]

    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing

        Kirigami.Heading {
            level: 2
            text: i18n("Which style of Start Menu would you prefer?")
        }

        Flow {
            Layout.fillWidth: true
            spacing: Kirigami.Units.largeSpacing

            Repeater {
                model: page.styles
                delegate: QQC2.ItemDelegate {
                    id: card
                    required property var modelData
                    readonly property bool ready: page.built.includes(modelData[0])
                    readonly property bool chosen: page.cfg_menuStyle === modelData[0]
                    width: Kirigami.Units.gridUnit * 11
                    height: Kirigami.Units.gridUnit * 11
                    enabled: ready
                    highlighted: chosen
                    onClicked: page.cfg_menuStyle = modelData[0]

                    contentItem: ColumnLayout {
                        StylePreview {
                            Layout.fillWidth: true
                            Layout.preferredHeight: Kirigami.Units.gridUnit * 6.5
                            styleId: card.modelData[0]
                            opacity: card.ready ? 1 : 0.4
                        }
                        QQC2.Label {
                            Layout.fillWidth: true
                            text: card.modelData[1]
                            font.bold: card.chosen
                            elide: Text.ElideRight
                        }
                        QQC2.Label {
                            Layout.fillWidth: true
                            text: card.ready ? card.modelData[2] : i18n("Coming soon")
                            opacity: 0.7
                            font: Kirigami.Theme.smallFont
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }

        Kirigami.FormLayout {
            Layout.fillWidth: true

            QQC2.ComboBox {
                id: subBox
                visible: page.cfg_menuStyle === "windows7"
                Kirigami.FormData.label: i18n("Substyle:")
                model: [i18n("Windows 7 style"), i18n("Windows 7 style with icons"), i18n("Compact Windows 7 style"),
                        i18n("Grid Windows 7 style"), i18n("Grid Windows 7 style with icons"), i18n("Compact Grid Windows 7 style")]
            }
            QQC2.ComboBox {
                id: modernSubBox
                visible: page.cfg_menuStyle === "modern"
                Kirigami.FormData.label: i18n("Substyle:")
                model: [i18n("Modern style"), i18n("Modern style with icons"), i18n("Compact Modern style"),
                        i18n("Grid Modern style"), i18n("Grid Modern style with icons"), i18n("Compact Grid Modern style")]
            }
            QQC2.ComboBox {
                visible: page.cfg_menuStyle === "xp"
                Kirigami.FormData.label: i18n("Substyle:")
                model: [i18n("Classic Windows XP style"), i18n("Modern Windows XP style")]
                currentIndex: page.cfg_xpSubstyle === "modern" ? 1 : 0
                onActivated: index => page.cfg_xpSubstyle = index === 1 ? "modern" : "classic"
            }
            RowLayout {
                visible: page.cfg_menuStyle === "xp"
                Kirigami.FormData.label: i18n("Colour scheme:")
                QQC2.ComboBox {
                    readonly property var keys: ["blue", "olive", "silver", "custom"]
                    model: [i18n("Blue"), i18n("Olive Green"), i18n("Silver"), i18n("Custom")]
                    currentIndex: Math.max(0, keys.indexOf(page.cfg_xpColor))
                    onActivated: index => page.cfg_xpColor = keys[index]
                }
                KQuickControls.ColorButton { id: xpCustom; visible: page.cfg_xpColor === "custom"; showAlphaChannel: false }
            }
            QQC2.CheckBox {
                id: xpTaskbarBox
                visible: page.cfg_menuStyle === "xp"
                text: i18n("Apply matching XP taskbar theme")
            }
            QQC2.CheckBox {
                id: xpStartGreenBox
                visible: page.cfg_menuStyle === "xp"
                text: i18n("Green XP Start button")
            }
            QQC2.ComboBox {
                id: sizeBox
                Kirigami.FormData.label: i18n("What size should it be?")
                model: [i18n("Small"), i18n("Tall"), i18n("Wide (two tile columns)"), i18n("Large (two tile columns)")]
            }
            QQC2.SpinBox {
                id: heightSpin
                Kirigami.FormData.label: i18n("Custom height:")
                from: 0
                to: 1600
                stepSize: 20
                textFromValue: v => v === 0 ? i18n("From size") : v + " px"
                valueFromText: t => parseInt(t) || 0
            }
            RowLayout {
                Kirigami.FormData.label: i18n("Adjust global menu scaling:")
                QQC2.Slider {
                    id: scaleSlider
                    from: 50
                    to: 200
                    stepSize: 5
                    value: page.cfg_uiScale * 100
                    onMoved: page.cfg_uiScale = value / 100
                }
                QQC2.Label {
                    text: i18n("%1% of original size", Math.round(scaleSlider.value))
                }
            }
        }

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Reset") }
        QQC2.Button {
            text: i18n("Reset all Start12 settings…")
            icon.name: "edit-reset"
            onClicked: allDialog.open()
        }
    }

    Kirigami.PromptDialog {
        id: allDialog
        title: i18n("Reset all Start12 settings?")
        subtitle: i18n("Every setting, tile and pinned icon goes back to the fresh-install default. If the XP taskbar theme is active, your previous Plasma Style is put back. Press OK/Apply in the settings window afterwards to finish.")
        standardButtons: Kirigami.Dialog.Ok | Kirigami.Dialog.Cancel
        onAccepted: page.cfg_resetRequest = "all|" + Date.now()
    }
}
