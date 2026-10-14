pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.iconthemes as KIconThemes

// Start11 "Left hand side shortcuts" + "Power menu options".
KCM.SimpleKCM {
    id: page
    property alias cfg_railMode: modeBox.currentIndex
    property alias cfg_railIconSize: iconSize.value
    property var cfg_railItems: []
    property var cfg_powerItems: []
    property string cfg_powerButtonAction

    readonly property var builtins: ({
        "user": [i18n("User picture"), "user-identity"],
        "documents": [i18n("Documents"), "folder-documents"],
        "downloads": [i18n("Downloads"), "folder-download"],
        "music": [i18n("Music"), "folder-music"],
        "pictures": [i18n("Pictures"), "folder-pictures"],
        "videos": [i18n("Videos"), "folder-videos"],
        "home": [i18n("Personal folder"), "user-home"],
        "network": [i18n("Network"), "network-workgroup"],
        "files": [i18n("File Explorer"), "system-file-manager"],
        "personalization": [i18n("Personalization"), "preferences-desktop-theme-global"],
        "settings": [i18n("Settings"), "configure"],
        "terminal": [i18n("Terminal"), "utilities-terminal"],
        "monitor": [i18n("System Monitor"), "utilities-system-monitor"],
        "run": [i18n("Run…"), "system-run"],
        "start12": [i18n("Start12 Settings"), "configure"],
        "power": [i18n("Power"), "system-shutdown"]
    })
    readonly property var powerChoices: [
        ["lock-screen", i18n("Lock")], ["logout", i18n("Sign out")], ["switch-user", i18n("Switch user")],
        ["suspend", i18n("Sleep")], ["hibernate", i18n("Hibernate")], ["reboot", i18n("Restart")],
        ["shutdown", i18n("Shut down")]
    ]

    function label(id) {
        return id.startsWith("custom|") ? id.split("|")[1] : (builtins[id] ? builtins[id][0] : id);
    }
    function iconOf(id) {
        return id.startsWith("custom|") ? (id.split("|")[2] || "folder") : (builtins[id] ? builtins[id][1] : "");
    }
    function move(i, d) {
        const l = cfg_railItems.slice();
        if (i + d < 0 || i + d >= l.length) return;
        [l[i], l[i + d]] = [l[i + d], l[i]];
        cfg_railItems = l;
    }
    function removeAt(i) {
        const l = cfg_railItems.slice();
        l.splice(i, 1);
        cfg_railItems = l;
    }
    function add(id) {
        // New items go just above "Power", like Start11's list.
        const l = cfg_railItems.slice();
        const p = l.indexOf("power");
        l.splice(p >= 0 ? p : l.length, 0, id);
        cfg_railItems = l;
    }

    Kirigami.FormLayout {
        QQC2.ComboBox {
            id: modeBox
            Kirigami.FormData.label: i18n("Decide how shortcut icons look:")
            model: [i18n("Only show icons"), i18n("Show names when the mouse is over it"), i18n("Always show icons and names")]
        }
        QQC2.SpinBox {
            id: iconSize
            Kirigami.FormData.label: i18n("Icon size:")
            from: 12
            to: 48
            textFromValue: v => v + " px"
            valueFromText: t => parseInt(t) || 18
        }

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Left hand side shortcuts") }

        ColumnLayout {
            Kirigami.FormData.label: i18n("Top to bottom:")
            Layout.minimumWidth: Kirigami.Units.gridUnit * 20
            Repeater {
                model: page.cfg_railItems
                delegate: RowLayout {
                    id: entry
                    required property string modelData
                    required property int index
                    Kirigami.Icon { source: page.iconOf(entry.modelData); Layout.preferredWidth: Kirigami.Units.iconSizes.small; Layout.preferredHeight: Layout.preferredWidth }
                    QQC2.Label { text: page.label(entry.modelData); Layout.fillWidth: true }
                    QQC2.ToolButton { icon.name: "arrow-up"; enabled: entry.index > 0; onClicked: page.move(entry.index, -1) }
                    QQC2.ToolButton { icon.name: "arrow-down"; enabled: entry.index < page.cfg_railItems.length - 1; onClicked: page.move(entry.index, 1) }
                    QQC2.ToolButton { icon.name: "list-remove"; onClicked: page.removeAt(entry.index) }
                }
            }
            RowLayout {
                QQC2.ComboBox {
                    id: addBox
                    Layout.fillWidth: true
                    textRole: "text"
                    valueRole: "id"
                    model: Object.keys(page.builtins).filter(id => !page.cfg_railItems.includes(id))
                        .map(id => ({ id: id, text: page.builtins[id][0] }))
                }
                QQC2.Button { text: i18n("Add"); icon.name: "list-add"; enabled: addBox.count > 0; onClicked: page.add(addBox.currentValue) }
            }
            QQC2.Button { text: i18n("Add custom location…"); icon.name: "folder-new"; onClicked: customDialog.open() }
        }

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Power menu options") }

        QQC2.ComboBox {
            Kirigami.FormData.label: i18n("Clicking the power button should:")
            textRole: "text"
            valueRole: "id"
            model: [{ id: "menu", text: i18n("Show the power menu") }].concat(page.powerChoices.map(c => ({ id: c[0], text: c[1] })))
            Component.onCompleted: currentIndex = Math.max(0, indexOfValue(page.cfg_powerButtonAction))
            onActivated: page.cfg_powerButtonAction = currentValue
        }
        ColumnLayout {
            Kirigami.FormData.label: i18n("Show in the power menu:")
            Repeater {
                model: page.powerChoices
                delegate: QQC2.CheckBox {
                    required property var modelData
                    text: modelData[1]
                    checked: page.cfg_powerItems.includes(modelData[0])
                    onToggled: {
                        const set = new Set(page.cfg_powerItems);
                        checked ? set.add(modelData[0]) : set.delete(modelData[0]);
                        page.cfg_powerItems = page.powerChoices.map(c => c[0]).filter(x => set.has(x));
                    }
                }
            }
        }
    }

    // "Add custom location..." - a folder, a web address, or a command.
    KIconThemes.IconDialog {
        id: customIconDialog
        onIconNameChanged: name => customIcon.text = name
    }
    Kirigami.PromptDialog {
        id: customDialog
        title: i18n("Add custom location")
        standardButtons: Kirigami.Dialog.Ok | Kirigami.Dialog.Cancel
        onAccepted: {
            if (customName.text && customTarget.text) {
                const target = customKind.currentIndex === 1 ? "cmd:" + customTarget.text : customTarget.text;
                page.add(["custom", customName.text.replace(/\|/g, "/"), customIcon.text, target].join("|"));
            }
            customName.text = customTarget.text = customIcon.text = "";
        }
        Kirigami.FormLayout {
            QQC2.TextField { id: customName; Kirigami.FormData.label: i18n("Name:") }
            QQC2.ComboBox { id: customKind; Kirigami.FormData.label: i18n("Opens:"); model: [i18n("Folder or web address"), i18n("Command")] }
            QQC2.TextField {
                id: customTarget
                Kirigami.FormData.label: customKind.currentIndex === 1 ? i18n("Command:") : i18n("Location:")
                placeholderText: customKind.currentIndex === 1 ? "kate" : "/home/you/Projects  or  https://…"
            }
            RowLayout {
                Kirigami.FormData.label: i18n("Icon:")
                QQC2.TextField { id: customIcon; placeholderText: "folder" }
                QQC2.Button { icon.name: "document-open"; onClicked: customIconDialog.open() }
            }
        }
    }
}
