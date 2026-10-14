pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

// Start11Config "Configure menu": tiles and the apps list (Windows 10 style).
KCM.SimpleKCM {
    id: page
    property alias cfg_tileColumns: columns.value
    property alias cfg_tileGap: gap.value
    property alias cfg_tileIconScale: tileIcon.value
    property alias cfg_hideTileText: hideText.checked
    property alias cfg_tilesLocked: locked.checked
    property alias cfg_listIconSize: listIcon.value
    property alias cfg_listRowHeight: rowHeight.value
    property alias cfg_showRecentlyAdded: recent.checked
    property alias cfg_showMostUsed: mostUsed.checked
    property alias cfg_categoryFolders: folders.checked
    property alias cfg_foldersAtBottom: foldersBottom.checked
    property alias cfg_highlightNew: highlightNew.checked
    property alias cfg_hideAppList: hideList.checked

    Kirigami.FormLayout {
        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Tiles") }

        QQC2.SpinBox {
            id: columns
            Kirigami.FormData.label: i18n("Show icons as tiles split into:")
            from: 3
            to: 8
            textFromValue: v => i18np("%1 column", "%1 columns", v)
        }
        QQC2.SpinBox {
            id: gap
            Kirigami.FormData.label: i18n("Space between tiles:")
            from: 0
            to: 16
            textFromValue: v => v + " px"
            valueFromText: t => parseInt(t) || 0
        }
        RowLayout {
            Kirigami.FormData.label: i18n("Tile icon size:")
            QQC2.Slider { id: tileIcon; from: 25; to: 90; stepSize: 1 }
            QQC2.Label { text: Math.round(tileIcon.value) + " %" }
        }
        QQC2.CheckBox { id: hideText; text: i18n("Hide caption on tiles (show it as a tooltip)") }
        QQC2.CheckBox { id: locked; text: i18n("Lock menu shortcut positions") }

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Apps list") }

        QQC2.CheckBox { id: hideList; text: i18n("Hide the apps list (tiles only)") }
        QQC2.SpinBox {
            id: listIcon
            Kirigami.FormData.label: i18n("Shortcut icons should be sized:")
            enabled: !hideList.checked
            from: 12
            to: 64
            textFromValue: v => v + " px"
            valueFromText: t => parseInt(t) || 22
        }
        QQC2.SpinBox {
            id: rowHeight
            Kirigami.FormData.label: i18n("Row height:")
            enabled: !hideList.checked
            from: 20
            to: 80
            textFromValue: v => v + " px"
            valueFromText: t => parseInt(t) || 36
        }
        QQC2.CheckBox { id: recent; enabled: !hideList.checked; text: i18n("Show recently added apps") }
        QQC2.CheckBox { id: mostUsed; enabled: !hideList.checked; text: i18n("Show my most used applications") }
        QQC2.CheckBox { id: highlightNew; enabled: !hideList.checked; text: i18n("Highlight new applications") }
        QQC2.CheckBox { id: folders; enabled: !hideList.checked; text: i18n("Show app categories as folders") }
        QQC2.CheckBox { id: foldersBottom; enabled: !hideList.checked && folders.checked; text: i18n("Place folders at the bottom of the list") }
    }
}
