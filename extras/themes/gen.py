# Generates the Start12 XP Plasma themes (panel-background + tasks 9-slice SVGs).
# Run: python3 extras/themes/gen.py extras/themes
import os, sys
OUT = sys.argv[1]

def frame(prefix, x0, y0, W, H, c, border, stops, hi=None, margins=(4, 4, 4, 4), gid="g"):
    """9 pieces of a rounded box. stops: [(offset, color, opacity)] vertical gradient.
    border: (color, opacity) or None. hi: top highlight (color, opacity) or None."""
    p = (prefix + "-") if prefix else ""
    defs = '<linearGradient id="%s" gradientUnits="userSpaceOnUse" x1="0" y1="%d" x2="0" y2="%d">%s</linearGradient>' % (
        gid, y0, y0 + H, "".join('<stop offset="%s" stop-color="%s" stop-opacity="%s"/>' % s for s in stops))
    b = 1 if border else 0
    F = 'fill="url(#%s)"' % gid
    B = ('fill="%s" fill-opacity="%s"' % border) if border else ""
    x1, y1, x2, y2 = x0 + c, y0 + c, x0 + W - c, y0 + H - c
    out = []
    def g(name, body):
        out.append('<g id="%s%s">%s</g>' % (p, name, body))
    def rect(x, y, w, h, f):
        return '<rect x="%s" y="%s" width="%s" height="%s" %s/>' % (x, y, w, h, f) if w > 0 and h > 0 else ""
    def corner(cx, cy, sx, sy, r, f):
        # quarter disc of radius r around (cx,cy), toward (sx,sy) signs, filling the c-box
        if r <= 0:
            return ""
        sweep = 0 if sx * sy < 0 else 1
        return '<path d="M %s,%s L %s,%s A %s %s 0 0 %d %s,%s Z" %s/>' % (
            cx, cy, cx + sx * r, cy, r, r, sweep, cx, cy + sy * r, f)
    def piece_corner(name, cx, cy, sx, sy, bx, by):
        body = ""
        if c == 0 or (border is None):
            pass
        # transparent box keeps the element size exactly c x c
        body += rect(bx, by, c, c, 'fill="none"')
        if border:  # quarter ring, so translucent fills do not double up
            sw = 0 if sx * sy < 0 else 1
            body += '<path d="M %s,%s A %s %s 0 0 %d %s,%s L %s,%s A %s %s 0 0 %d %s,%s Z" %s/>' % (
                cx + sx * c, cy, c, c, sw, cx, cy + sy * c, cx, cy + sy * (c - b), c - b, c - b, 1 - sw, cx + sx * (c - b), cy, B)
        body += corner(cx, cy, sx, sy, c - b, F)
        if hi and sy < 0:
            pass
        g(name, body)
    piece_corner("topleft", x1, y1, -1, -1, x0, y0)
    piece_corner("topright", x2, y1, 1, -1, x2, y0)
    piece_corner("bottomleft", x1, y2, -1, 1, x0, y2)
    piece_corner("bottomright", x2, y2, 1, 1, x2, y2)
    top = (rect(x1, y0, W - 2 * c, b, B) if border else "") + rect(x1, y0 + b, W - 2 * c, c - b, F)
    if hi:
        top += rect(x1, y0 + b, W - 2 * c, 1, 'fill="%s" fill-opacity="%s"' % hi)
    g("top", top)
    g("bottom", rect(x1, y2, W - 2 * c, c - b, F) + (rect(x1, y0 + H - b, W - 2 * c, b, B) if border else ""))
    g("left", (rect(x0, y1, b, H - 2 * c, B) if border else "") + rect(x0 + b, y1, c - b, H - 2 * c, F))
    g("right", rect(x2, y1, c - b, H - 2 * c, F) + (rect(x0 + W - b, y1, b, H - 2 * c, B) if border else ""))
    g("center", rect(x1, y1, W - 2 * c, H - 2 * c, F))
    l, t, r, bm = margins
    hy = y0 + H + 2
    for i, (side, w, h) in enumerate([("left", l, 1), ("top", 1, t), ("right", r, 1), ("bottom", 1, bm)]):
        out.append('<rect id="%shint-%s-margin" x="%d" y="%d" width="%d" height="%d" fill="none"/>' % (p, side, x0 + i * 10, hy, w, h))
    return defs, "".join(out)

def svg(path, frames, extra=""):
    defs, body = zip(*frames)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write('<?xml version="1.0" encoding="UTF-8"?>\n<svg xmlns="http://www.w3.org/2000/svg" width="400" height="%d">\n<defs>%s</defs>\n%s%s\n</svg>\n'
                % (len(frames) * 60 + 20, "".join(defs), "\n".join(body), extra))

# name: (panel stops, panel top-edge highlight, tasks {prefix: (border, stops, hi)}, corner)
W = "#ffffff"
themes = {
    "start12-xp-classic": dict(
        panel=[(0, "#3f80ee", 1), (0.1, "#2a66df", 1), (0.5, "#245edb", 1), (0.92, "#1f53c4", 1), (1, "#1941a5", 1)],
        edge=("#6aa6f6", 1), c=4,
        tasks={
            "normal": (("#1a4bb5", 1), [(0, "#5a9bfb", 1), (1, "#3c81f3", 1)], (W, 0.35)),
            "hover": (("#1a4bb5", 1), [(0, "#7ab4ff", 1), (1, "#4f93ff", 1)], (W, 0.45)),
            "focus": (("#10368a", 1), [(0, "#1a48a8", 1), (1, "#2a63cf", 1)], None),
            "attention": (("#c76d10", 1), [(0, "#fcc77b", 1), (1, "#f39a32", 1)], (W, 0.4)),
            "minimized": (("#1a4bb5", 1), [(0, "#4f90f7", 1), (1, "#3577ea", 1)], (W, 0.25)),
        }),
    "start12-xp-modern": dict(
        panel=[(0, "#3a7bea", 1), (1, "#2c63cc", 1)],
        edge=(W, 0.35), c=8,
        tasks={
            "normal": ((W, 0.18), [(0, W, 0.14), (1, W, 0.08)], None),
            "hover": ((W, 0.32), [(0, W, 0.26), (1, W, 0.16)], None),
            "focus": ((W, 0.6), [(0, W, 0.38), (1, W, 0.26)], None),
            "attention": (("#fcc77b", 0.9), [(0, "#fcc77b", 0.9), (1, "#f39a32", 0.9)], None),
            "minimized": ((W, 0.1), [(0, W, 0.07), (1, W, 0.04)], None),
        }),
}
for name, t in themes.items():
    base = os.path.join(OUT, name)
    # panel: square, 2px edge rows; top edge = light line
    svg(os.path.join(base, "widgets/panel-background.svg"),
        [frame("", 10, 10, 60, 40, 2, None, t["panel"], hi=t["edge"], margins=(2, 3, 2, 2), gid="panel")],
        '<rect id="hint-stretch-borders" x="200" y="10" width="1" height="1" fill="none"/>')
    frames = [frame(pfx, 10, 10 + i * 60, 60, 40, t["c"], bd, st, hi=hi, margins=(6, 4, 6, 4), gid="t" + pfx)
              for i, (pfx, (bd, st, hi)) in enumerate(t["tasks"].items())]
    svg(os.path.join(base, "widgets/tasks.svg"), frames,
        '<rect id="hint-stretch-borders" x="200" y="10" width="1" height="1" fill="none"/>')
