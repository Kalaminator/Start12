.pragma library

// Tile groups live in the config as JSON, per page (parsePages):
// { "pages": [{ "groups": [{ "name": "Gaming", "tiles": [{ "id": "steam.desktop", "size": "medium" }] }] }] }
// Grid unit = one small tile. A group is (columns * 2) units wide.

var SIZES = {
    small:  { w: 1, h: 1 },
    medium: { w: 2, h: 2 },
    wide:   { w: 4, h: 2 },
    large:  { w: 4, h: 4 }
};

// Tile pages (Start11): { "pages": [{ "groups": [...] }] }. The old flat group list becomes page 1.
function parsePages(json) {
    var d;
    try { d = JSON.parse(json || "[]"); } catch (e) { d = []; }
    var pages = Array.isArray(d) ? [{ groups: d }] : (d && Array.isArray(d.pages) ? d.pages : []);
    pages = pages.filter(function (p) { return p && Array.isArray(p.groups); }).map(function (p) {
        return { groups: p.groups.filter(function (x) { return x && Array.isArray(x.tiles); }) };
    });
    return pages.length ? pages : [{ groups: [] }];
}

// Page p gets these groups; a tile moved here from another page leaves that page (no duplicates).
// Folder ids are per page ("folder|1" on two pages), so only app ids are checked.
function setPage(pages, p, groups) {
    var out = clone(pages);
    out[p] = { groups: groups };
    var ids = [];
    groups.forEach(function (g) { g.tiles.forEach(function (t) {
        (t.kind === "folder" ? t.tiles : [t]).forEach(function (x) { ids.push(x.id); });
    }); });
    out.forEach(function (pg, k) {
        if (k === p) return;
        ids.forEach(function (id) { if (!isFolder(id) && findTile(pg.groups, id)) pg.groups = remove(pg.groups, id); });
    });
    return out;
}

function newPage(pages) {
    return clone(pages).concat([{ groups: [] }]);
}

// Deleting a page keeps its groups: they move to the end of the page before it (or the next one).
function deletePage(pages, p) {
    var out = clone(pages);
    if (out.length < 2 || p < 0 || p >= out.length) return out;
    var gone = out.splice(p, 1)[0];
    var to = Math.max(0, p - 1);
    out[to].groups = p > 0 ? out[to].groups.concat(gone.groups) : gone.groups.concat(out[to].groups);
    return out;
}

// Move group g of page p to the end of page "to".
function moveGroupToPage(pages, p, g, to) {
    var out = clone(pages);
    if (to < 0 || to >= out.length || to === p || !out[p] || !out[p].groups[g]) return out;
    out[to].groups.push(out[p].groups.splice(g, 1)[0]);
    return out;
}

function sizeOf(size) {
    return SIZES[size] || SIZES.medium;
}

// First-fit packing, in list order, like Windows 10 tile groups.
// ponytail: O(tiles * cells) scan, fine for the few dozen tiles a menu holds.
function pack(tiles, columns) {
    var W = Math.max(2, columns * 2);
    var used = [];
    function free(x, y, w, h) {
        for (var j = y; j < y + h; j++)
            for (var i = x; i < x + w; i++)
                if (used[j] && used[j][i]) return false;
        return true;
    }
    function take(x, y, w, h) {
        for (var j = y; j < y + h; j++) {
            used[j] = used[j] || [];
            for (var i = x; i < x + w; i++) used[j][i] = true;
        }
    }
    var pos = [], rows = 0;
    for (var t = 0; t < tiles.length; t++) {
        var s = sizeOf(tiles[t].size);
        var w = Math.min(s.w, W), h = s.h;
        // Bigger tiles snap to 2x2 blocks; small tiles fill a block's 4 cells first.
        var cells = w === 1 ? [[0, 0], [1, 0], [0, 1], [1, 1]] : [[0, 0]];
        var placed = false;
        for (var y = 0; !placed; y += 2) {
            for (var x = 0; x + w <= W && !placed; x += 2) {
                for (var c = 0; c < cells.length; c++) {
                    var cx = x + cells[c][0], cy = y + cells[c][1];
                    if (free(cx, cy, w, h)) {
                        take(cx, cy, w, h);
                        pos.push({ x: cx, y: cy, w: w, h: h });
                        rows = Math.max(rows, cy + h);
                        placed = true;
                        break;
                    }
                }
            }
        }
    }
    return { pos: pos, rows: rows };
}

function clone(groups) {
    return JSON.parse(JSON.stringify(groups));
}

// Finds a tile, also inside folders. { g, i, list }: list is the array holding it (group or folder
// tiles); f is the folder's index in its group when the tile sits in a folder.
function findTile(groups, id) {
    for (var g = 0; g < groups.length; g++)
        for (var i = 0; i < groups[g].tiles.length; i++) {
            var t = groups[g].tiles[i];
            if (t.id === id) return { g: g, i: i, list: groups[g].tiles };
            if (t.kind === "folder")
                for (var k = 0; k < t.tiles.length; k++)
                    if (t.tiles[k].id === id) return { g: g, i: k, f: i, list: t.tiles };
        }
    return null;
}

// Folders with one tile turn back into that tile (taking the folder's place and size); empty
// folders and empty unnamed groups vanish.
function tidy(groups) {
    groups.forEach(function (grp) {
        grp.tiles = grp.tiles.filter(function (t) { return t.kind !== "folder" || t.tiles.length > 0; })
            .map(function (t) {
                if (t.kind !== "folder" || t.tiles.length > 1) return t;
                var only = t.tiles[0];
                only.size = t.size;
                return only;
            });
    });
    return groups.filter(function (x) { return x.tiles.length > 0 || x.name !== ""; });
}

function isFolder(id) {
    return typeof id === "string" && id.indexOf("folder|") === 0;
}

// Drop tile (or app) id onto tile target: into target's folder, or both become a new folder in
// target's place (Windows 10 tile folders). A folder dropped on a tile is not nested: no change.
function dropOnTile(groups, id, target, size) {
    var out = clone(groups);
    if (id === target || isFolder(id)) return out;
    var tile = { id: id, size: size || "medium" };
    var at = findTile(out, id);
    if (at) tile = at.list.splice(at.i, 1)[0];
    var to = findTile(out, target);
    if (!to) return groups;
    if (to.f !== undefined) {
        to.list.splice(to.i + 1, 0, tile);
    } else if (to.list[to.i].kind === "folder") {
        to.list[to.i].tiles.push(tile);
    } else {
        var n = 1;
        while (findTile(out, "folder|" + n)) n++;
        var t = to.list[to.i];
        to.list[to.i] = { kind: "folder", id: "folder|" + n, name: "", size: t.size, tiles: [t, tile] };
    }
    return tidy(out);
}

// Move (or insert, when the id is not pinned yet) a tile to group g, index i.
// g === groups.length makes a new unnamed group.
function place(groups, id, g, i, size) {
    var out = clone(groups);
    var tile = { id: id, size: size || "medium" };
    var at = findTile(out, id);
    if (at) {
        tile = at.list.splice(at.i, 1)[0];
        if (at.g === g && at.f === undefined && at.i < i) i--;
    }
    if (g >= out.length) {
        out.push({ name: "", tiles: [] });
        g = out.length - 1;
    }
    var list = out[g].tiles;
    list.splice(Math.max(0, Math.min(i, list.length)), 0, tile);
    return tidy(out);
}

function remove(groups, id) {
    var out = clone(groups);
    var at = findTile(out, id);
    if (at) at.list.splice(at.i, 1);
    return tidy(out);
}

function resize(groups, id, size) {
    var out = clone(groups);
    var at = findTile(out, id);
    if (at) at.list[at.i].size = size;
    return out;
}

function sortGroup(groups, g, names) {
    var out = clone(groups);
    out[g].tiles.sort(function (a, b) {
        return (names[a.id] || a.id).localeCompare(names[b.id] || b.id);
    });
    return out;
}

// Per-tile options: icon, caption ("show"/"hide"), color. undefined/"" removes the key.
function setProp(groups, id, key, value) {
    var out = clone(groups);
    var at = findTile(out, id);
    if (at) {
        if (value === undefined || value === "") delete at.list[at.i][key];
        else at.list[at.i][key] = value;
    }
    return out;
}

// Pinned grid (Windows 11 style): a flat list of ids. Move (or insert) id to index i.
function placeInList(list, id, i) {
    var out = list.slice();
    var at = out.indexOf(id);
    if (at >= 0) {
        out.splice(at, 1);
        if (at < i) i--;
    }
    out.splice(Math.max(0, Math.min(i, out.length)), 0, id);
    return out;
}

// Pinned grid folders (Windows 11): entry "folder|name|id1,id2,...".
// ponytail: comma-separated ids; a pinned url containing "," would split, escape if that happens.
function folderOf(entry) {
    if (!isFolder(entry)) return null;
    var p = entry.split("|");
    var ids = p.slice(2).join("|");
    return { name: p[1], ids: ids ? ids.split(",") : [] };
}

function folderEntry(name, ids) {
    return "folder|" + String(name).replace(/[|,]/g, " ") + "|" + ids.join(",");
}

// Every pinned id, folders opened up.
function allPins(list) {
    var out = [];
    list.forEach(function (e) { var f = folderOf(e); out = out.concat(f ? f.ids : [e]); });
    return out;
}

// Unpin id from the list or from its folder; a folder left with one app turns back into it.
function removePin(list, id) {
    var out = [];
    list.forEach(function (e) {
        var f = folderOf(e);
        if (!f) { if (e !== id) out.push(e); return; }
        var ids = f.ids.filter(function (x) { return x !== id; });
        if (ids.length > 1) out.push(folderEntry(f.name, ids));
        else if (ids.length === 1) out.push(ids[0]);
    });
    return out;
}

// Drop id onto list entry target: into target's folder, or both become a new folder in target's
// place. Folders do not nest.
function placeInFolder(list, id, target, name) {
    if (id === target || isFolder(id) || list.indexOf(target) < 0) return list;
    var f = folderOf(target);
    var out = removePin(list, id);
    var i = out.indexOf(target);
    if (i < 0) return list;
    out[i] = f ? folderEntry(f.name, f.ids.concat([id])) : folderEntry(name || "Folder", [target, id]);
    return out;
}

// Move group "from" so it ends up before the group now at "to" (to === length: last).
function moveGroup(groups, from, to) {
    var out = clone(groups);
    if (from < 0 || from >= out.length) return out;
    var g = out.splice(from, 1)[0];
    if (from < to) to--;
    out.splice(Math.max(0, Math.min(to, out.length)), 0, g);
    return out;
}

// Pinned websites, files and folders use the rail's custom id: "custom|name|icon|target".
function custom(id) {
    if (typeof id !== "string" || id.indexOf("custom|") !== 0) return null;
    var p = id.split("|");
    return { id: id, name: p[1], icon: p[2], target: p.slice(3).join("|") };
}

// ponytail: icon by file extension, not a real mime lookup (QML has no KIO mime API).
var EXT_ICONS = {
    pdf: "application-pdf", txt: "text-plain", md: "text-markdown", html: "text-html",
    png: "image-x-generic", jpg: "image-x-generic", jpeg: "image-x-generic", gif: "image-x-generic",
    svg: "image-svg+xml", webp: "image-x-generic", mp3: "audio-x-generic", ogg: "audio-x-generic",
    flac: "audio-x-generic", wav: "audio-x-generic", mp4: "video-x-generic", mkv: "video-x-generic",
    webm: "video-x-generic", zip: "application-zip", tar: "application-x-tar", gz: "application-x-compressed-tar",
    odt: "x-office-document", docx: "x-office-document", doc: "x-office-document",
    ods: "x-office-spreadsheet", xlsx: "x-office-spreadsheet", odp: "x-office-presentation", pptx: "x-office-presentation",
    sh: "application-x-shellscript", py: "text-x-python", js: "text-x-javascript", iso: "application-x-cd-image"
};

// Build the custom id for a url. kind: "web", "file" or "folder".
function customFor(url, kind) {
    var name, icon;
    if (kind === "web") {
        var host = (url.match(/^\w+:\/\/([^\/:?#]+)/) || [null, url])[1];
        name = host.replace(/^www\./, "");
        icon = "https://icons.duckduckgo.com/ip3/" + host + ".ico";
    } else {
        var path = url.replace(/\/+$/, "");
        name = decodeURIComponent(path.slice(path.lastIndexOf("/") + 1)) || "/";
        var dot = name.lastIndexOf(".");
        icon = kind === "folder" ? "folder" : (dot > 0 && EXT_ICONS[name.slice(dot + 1).toLowerCase()]) || "text-x-generic";
    }
    return ["custom", name.replace(/\|/g, "/"), icon, url].join("|");
}

// Keyboard arrows: index of the rect nearest to rects[cur] in direction (dx, dy), -1 if none.
// Rects are {x, y, width, height}; sideways distance counts double. cur < 0: the top-left rect.
function nearest(rects, cur, dx, dy) {
    var best = -1, bestScore = Infinity;
    for (var i = 0; i < rects.length; i++) {
        var r = rects[i];
        var score;
        if (cur < 0) {
            score = r.y * 10000 + r.x;
        } else {
            if (i === cur) continue;
            var a = rects[cur];
            var ox = r.x + r.width / 2 - a.x - a.width / 2;
            var oy = r.y + r.height / 2 - a.y - a.height / 2;
            var along = ox * dx + oy * dy;
            if (along < 1) continue;
            score = along + 2 * (Math.abs(ox * dy) + Math.abs(oy * dx));
        }
        if (score < bestScore) {
            bestScore = score;
            best = i;
        }
    }
    return best;
}

// Backup/restore (T13): quote any text for /bin/sh, and the command that writes text to a file.
function shQuote(s) {
    return "'" + String(s).replace(/'/g, "'\\''") + "'";
}
function writeFileCmd(text, file) {
    return "sh -c " + shQuote("printf %s " + shQuote(text) + " > " + shQuote(file));
}
