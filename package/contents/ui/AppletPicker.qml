pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami
import org.kde.kitemmodels as KItemModels
import org.kde.plasma.private.shell as Shell

// "Add widget > KDE widgets…": searchable list of installed Plasma widgets (the shell's own
// WidgetExplorer model); picking one creates it as a child applet of Start12 (root.addApplet).
// ponytail: private plasma-workspace module, always there with plasmashell; no metadata.json fallback.
Window {
    id: picker
    property int group: 0
    readonly property alias explorer: explorer
    // Only widgets that make sense inside a Start menu tile (panel, tray, launcher, spacer, battery,
    // network... are left out). The list only shows installed widgets, so missing ones need no check.
    readonly property var allow: /^org\.kde\.(plasma\.(analogclock|digitalclock|fuzzyclock|binaryclock|calendar|weather|notes|systemmonitor(\..+)?|mediacontroller|timer|comic|mediaframe|colorpicker|calculator|fifteenpuzzle)|plasma_applet_dict|kdeconnect)$/

    function openFor(gi) {
        group = gi;
        search.text = "";
        show();
        requestActivate();
        search.forceActiveFocus();
    }
    function pick(plugin) {
        close();
        root.addApplet(plugin, group);
    }

    title: i18n("KDE widgets")
    width: Kirigami.Units.gridUnit * 22
    height: Kirigami.Units.gridUnit * 26
    color: Kirigami.Theme.backgroundColor

    Shell.WidgetExplorer {
        id: explorer
        containment: Plasmoid
    }
    KItemModels.KSortFilterProxyModel {
        id: filtered
        sourceModel: explorer.widgetsModel
        filterRoleName: "name"
        filterString: search.text
        filterCaseSensitivity: Qt.CaseInsensitive
        sortRoleName: "name"
    }
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.largeSpacing
        QQC2.TextField {
            id: search
            Layout.fillWidth: true
            placeholderText: i18n("Search widgets…")
            Keys.onEscapePressed: picker.close()
            Keys.onDownPressed: list.forceActiveFocus()
            onAccepted: if (list.count) list.itemAtIndex(Math.max(0, list.currentIndex))?.clicked()
        }
        QQC2.ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            ListView {
                id: list
                model: filtered
                clip: true
                keyNavigationEnabled: true
                Keys.onEscapePressed: picker.close()
                delegate: QQC2.ItemDelegate {
                    id: row
                    required property int index
                    required property var model
                    readonly property bool hidden: !picker.allow.test(model.pluginName)
                    width: ListView.view.width
                    height: hidden ? 0 : implicitHeight
                    visible: !hidden
                    highlighted: ListView.isCurrentItem
                    Keys.onReturnPressed: clicked()
                    onClicked: picker.pick(model.pluginName)
                    contentItem: RowLayout {
                        Kirigami.Icon {
                            source: row.model.decoration
                            Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                            Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                        }
                        ColumnLayout {
                            spacing: 0
                            Layout.fillWidth: true
                            QQC2.Label { text: row.model.name; Layout.fillWidth: true; elide: Text.ElideRight }
                            QQC2.Label {
                                text: row.model.description || ""
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                                opacity: 0.7
                                font: Kirigami.Theme.smallFont
                            }
                        }
                    }
                }
            }
        }
    }
}
