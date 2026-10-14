.pragma library

// Tile groups live in the config as JSON:
// [{ "name": "Gaming", "tiles": [{ "id": "steam.desktop", "size": "medium" }] }]
// Grid unit = one small tile. A group is (columns * 2) units wide.

var SIZES = {
    small:  { w: 1, h: 1 },
    medium: { w: 2, h: 2 },
    wide:   { w: 4, h: 2 },
    large:  { w: 4, h: 4 }
};

function parse(json) {
    try {
        var g = JSON.parse(json || "[]");
        return Array.isArray(g) ? g.filter(function (x) { return x && Array.isArray(x.tiles); }) : [];
    } catch (e) {
        return [];
    }
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

function findTile(groups, id) {
    for (var g = 0; g < groups.length; g++)
        for (var i = 0; i < groups[g].tiles.length; i++)
            if (groups[g].tiles[i].id === id) return { g: g, i: i };
    return null;
}

// Move (or insert, when the id is not pinned yet) a tile to group g, index i.
// g === groups.length makes a new unnamed group.
function place(groups, id, g, i, size) {
    var out = clone(groups);
    var tile = { id: id, size: size || "medium" };
    var at = findTile(out, id);
    if (at) {
        tile = out[at.g].tiles.splice(at.i, 1)[0];
        if (at.g === g && at.i < i) i--;
    }
    if (g >= out.length) {
        out.push({ name: "", tiles: [] });
        g = out.length - 1;
    }
    var list = out[g].tiles;
    list.splice(Math.max(0, Math.min(i, list.length)), 0, tile);
    return out.filter(function (x) { return x.tiles.length > 0 || x.name !== ""; });
}

function remove(groups, id) {
    var out = clone(groups);
    var at = findTile(out, id);
    if (at) out[at.g].tiles.splice(at.i, 1);
    return out.filter(function (x) { return x.tiles.length > 0 || x.name !== ""; });
}

function resize(groups, id, size) {
    var out = clone(groups);
    var at = findTile(out, id);
    if (at) out[at.g].tiles[at.i].size = size;
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
        if (value === undefined || value === "") delete out[at.g].tiles[at.i][key];
        else out[at.g].tiles[at.i][key] = value;
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
