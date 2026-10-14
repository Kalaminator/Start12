// Run: node tests/test_tiles.js
const fs = require("fs");
const path = require("path");
const assert = require("assert");
const src = fs.readFileSync(path.join(__dirname, "../package/contents/ui/code/tiles.js"), "utf8")
    .replace(/^\.pragma library/m, "");
const T = new Function(src + "; return { parse, pack, place, remove, resize, sortGroup, setProp, placeInList, moveGroup, custom, customFor, nearest };")();

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
assert.deepStrictEqual(T.parse("garbage"), []);

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

console.log("tiles.js: all checks passed");
