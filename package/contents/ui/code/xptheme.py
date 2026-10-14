# Generates the Start12 XP Plasma Styles (taskbar: panel-background + tasks 9-slice SVGs, colors, metadata).
# All schemes x substyles:  python3 xptheme.py <outdir>       (install.sh -> ~/.local/share/plasma/desktoptheme)
# One custom colour:        python3 xptheme.py --custom '#3a6ea5' --sub classic --out <dir>   (main.qml)
# Any-style taskbar (T31):  python3 xptheme.py --taskbar colour=#101010 alpha=0.8 radius=8 line=0 buttons=win11 accent=3d8ee6 solid=0
#                             fallback=default --out <dir>   (main.qml; only panel/tasks/colors, rest = fallback)
#                             [image=<png/jpg> mode=tile|stretch|top|middle|bottom imagealpha=0.3 tint=3daee9] (T33)
import argparse, base64, json, os, struct

def frame(prefix, x0, y0, W, H, c, border, stops, hi=None, margins=(4, 4, 4, 4), gid="g", center="", under=None):
    """9 pieces of a rounded box. stops: [(offset, color, opacity)] vertical gradient.
    border: (color, opacity) or None. hi: top highlight (color, opacity) or None.
    under: (color, opacity, height, full) bar on the bottom edge (T34 task indicator); full = also in the
    corners, else only the stretched middle piece with round ends (Win11 pill, inset by c)."""
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
        if under and under[3] and sy > 0:
            body += rect(bx, by + c - under[2], c, under[2], 'fill="%s" fill-opacity="%s"' % under[:2])
        g(name, body)
    piece_corner("topleft", x1, y1, -1, -1, x0, y0)
    piece_corner("topright", x2, y1, 1, -1, x2, y0)
    piece_corner("bottomleft", x1, y2, -1, 1, x0, y2)
    piece_corner("bottomright", x2, y2, 1, 1, x2, y2)
    top = (rect(x1, y0, W - 2 * c, b, B) if border else "") + rect(x1, y0 + b, W - 2 * c, c - b, F)
    if hi:
        top += rect(x1, y0 + b, W - 2 * c, 1, 'fill="%s" fill-opacity="%s"' % hi)
    g("top", top)
    bar = ""
    if under:
        bar = '<rect x="%s" y="%s" width="%s" height="%s" rx="%s" fill="%s" fill-opacity="%s"/>' % (
            x1, y0 + H - under[2], W - 2 * c, under[2], 0 if under[3] else under[2] / 2, under[0], under[1])
    g("bottom", rect(x1, y2, W - 2 * c, c - b, F) + (rect(x1, y0 + H - b, W - 2 * c, b, B) if border else "") + bar)
    g("left", (rect(x0, y1, b, H - 2 * c, B) if border else "") + rect(x0 + b, y1, c - b, H - 2 * c, F))
    g("right", rect(x2, y1, c - b, H - 2 * c, F) + (rect(x0 + W - b, y1, b, H - 2 * c, B) if border else ""))
    g("center", rect(x1, y1, W - 2 * c, H - 2 * c, F) + center)
    l, t, r, bm = margins
    hy = y0 + H + 2
    for i, (side, w, h) in enumerate([("left", l, 1), ("top", 1, t), ("right", r, 1), ("bottom", 1, bm)]):
        out.append('<rect id="%shint-%s-margin" x="%d" y="%d" width="%d" height="%d" fill="none"/>' % (p, side, x0 + i * 10, hy, w, h))
    return defs, "".join(out)

def svg(path, frames, extra="", size=(400, 0)):
    defs, body = zip(*frames)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write('<?xml version="1.0" encoding="UTF-8"?>\n<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="%d" height="%d">\n<defs>%s</defs>\n%s%s\n</svg>\n'
                % (size[0], size[1] or len(frames) * 60 + 20, "".join(defs), "\n".join(body), extra))

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
        [frame("", 10, 10, 60, 40, 2, None, t["panel"], hi=t["edge"], margins=(2, 2, 2, 2), gid="panel")],
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

def imgsize(data):
    """(w, h) of PNG / JPEG bytes."""
    if data[:8] == b"\x89PNG\r\n\x1a\n":
        return struct.unpack(">II", data[16:24])
    i = 2
    while i < len(data) - 9:  # JPEG: walk the segments to the SOFn frame header
        seg, ln = data[i + 1], struct.unpack(">H", data[i + 2:i + 4])[0]
        if 0xC0 <= seg <= 0xCF and seg not in (0xC4, 0xC8, 0xCC):
            h, w = struct.unpack(">HH", data[i + 5:i + 9])
            return w, h
        i += 2 + ln
    raise ValueError("not a PNG or JPEG image")

def taskbar(base, colour="#101010", alpha="0.8", radius="0", line="0", fallback="default",
            image="", mode="tile", imagealpha="1", tint="", buttons="win10", accent="", solid="0"):
    """Plasma Style that only replaces panel-background (plain, opaque/ and translucent/ for blur), tasks
    and colors; everything else comes from FallbackTheme (the user's own style).
    T33 texture: image (PNG/JPEG) in the 9-slice center; mode tile (native size, hint-tile-center) | stretch |
    top/middle/bottom (scaled to cover a panel-shaped box, cropped at that edge); tint = colour multiplied over."""
    B = "#" + colour.lstrip("#")[-6:]
    rgb(B)
    a, r = max(0.0, min(1.0, float(alpha))), max(2, min(24, int(radius)))
    hi = (mix(B, W, .35), 1) if line not in ("0", "", "false") else None
    fw, fh, tex, hints = 60, 40, "", '<rect id="hint-stretch-borders" x="200" y="10" width="1" height="1" fill="none"/>'
    if image:
        with open(image, "rb") as f:
            data = f.read()
        iw, ih = imgsize(data)
        mime = "png" if data[:4] == b"\x89PNG" else "jpeg"
        if mode == "tile":
            fw, fh = iw + 2 * r, ih + 2 * r
            hints += '<rect id="hint-tile-center" x="200" y="20" width="1" height="1" fill="none"/>'
        elif mode != "stretch":
            # ponytail: the center piece is panel-shaped (48:1), Plasma stretches it; exact for a ~1920x40 panel
            fw, fh = 960 + 2 * r, 20 + 2 * r
        par = {"stretch": "none", "top": "xMidYMin slice", "middle": "xMidYMid slice", "bottom": "xMidYMax slice"}.get(mode, "none")
        x, y, w, h = 10 + r, 10 + r, fw - 2 * r, fh - 2 * r
        tex = '<image x="%d" y="%d" width="%d" height="%d" preserveAspectRatio="%s" opacity="{op}" xlink:href="data:image/%s;base64,%s"/>' % (
            x, y, w, h, par, mime, base64.b64encode(data).decode())
        if tint:
            tex += '<rect x="%d" y="%d" width="%d" height="%d" fill="#%s" comp-op="multiply"/>' % (
                x, y, w, h, tint.lstrip("#")[-6:])
    for pre, op in (("", a), ("translucent/", a), ("opaque/", 1)):
        t = tex.replace("{op}", "%.3f" % (op * max(0.0, min(1.0, float(imagealpha)))))
        svg(os.path.join(base, pre + "widgets/panel-background.svg"),
            [frame("", 10, 10, fw, fh, r, None, [(0, B, op), (1, B, op)], hi=hi, margins=(2, 2, 2, 2), gid="panel", center=t),
             frame("mask", 10, 20 + fh, fw, fh, r, None, [(0, K, 1), (1, K, 1)], gid="mask")],
            hints.replace('x="200"', 'x="%d"' % (fw + 40)), size=(fw + 60, 2 * fh + 40))
    ink = "#000000" if light(B) else W
    acc = "#" + (accent.lstrip("#")[-6:] or "3d8ee6")
    fa = 2 if solid not in ("0", "", "false") else 1  # T34 Start11 "Paint focused item backgrounds less transparent"
    def fill(col, op, op2=None):
        return [(0, col, min(1, op)), (1, col, min(1, op if op2 is None else op2))]
    clear = (None, fill(ink, 0), None)
    att = (None, fill("#f39a32", .8), None)
    # T34 buttons: (corner, {prefix: (border, stops, hi, under)}); plasma = no tasks.svg, the fallback's is used.
    # ponytail: indicators sit on the bottom edge (bottom panel); a left/top panel would need north-/west- prefixes.
    tasks = {
        "win10": (2, {"normal": clear + ((ink, .45, 2, True),), "minimized": clear + ((ink, .3, 2, True),),
                      "hover": (None, fill(ink, .12), None, (ink, .45, 2, True)),
                      "focus": (None, fill(ink, .18 * fa), None, (acc, 1, 2, True)), "attention": att + (None,)}),
        "win11": (6, {"normal": clear + ((ink, .4, 3, False),), "minimized": clear + ((ink, .25, 3, False),),
                      "hover": (None, fill(ink, .08), None, (ink, .4, 3, False)),
                      "focus": ((ink, .08), fill(ink, .1 * fa), None, (acc, 1, 3, False)), "attention": att + (None,)}),
        "win7": (3, {"normal": ((W, .25), fill(W, .14, .02), (W, .3), None),
                     "minimized": ((W, .15), fill(W, .07, .01), None, None),
                     "hover": ((W, .45), fill(W, .3, .08), (W, .5), None),
                     "focus": ((W, .55), fill(W, .22 * fa, .06 * fa), (W, .6), None),
                     "attention": ((W, .5), fill("#f39a32", .85, .55), (W, .5), None)}),
    }.get(buttons)
    if tasks:
        c, states = tasks
        frames = [frame(pfx, 10, 10 + i * 60, 60, 40, c, bd, st, hi=h, margins=(6, 4, 6, 4), gid="t" + pfx, under=u)
                  for i, (pfx, (bd, st, h, u)) in enumerate(states.items())]
        svg(os.path.join(base, "widgets/tasks.svg"), frames,
            '<rect id="hint-stretch-borders" x="200" y="10" width="1" height="1" fill="none"/>')
    with open(os.path.join(base, "colors"), "w") as f:
        # No XP-orange Selection group here: selection/highlight stay the system's (blue by default).
        f.write(colors(B).split("[Colors:Selection]")[0])
    with open(os.path.join(base, "plasmarc"), "w") as f:
        f.write("[Settings]\nFallbackTheme=%s\n\n[AdaptiveTransparency]\nenabled=false\n" % fallback)
    name = os.path.basename(os.path.normpath(base))
    with open(os.path.join(base, "metadata.json"), "w") as f:
        json.dump({"KPlugin": {"Authors": [{"Name": "Start12"}], "Description": "Start12 taskbar on top of " + fallback,
                               "Id": name, "License": "LGPL", "Name": "Start12 Taskbar " + B, "Version": "1.0"},
                   "X-Plasma-API": "5.0", "X-Plasma-FallbackTheme": fallback}, f, indent=4)

if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("outdir", nargs="?")
    ap.add_argument("--custom")
    ap.add_argument("--sub", choices=("classic", "modern"), default="classic")
    ap.add_argument("--out")
    ap.add_argument("--taskbar", nargs="*", metavar="key=value")
    a = ap.parse_args()
    if a.taskbar is not None:
        taskbar(a.out, **dict(kv.split("=", 1) for kv in a.taskbar))
    elif a.custom:
        rgb(a.custom)  # rejects anything that is not a hex colour
        write(a.out, derive("#" + a.custom.lstrip("#")[-6:], a.sub), "%s %s" % (a.sub.title(), a.custom))
    else:
        for sub in ("classic", "modern"):
            write(os.path.join(a.outdir, "start12-xp-" + sub), BLUE[sub], sub.title())
            for sch, B in BASES.items():
                write(os.path.join(a.outdir, "start12-xp-%s-%s" % (sub, sch)), derive(B, sub), "%s %s" % (sub.title(), sch.title()))
