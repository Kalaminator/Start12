import QtQuick
import "../code/tiles.js" as Tiles

// Keyboard navigation shared by all styles. Arrows move root.kbCurrent through the items with
// kbNav: true inside a pane (or call the pane's kbStep(cur, dx, dy), see AppList); Left/Right
// at a pane edge and Tab/Shift-Tab change pane; Enter runs kbActivate() (else clicked()),
// the Menu key kbMenu(). A pane with kbPane forwards to that item (PinnedPane).
// The style calls handle(event) from its Keys.onPressed; false = not a navigation key.
Item {
    id: nav

    property var panes: []      // in Tab order
    property Item main: null    // the pane the first arrow press goes to
    property int paneIndex: -1

    function target(p) {
        while (p && p.kbPane) p = p.kbPane;
        return p;
    }

    function items(p, out) {
        for (let i = 0; i < p.children.length; i++) {
            const c = p.children[i];
            if (!c.visible) continue;
            if (c.kbNav) out.push(c);
            else items(c, out);
        }
        return out;
    }

    // Item after cur (null: the first one) in pane p, or null.
    function step(p, cur, dx, dy) {
        if (p.kbStep) return p.kbStep(cur, dx, dy);
        const list = items(p, []);
        const rects = list.map(i => {
            const o = i.mapToItem(p, 0, 0);
            return { x: o.x, y: o.y, width: i.width, height: i.height };
        });
        const i = Tiles.nearest(rects, cur ? list.indexOf(cur) : -1, dx, dy);
        return i >= 0 ? list[i] : null;
    }

    // Scroll a Flickable parent (tile area) so the item shows; items with kbShow() do it themselves.
    function reveal(item) {
        for (let f = item.parent; f; f = f.parent) {
            if (f.flickableDirection === undefined) continue;
            const y = item.mapToItem(f.contentItem, 0, 0).y;
            if (y < f.contentY) f.contentY = y;
            else if (y + item.height > f.contentY + f.height) f.contentY = y + item.height - f.height;
            return;
        }
    }

    function show(item) {
        root.kbCurrent = item;
        if (item.kbShow) item.kbShow();
        else reveal(item);
    }

    // Go to the first item of the next visible pane in direction d (wraps for Tab).
    function enter(from, d, wrap) {
        for (let i = from + d, n = 0; n < panes.length; i += d, n++) {
            if (wrap) i = (i + panes.length) % panes.length;
            if (i < 0 || i >= panes.length) return false;
            const p = target(panes[i]);
            const first = p && p.visible ? step(p, null, 0, 1) : null;
            if (first) {
                paneIndex = i;
                show(first);
                return true;
            }
        }
        return false;
    }

    function handle(event) {
        if (root.searching || (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) return false;
        const k = event.key;
        const cur = root.kbCurrent;
        if (k === Qt.Key_Tab || k === Qt.Key_Backtab) {
            if (!cur) return enter(panes.indexOf(main) - 1, 1, true);
            return enter(paneIndex, k === Qt.Key_Tab ? 1 : -1, true);
        }
        const d = k === Qt.Key_Left ? [-1, 0] : k === Qt.Key_Right ? [1, 0]
                : k === Qt.Key_Up ? [0, -1] : k === Qt.Key_Down ? [0, 1] : null;
        if (d) {
            if (!cur) return enter(panes.indexOf(main) - 1, 1, true);
            const next = step(target(panes[paneIndex]), cur, d[0], d[1]);
            if (next) show(next);
            else if (d[0]) enter(paneIndex, d[0], false);
            return true;
        }
        if (!cur) return false;
        if (k === Qt.Key_Return || k === Qt.Key_Enter) {
            cur.kbActivate ? cur.kbActivate() : cur.clicked();
            return true;
        }
        if (k === Qt.Key_Menu && cur.kbMenu) {
            cur.kbMenu();
            return true;
        }
        return false;
    }

    Connections {
        target: root
        function onExpandedChanged() { root.kbCurrent = null; }
        function onSearchingChanged() { root.kbCurrent = null; }
    }
}
