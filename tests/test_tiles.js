// Run: node tests/test_tiles.js
const fs = require("fs");
const path = require("path");
const assert = require("assert");
const src = fs.readFileSync(path.join(__dirname, "../package/contents/ui/code/tiles.js"), "utf8")
    .replace(/^\.pragma library/m, "");
const T = new Function(src + "; return { pack, rowEnd, place, remove, resize, sortGroup, setProp, placeInList, moveGroup, custom, customFor, nearest, dropOnTile, findTile, folderOf, folderEntry, allPins, removePin, placeInFolder, parsePages, setPage, newPage, deletePage, moveGroupToPage, shQuote, writeFileCmd, parseCanvas, canvasAddTab, canvasDeleteTab, canvasMoveTab, canvasAddGroup, canvasDeleteGroup, canvasRename, canvasPlace, canvasRemove, canvasSet, canvasSort, fileIcon, pushHistory, parseFiltered, filterFile, dirUrl, pinDesktop, splitGet, splitSet, splitReset, isWidget, widgetId, addWidget };")();

// 6 columns = 12 units wide: six medium tiles fit in one row.
let p = T.pack(Array(6).fill({ size: "medium" }), 6);
assert.strictEqual(p.rows, 2);
assert.deepStrictEqual(p.pos[5], { x: 10, y: 0, w: 2, h: 2 });

// Seventh medium wraps to the next row (like the "Gaming" group).
p = T.pack(Array(7).fill({ size: "medium" }), 6);
assert.strictEqual(p.rows, 4);
assert.deepStrictEqual(p.pos[6], { x: 0, y: 2, w: 2, h: 2 });

// Four small tiles fill one 2x2 block before moving right.
p = T.pack([{ size: "small" }, { size: "small" }, { size: "medium" }, { size: "small" }], 3);
assert.deepStrictEqual(p.pos.map(q => [q.x, q.y]), [[0, 0], [1, 0], [2, 0], [0, 1]]);

// Large tile + mediums.
p = T.pack([{ size: "large" }, { size: "medium" }, { size: "medium" }], 4);
assert.deepStrictEqual(p.pos.map(q => [q.x, q.y]), [[0, 0], [4, 0], [6, 0]]);

// place: new id into new group, move between groups, empty unnamed groups vanish.
let g = T.place([], "a.desktop", 0, 0);
assert.deepStrictEqual(g, [{ name: "", tiles: [{ id: "a.desktop", size: "medium" }] }]);
g = [{ name: "X", tiles: [{ id: "a", size: "wide" }, { id: "b", size: "medium" }] }, { name: "", tiles: [{ id: "c", size: "small" }] }];
let h = T.place(g, "c", 0, 1);
assert.deepStrictEqual(h, [{ name: "X", tiles: [{ id: "a", size: "wide" }, { id: "c", size: "small" }, { id: "b", size: "medium" }] }]);
h = T.place(g, "a", 0, 2); // move to end of its own group
assert.deepStrictEqual(h[0].tiles.map(t => t.id), ["b", "a"]);
assert.strictEqual(T.remove(g, "b")[0].tiles.length, 1);
assert.strictEqual(T.resize(g, "b", "large")[0].tiles[1].size, "large");
assert.deepStrictEqual(T.sortGroup(g, 0, { a: "Zed", b: "Alpha" })[0].tiles.map(t => t.id), ["b", "a"]);

let q = T.setProp(g, "a", "icon", "firefox");
assert.strictEqual(q[0].tiles[0].icon, "firefox");
assert.strictEqual(T.setProp(q, "a", "icon", "")[0].tiles[0].icon, undefined);
assert.strictEqual(g[0].tiles[0].icon, undefined); // input not mutated

assert.deepStrictEqual(T.placeInList(["a", "b", "c"], "c", 0), ["c", "a", "b"]);
assert.deepStrictEqual(T.placeInList(["a", "b", "c"], "a", 2), ["b", "a", "c"]);   // drop before "c"
assert.deepStrictEqual(T.placeInList(["a", "b"], "z", 9), ["a", "b", "z"]);

const G = [{ name: "A", tiles: [] }, { name: "B", tiles: [] }, { name: "C", tiles: [] }];
assert.deepStrictEqual(T.moveGroup(G, 2, 0).map(x => x.name), ["C", "A", "B"]);
assert.deepStrictEqual(T.moveGroup(G, 0, 2).map(x => x.name), ["B", "A", "C"]);   // before "C"
assert.deepStrictEqual(T.moveGroup(G, 0, 3).map(x => x.name), ["B", "C", "A"]);   // to the end

// Pinned websites, files, folders.
assert.strictEqual(T.customFor("https://www.kde.org/news?x=1", "web"),
    "custom|kde.org|https://icons.duckduckgo.com/ip3/www.kde.org.ico|https://www.kde.org/news?x=1");
assert.strictEqual(T.customFor("https://a.org/x", "web", false), "custom|a.org|internet-web-browser|https://a.org/x");
assert.strictEqual(T.customFor("file:///home/u/My%20Doc.PDF", "file"), "custom|My Doc.PDF|application-pdf|file:///home/u/My%20Doc.PDF");
assert.strictEqual(T.customFor("file:///home/u/Pictures/", "folder"), "custom|Pictures|folder|file:///home/u/Pictures/");
assert.strictEqual(T.customFor("file:///home/u/notes", "file").split("|")[2], "text-x-generic");
assert.deepStrictEqual(T.custom("custom|a|b|cmd:x|y"), { id: "custom|a|b|cmd:x|y", name: "a", icon: "b", target: "cmd:x|y" });
assert.strictEqual(T.custom("firefox.desktop"), null);

// Keyboard arrows in a 3x2 grid of 10x10 cells.
const R = [0, 1, 2, 3, 4, 5].map(i => ({ x: (i % 3) * 10, y: Math.floor(i / 3) * 10, width: 10, height: 10 }));
assert.strictEqual(T.nearest(R, -1, 0, 1), 0);
assert.strictEqual(T.nearest(R, 0, 1, 0), 1);
assert.strictEqual(T.nearest(R, 1, 0, 1), 4);
assert.strictEqual(T.nearest(R, 2, 1, 0), -1);   // right edge
assert.strictEqual(T.nearest(R, 4, 0, -1), 1);


// Tile folders (Windows 10): drop a tile on a tile -> folder in the target's place.
const F0 = [{ name: "", tiles: [{ id: "a", size: "wide" }, { id: "b", size: "medium" }, { id: "c", size: "small" }] }];
let f = T.dropOnTile(F0, "c", "a");
assert.deepStrictEqual(f[0].tiles.map(t => t.id), ["folder|1", "b"]);
assert.deepStrictEqual(f[0].tiles[0], { kind: "folder", id: "folder|1", name: "", size: "wide", tiles: [{ id: "a", size: "wide" }, { id: "c", size: "small" }] });
f = T.dropOnTile(f, "b", "folder|1");                       // onto the folder: appended
assert.deepStrictEqual(f[0].tiles[0].tiles.map(t => t.id), ["a", "c", "b"]);
f = T.dropOnTile(f, "new.desktop", "a");                    // new app onto a tile inside: after it
assert.deepStrictEqual(f[0].tiles[0].tiles.map(t => t.id), ["a", "new.desktop", "c", "b"]);
assert.strictEqual(T.findTile(f, "c").f, 0);
assert.deepStrictEqual(T.dropOnTile(f, "folder|1", "a"), f);  // no nesting
f = T.place(f, "c", 0, 1);                                  // drag out of the folder
assert.deepStrictEqual(f[0].tiles.map(t => t.id), ["folder|1", "c"]);
f = T.remove(T.remove(f, "b"), "new.desktop");             // one tile left: folder dissolves
assert.deepStrictEqual(f[0].tiles, [{ id: "a", size: "wide" }, { id: "c", size: "small" }]);
f = T.dropOnTile(T.dropOnTile(F0, "b", "a"), "c", "folder|1");
assert.strictEqual(T.setProp(f, "folder|1", "name", "Games")[0].tiles[0].name, "Games");
assert.deepStrictEqual(T.remove(f, "folder|1"), []);        // unpin folder = unpin its tiles

// Pinned grid folders (Win11): "folder|name|id1,id2".
let L = T.placeInFolder(["a", "b", "c"], "c", "a", "Games");
assert.deepStrictEqual(L, ["folder|Games|a,c", "b"]);
assert.deepStrictEqual(T.folderOf(L[0]), { name: "Games", ids: ["a", "c"] });
L = T.placeInFolder(L, "b", L[0]);                          // onto the folder: appended
assert.deepStrictEqual(L, ["folder|Games|a,c,b"]);
assert.deepStrictEqual(T.placeInFolder(L, L[0], "x"), L);   // no nesting / unknown target
assert.deepStrictEqual(T.allPins(["x", ...L]), ["x", "a", "c", "b"]);
L = T.removePin(T.removePin(L, "c"), "b");                  // one left: folder dissolves
assert.deepStrictEqual(L, ["a"]);
assert.strictEqual(T.folderEntry("A|b,c", ["x"]), "folder|A b c|x");
assert.deepStrictEqual(T.folderOf(T.folderEntry("F", ["custom|M|i|https://x?a,b", "a.desktop"])).ids, ["custom|M|i|https://x?a,b", "a.desktop"]);
assert.deepStrictEqual(T.folderOf("custom|x|y|z"), null);
// Tile pages: old flat list migrates to page 1; moves keep tiles unique across pages.
let P = T.parsePages('[{"name":"A","tiles":[{"id":"a"}]}]');
assert.deepStrictEqual(P, [{ groups: [{ name: "A", tiles: [{ id: "a" }] }] }]);
assert.deepStrictEqual(T.parsePages("bad"), [{ groups: [] }]);
assert.deepStrictEqual(T.parsePages(JSON.stringify({ pages: P })), P);
P = T.newPage(P);
assert.strictEqual(P.length, 2);
P = T.moveGroupToPage(P, 0, 0, 1);
assert.deepStrictEqual(P.map(p => p.groups.length), [0, 1]);
P = T.setPage(P, 0, [{ name: "", tiles: [{ id: "a" }] }]);       // "a" dragged onto page 1
assert.deepStrictEqual(P[1].groups, [{ name: "A", tiles: [] }]); // named group stays, tile gone
P = T.deletePage(P, 0);                                          // first page: groups go to the next
assert.deepStrictEqual(P, [{ groups: [{ name: "", tiles: [{ id: "a" }] }, { name: "A", tiles: [] }] }]);
assert.deepStrictEqual(T.deletePage(P, 0), P);                   // last page stays
// App canvas user tabs: "Work" with two groups, apps dragged in and between groups.
let C = T.parseCanvas("bad");
assert.deepStrictEqual(C, { tabs: [] });
C = T.canvasAddGroup(T.canvasAddGroup(T.canvasAddTab(C, "Work"), 0, "Mail"), 0, "Code");
C = T.canvasPlace(C, 0, "a", 0, "", "");
C = T.canvasPlace(C, 0, "b", 0, "a", "");                 // before a
assert.deepStrictEqual(C.tabs[0].groups[0].ids, ["b", "a"]);
C = T.canvasPlace(C, 0, "a", 1, "", "");                  // dragged to the other group
assert.deepStrictEqual(C.tabs[0].groups.map(g => g.ids), [["b"], ["a"]]);
C = T.canvasPlace(C, 0, "c", 5, "", "New");               // empty space: new group
assert.deepStrictEqual(C.tabs[0].groups[2], { name: "New", colour: "", ids: ["c"] });
C = T.canvasRemove(T.canvasDeleteGroup(C, 0, 2), 0, "a");
assert.deepStrictEqual(C.tabs[0].groups.map(g => g.ids), [["b"], []]);
C = T.canvasRename(T.canvasRename(T.canvasAddTab(C, "X"), 1, -1, "Y"), 0, 1, "Dev");
assert.deepStrictEqual([C.tabs[1].name, C.tabs[0].groups[1].name], ["Y", "Dev"]);
assert.strictEqual(T.canvasMoveTab(C, 0, -1), C);
assert.deepStrictEqual(T.canvasMoveTab(C, 0, 1).tabs.map(t => t.name), ["Y", "Work"]);
assert.deepStrictEqual(T.parseCanvas(JSON.stringify(T.canvasDeleteTab(C, 0))).tabs.map(t => t.name), ["Y"]);
// Group settings, A-Z resort, folder file icons.
C = T.canvasSet(C, 0, 0, "rows", 2);
assert.strictEqual(C.tabs[0].groups[0].rows, 2);
C = T.canvasSet(C, 0, 0, "ids", ["z", "x", "y", "gone"]);
assert.deepStrictEqual(T.canvasSort(C, 0, 0, { z: "Zed", x: "alpha", y: "Beta" }).tabs[0].groups[0].ids, ["x", "y", "z", "gone"]);
assert.deepStrictEqual([T.fileIcon("A.PDF"), T.fileIcon("x", true), T.fileIcon("noext")], ["application-pdf", "folder", "text-x-generic"]);
// Backup file write survives quotes, $, newlines, unicode, spaces in the path.
{
    const os = require("os"), cp = require("child_process");
    const file = path.join(fs.mkdtempSync(path.join(os.tmpdir(), "s12-")), "my 'backup'.json");
    const text = JSON.stringify({ a: "it's $HOME `x` \\ \n é", b: ["x|y"] });
    cp.execSync(T.writeFileCmd(text, file), { shell: "/bin/sh" });
    assert.strictEqual(fs.readFileSync(file, "utf8"), text);
}
assert.deepStrictEqual(T.pushHistory(["a", "b"], " b "), ["b", "a"]);
assert.deepStrictEqual(T.pushHistory(["a"], ""), ["a"]);
assert.strictEqual(T.pushHistory("0123456789".split(""), "x").length, 10);
// Filtered folders.
{
    const F = T.parseFiltered('[{"name":"PDFs","path":"~/Downloads","include":"pdf$"},{"name":"x"},5]');
    assert.strictEqual(F.length, 1);
    assert.deepStrictEqual(["a.pdf", "b.PDF", "c.txt", "pdfs"].filter(n => T.filterFile(F[0], n)), ["a.pdf", "b.PDF"]);
    assert.deepStrictEqual(["a.txt", "b.tmp"].filter(n => T.filterFile({ exclude: "\\.tmp$" }, n)), ["a.txt"]);
    assert.ok(T.filterFile({ include: "(" }, "any"));
    assert.deepStrictEqual(T.parseFiltered("bad"), []);
    assert.strictEqual(T.dirUrl("~/Downloads", "file:///home/u/"), "file:///home/u/Downloads");
    assert.strictEqual(T.dirUrl("/tmp", "file:///home/u"), "file:///tmp");
}
// Opened folder row: under the folder's own row, below any tile crossing it.
{
    const P = [{ x: 0, y: 0, w: 2, h: 2 }, { x: 2, y: 0, w: 4, h: 4 }, { x: 0, y: 4, w: 2, h: 2 }];
    assert.strictEqual(T.rowEnd(P, 0), 4);
    assert.strictEqual(T.rowEnd(P, 2), 6);
    assert.strictEqual(T.rowEnd([{ x: 0, y: 0, w: 1, h: 1 }, { x: 0, y: 2, w: 2, h: 2 }], 0), 1);
}
// Taskbar pin .desktop: quoted Exec with spec escapes, favicon urls fall back to a theme icon.
{
    const d = T.pinDesktop(T.custom("custom|kde.org|https://icons.x/kde.ico|https://kde.org/a?b=50%"));
    assert.ok(d.includes("Icon=internet-web-browser\n"));
    assert.ok(d.includes('Exec=xdg-open "https://kde.org/a?b=50%%"\n'));
    assert.ok(T.pinDesktop(T.custom('custom|x|folder|cmd:echo "$HOME"')).includes('Exec=sh -c "echo \\\\"\\\\$HOME\\\\""'));
}
// Design mode splits (T40).
{
    let j = T.splitSet("", "windows10", 300.4);
    assert.strictEqual(T.splitGet(j, "windows10"), 300);
    assert.strictEqual(T.splitGet(j, "xp"), null);
    assert.strictEqual(T.splitGet("bad", "xp"), null);
    j = T.splitSet(T.splitSet(j, "xp/right", 200), "xpx", 5);
    j = T.splitReset(j, "xp");
    assert.deepStrictEqual(JSON.parse(j), { windows10: 300, xpx: 5 });
    assert.strictEqual(T.splitSet(j, "windows10", null), '{"xpx":5}');
}
// Big sizes (wideLargeH 8x4, wideLargeV 4x8), also in a narrow 2-unit group.
{
    let p = T.pack([{ size: "wideLargeH" }, { size: "wideLargeV" }, { size: "small" }], 6);
    assert.deepStrictEqual(p.pos[0], { x: 0, y: 0, w: 8, h: 4 });
    assert.deepStrictEqual(p.pos[1], { x: 8, y: 0, w: 4, h: 8 });
    assert.strictEqual(p.rows, 8);
    p = T.pack([{ size: "wideLargeH" }, { size: "wideLargeV" }], 1);
    assert.deepStrictEqual(p.pos[0], { x: 0, y: 0, w: 2, h: 4 });
    assert.deepStrictEqual(p.pos[1], { x: 0, y: 4, w: 2, h: 8 });
}
// 3x6 sizes: 12x6 / 6x12, clamped in narrow groups (odd/clamped widths still lay out).
{
    let p = T.pack([{ size: "hugeH" }, { size: "hugeV" }, { size: "small" }], 6);
    assert.deepStrictEqual(p.pos[0], { x: 0, y: 0, w: 12, h: 6 });
    assert.deepStrictEqual(p.pos[1], { x: 0, y: 6, w: 6, h: 12 });
    assert.strictEqual(p.rows, 18);
    p = T.pack([{ size: "hugeH" }, { size: "hugeV" }, { size: "medium" }], 1);
    assert.deepStrictEqual(p.pos[0], { x: 0, y: 0, w: 2, h: 6 });
    assert.deepStrictEqual(p.pos[1], { x: 0, y: 6, w: 2, h: 12 });
    p = T.pack([{ size: "hugeV" }, { size: "wide" }], 2);
    assert.deepStrictEqual(p.pos[0], { x: 0, y: 0, w: 4, h: 12 });
    assert.strictEqual(p.pos.length, 2);
}
// Widget tiles.
{
    assert.ok(T.isWidget("widget|clock|1") && !T.isWidget("a.desktop"));
    let pages = [{ groups: [] }];
    pages = T.addWidget(pages, 0, "clock");
    pages = T.addWidget(pages, 0, "clock");
    assert.deepStrictEqual(pages[0].groups[0].tiles.map(t => t.id), ["widget|clock|1", "widget|clock|2"]);
    let g = [{ name: "", tiles: [{ id: "a.desktop", size: "medium" }, { id: "widget|clock|1", size: "medium" }, { id: "b.desktop", size: "medium" }] }];
    let r = T.dropOnTile(g, "widget|clock|1", "a.desktop");   // widget onto app: moves, no folder
    assert.deepStrictEqual(r[0].tiles.map(t => t.id), ["widget|clock|1", "a.desktop", "b.desktop"]);
    r = T.dropOnTile(g, "b.desktop", "widget|clock|1");       // app onto widget: moves, no folder
    assert.deepStrictEqual(r[0].tiles.map(t => t.id), ["a.desktop", "b.desktop", "widget|clock|1"]);
    r = T.remove(g, "widget|clock|1");
    assert.strictEqual(r[0].tiles.length, 2);
    r = T.place(g, "widget|clock|1", 1, 0);
    assert.strictEqual(r[1].tiles[0].id, "widget|clock|1");
}
console.log("tiles.js: all checks passed");
