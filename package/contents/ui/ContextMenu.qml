pragma ComponentBehavior: Bound

import QtQuick
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kitemmodels as KItemModels

// Right-click menu. Items are plain objects:
//   { text, icon, run: function() }            our own actions
//   { text, icon, actionId, actionArgument }   kicker actions, run on (model, row)
//   { type: "separator" }
Item {
    id: menuRoot
    visible: false

    property var model: null
    property int row: -1
    property var items: []

    signal actionDone()

    // Kicker's own actions for this row (jump list, add to panel, uninstall, ...).
    function kickerActions(model, row) {
        if (!model || row < 0) return [];
        const roles = model.KItemModels.KRoleNames;
        const idx = model.index(row, 0);
        if (!model.data(idx, roles.role("hasActionList"))) return [];
        return Array.from(model.data(idx, roles.role("actionList")) || []);
    }

    function show(visualParent, model, row, ownItems, x, y) {
        menuRoot.model = model;
        menuRoot.row = row;
        let list = ownItems.slice();
        const extra = kickerActions(model, row);
        if (extra.length) {
            if (list.length) list.push({ type: "separator" });
            list = list.concat(extra);
        }
        menuRoot.items = list;
        if (!list.length) return;
        menu.visualParent = visualParent;
        if (x !== undefined) {
            menu.open(x, y);
        } else {
            menu.openRelative();
        }
    }

    PlasmaExtras.Menu {
        id: menu
        placement: PlasmaExtras.Menu.BottomPosedLeftAlignedPopup
    }

    Instantiator {
        model: menuRoot.items
        delegate: itemComponent
        onObjectAdded: (index, object) => menu.addMenuItem(object)
        onObjectRemoved: (index, object) => menu.removeMenuItem(object)
    }

    Component {
        id: subMenuComponent
        PlasmaExtras.Menu {}
    }

    Component {
        id: itemComponent
        PlasmaExtras.MenuItem {
            id: item
            required property var modelData
            readonly property PlasmaExtras.Menu subMenu: modelData.subActions
                ? subMenuComponent.createObject(this, { visualParent: action }) as PlasmaExtras.Menu
                : null

            text: modelData.text ?? ""
            icon: modelData.icon ?? null
            separator: modelData.type === "separator"
            section: modelData.type === "title"
            enabled: modelData.type !== "title" && (modelData.enabled ?? true)
            checkable: modelData.checkable ?? false
            checked: modelData.checked ?? false

            readonly property Instantiator subItems: Instantiator {
                active: item.subMenu !== null
                model: item.modelData.subActions
                delegate: itemComponent
                onObjectAdded: (index, object) => item.subMenu.addMenuItem(object)
                onObjectRemoved: (index, object) => item.subMenu.removeMenuItem(object)
            }

            onClicked: {
                let close = false;
                if (modelData.run) {
                    modelData.run();
                    close = modelData.closes ?? false;
                } else if (modelData.actionId && menuRoot.model) {
                    close = menuRoot.model.trigger(menuRoot.row, modelData.actionId, modelData.actionArgument);
                }
                if (close) menuRoot.actionDone();
            }
        }
    }
}
