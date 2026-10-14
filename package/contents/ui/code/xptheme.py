# Generates the Start12 XP Plasma Styles (taskbar: panel-background + tasks 9-slice SVGs, colors, metadata).
# All schemes x substyles:  python3 xptheme.py <outdir>       (install.sh -> ~/.local/share/plasma/desktoptheme)
# One custom colour:        python3 xptheme.py --custom '#3a6ea5' --sub classic --out <dir>   (main.qml)
import argparse, json, os

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

W, K = "#ffffff", "#000000"
ORANGE = [(0, "#fcc77b", 1), (1, "#f39a32", 1)]

def rgb(h):
    h = h.lstrip("#")[-6:]
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))

def mix(a, b, t):
    """a blended toward b by t (0..1), as #rrggbb."""
    return "#%02x%02x%02x" % tuple(round(x + (y - x) * t) for x, y in zip(rgb(a), rgb(b)))

def light(h):
    r, g, b = rgb(h)
    return 0.299 * r + 0.587 * g + 0.114 * b > 150

# Luna blue, exactly as before.
BLUE = {
    "classic": dict(
        panel=[(0, "#3f80ee", 1), (0.1, "#2a66df", 1), (0.5, "#245edb", 1), (0.92, "#1f53c4", 1), (1, "#1941a5", 1)],
        edge=("#6aa6f6", 1), c=4, base="#245edb",
        tasks={
            "normal": (("#1a4bb5", 1), [(0, "#5a9bfb", 1), (1, "#3c81f3", 1)], (W, 0.35)),
            "hover": (("#1a4bb5", 1), [(0, "#7ab4ff", 1), (1, "#4f93ff", 1)], (W, 0.45)),
            "focus": (("#10368a", 1), [(0, "#1a48a8", 1), (1, "#2a63cf", 1)], None),
            "attention": (("#c76d10", 1), ORANGE, (W, 0.4)),
            "minimized": (("#1a4bb5", 1), [(0, "#4f90f7", 1), (1, "#3577ea", 1)], (W, 0.25)),
        }),
    "modern": dict(
        panel=[(0, "#3a7bea", 1), (1, "#2c63cc", 1)],
        edge=(W, 0.35), c=8, base="#2c63cc",
        tasks={
            "normal": ((W, 0.18), [(0, W, 0.14), (1, W, 0.08)], None),
            "hover": ((W, 0.32), [(0, W, 0.26), (1, W, 0.16)], None),
            "focus": ((W, 0.6), [(0, W, 0.38), (1, W, 0.26)], None),
            "attention": (("#fcc77b", 0.9), [(0, "#fcc77b", 0.9), (1, "#f39a32", 0.9)], None),
            "minimized": ((W, 0.1), [(0, W, 0.07), (1, W, 0.04)], None),
        }),
}
# Other schemes: taskbar body colour; the rest is derived from it.
BASES = {"olive": "#7f9656", "silver": "#c9c9d9"}

def derive(B, sub):
    if sub == "classic":
        return dict(
            panel=[(0, mix(B, W, .25), 1), (0.1, mix(B, W, .08), 1), (0.5, B, 1), (0.92, mix(B, K, .12), 1), (1, mix(B, K, .3), 1)],
            edge=(mix(B, W, .45), 1), c=4, base=B,
            tasks={
                "normal": ((mix(B, K, .3), 1), [(0, mix(B, W, .3), 1), (1, mix(B, W, .15), 1)], (W, 0.35)),
                "hover": ((mix(B, K, .3), 1), [(0, mix(B, W, .45), 1), (1, mix(B, W, .3), 1)], (W, 0.45)),
                "focus": ((mix(B, K, .5), 1), [(0, mix(B, K, .3), 1), (1, mix(B, K, .1), 1)], None),
                "attention": (("#c76d10", 1), ORANGE, (W, 0.4)),
                "minimized": ((mix(B, K, .3), 1), [(0, mix(B, W, .22), 1), (1, mix(B, W, .08), 1)], (W, 0.25)),
            })
    ink = "#1f2440" if light(B) else W  # light panel: dark translucent buttons instead of white ones
    k = 0.6 if light(B) else 1
    return dict(
        panel=[(0, mix(B, W, .12), 1), (1, B, 1)], edge=(W, 0.35), c=8, base=B,
        tasks={
            "normal": ((ink, .18 * k), [(0, ink, .14 * k), (1, ink, .08 * k)], None),
            "hover": ((ink, .32 * k), [(0, ink, .26 * k), (1, ink, .16 * k)], None),
            "focus": ((ink, .6 * k), [(0, ink, .38 * k), (1, ink, .26 * k)], None),
            "attention": (("#fcc77b", 0.9), [(0, "#fcc77b", 0.9), (1, "#f39a32", 0.9)], None),
            "minimized": ((ink, .1 * k), [(0, ink, .07 * k), (1, ink, .04 * k)], None),
        })

def colors(B):
    """Plasma colour scheme: text readable on the panel colour B."""
    c = lambda h: "%d,%d,%d" % rgb(h)
    lt = light(B)
    fg = "#1f2440" if lt else W
    acc, acc2 = ("#a85a00", "#7a4000") if lt else ("#fcc77b", "#f39a32")
    group = "\n".join([
        "BackgroundNormal=" + c(B), "BackgroundAlternate=" + c(mix(B, K, .12)),
        "ForegroundNormal=" + c(fg), "ForegroundInactive=" + c(mix(fg, B, .25)), "ForegroundActive=" + c(fg),
        "ForegroundLink=" + c(acc), "ForegroundVisited=" + c(acc2),
        "ForegroundNegative=" + ("170,30,20" if lt else "255,120,100"), "ForegroundNeutral=" + c(acc),
        "ForegroundPositive=" + ("30,110,30" if lt else "140,230,130"),
        "DecorationFocus=" + c(acc), "DecorationHover=" + c(mix(B, W, .4))])
    out = "".join("[Colors:%s]\n%s\n\n" % (g, group) for g in ("Window", "View", "Button", "Header", "Complementary", "Tooltip"))
    return out + """[Colors:Selection]
BackgroundNormal=243,154,50
BackgroundAlternate=252,199,123
ForegroundNormal=0,0,0
ForegroundInactive=40,40,40
ForegroundActive=0,0,0
ForegroundLink=0,19,107
ForegroundVisited=0,19,107
ForegroundNegative=150,20,10
ForegroundNeutral=90,50,0
ForegroundPositive=20,90,20
DecorationFocus=243,154,50
DecorationHover=252,199,123
"""

def write(base, t, label):
    name = os.path.basename(os.path.normpath(base))
    # panel: square, 2px edge rows; top edge = light line
    svg(os.path.join(base, "widgets/panel-background.svg"),
        [frame("", 10, 10, 60, 40, 2, None, t["panel"], hi=t["edge"], margins=(2, 3, 2, 2), gid="panel")],
        '<rect id="hint-stretch-borders" x="200" y="10" width="1" height="1" fill="none"/>')
    frames = [frame(pfx, 10, 10 + i * 60, 60, 40, t["c"], bd, st, hi=hi, margins=(6, 4, 6, 4), gid="t" + pfx)
              for i, (pfx, (bd, st, hi)) in enumerate(t["tasks"].items())]
    svg(os.path.join(base, "widgets/tasks.svg"), frames,
        '<rect id="hint-stretch-borders" x="200" y="10" width="1" height="1" fill="none"/>')
    with open(os.path.join(base, "colors"), "w") as f:
        f.write(colors(t["base"]))
    with open(os.path.join(base, "plasmarc"), "w") as f:
        f.write("[Settings]\nFallbackTheme=default\n\n[AdaptiveTransparency]\nenabled=false\n")
    with open(os.path.join(base, "metadata.json"), "w") as f:
        json.dump({"KPlugin": {"Authors": [{"Name": "Start12"}], "Description": "Windows XP taskbar for the Start12 XP menu",
                               "Id": name, "License": "LGPL", "Name": "Start12 XP " + label, "Version": "1.0"},
                   "X-Plasma-API": "5.0"}, f, indent=4)

if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("outdir", nargs="?")
    ap.add_argument("--custom")
    ap.add_argument("--sub", choices=("classic", "modern"), default="classic")
    ap.add_argument("--out")
    a = ap.parse_args()
    if a.custom:
        rgb(a.custom)  # rejects anything that is not a hex colour
        write(a.out, derive("#" + a.custom.lstrip("#")[-6:], a.sub), "%s %s" % (a.sub.title(), a.custom))
    else:
        for sub in ("classic", "modern"):
            write(os.path.join(a.outdir, "start12-xp-" + sub), BLUE[sub], sub.title())
            for sch, B in BASES.items():
                write(os.path.join(a.outdir, "start12-xp-%s-%s" % (sub, sch)), derive(B, sub), "%s %s" % (sub.title(), sch.title()))
