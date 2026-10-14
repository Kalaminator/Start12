# Generates the Start12 XP Plasma Styles (taskbar: panel-background + tasks 9-slice SVGs, colors, metadata).
# All schemes x substyles:  python3 xptheme.py <outdir>       (install.sh -> ~/.local/share/plasma/desktoptheme)
# One custom colour:        python3 xptheme.py --custom '#3a6ea5' --sub classic --out <dir>   (main.qml)
# Window decorations (T26a): python3 xptheme.py --deco <outdir>  |  --deco --custom <hex> --sub s --out <dir>
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

# T26a window decorations: Aurorae SVG themes (~/.local/share/aurorae/themes/<name>), same names as the Plasma Styles.
DECO_BASES = {"blue": "#0054e3", "olive": BASES["olive"], "silver": BASES["silver"]}
BUTTONS = ("close", "minimize", "maximize", "restore", "help", "alldesktops", "keepabove", "keepbelow", "shade")
GLYPHS = {  # unit box 0..1, stroked
    "close": "M .2,.2 L .8,.8 M .8,.2 L .2,.8", "minimize": "M .2,.78 L .62,.78",
    "maximize": "M .18,.2 H .82 V .82 H .18 Z M .18,.3 H .82", "restore": "M .32,.18 H .84 V .62 M .16,.38 H .66 V .84 H .16 Z M .16,.46 H .66",
    "help": "M .3,.32 C .3,.1 .72,.1 .72,.32 C .72,.5 .5,.5 .5,.66 M .5,.82 V .86", "alldesktops": "M .3,.5 H .7 M .5,.3 V .7",
    "keepabove": "M .2,.66 L .5,.3 L .8,.66", "keepbelow": "M .2,.34 L .5,.7 L .8,.34", "shade": "M .2,.6 L .5,.3 L .8,.6 M .2,.82 H .8"}

def deco_frame(prefix, y0, T, S, ry, stops, side, line, hi, gid):
    """Window frame: title piece T high, borders S wide (= the rc borders, Aurorae aligns them), top corners
    rounded (rx S, ry), bottom corners square. Box 100 x T+40 at (10, y0)."""
    x0, W, H = 10, 100, T + 40
    x2, yb, F, L, Sd = x0 + W - S, y0 + H - S, 'fill="url(#%s)"' % gid, 'fill="%s"' % line, 'fill="%s"' % side
    r = lambda x, y, w, h, f: '<rect x="%s" y="%s" width="%s" height="%s" %s/>' % (x, y, w, h, f)
    def arc(cx, sx, inset, f):  # top corner shape: outer edge at cx, toward the inside by sx
        ex, ey = cx + sx * inset, y0 + inset
        return '<path d="M %s,%s V %s A %s %s 0 0 %d %s,%s H %s V %s Z" %s/>' % (
            ex, y0 + T, y0 + ry, S - inset, ry - inset, 1 if sx > 0 else 0, cx + sx * S, ey, cx + sx * S, y0 + T, f)
    defs = '<linearGradient id="%s" gradientUnits="userSpaceOnUse" x1="0" y1="%d" x2="0" y2="%d">%s</linearGradient>' % (
        gid, y0, y0 + T, "".join('<stop offset="%s" stop-color="%s"/>' % s for s in stops))
    p = prefix + "-"
    g = lambda n, b: '<g id="%s%s">%s</g>' % (p, n, b)
    out = [g("topleft", r(x0, y0, S, T, 'fill="none"') + arc(x0, 1, 0, L) + arc(x0, 1, 1, F)),
           g("topright", r(x2, y0, S, T, 'fill="none"') + arc(x0 + W, -1, 0, L) + arc(x0 + W, -1, 1, F)),
           g("top", r(x0 + S, y0, W - 2 * S, 1, L) + r(x0 + S, y0 + 1, W - 2 * S, T - 1, F) + r(x0 + S, y0 + 1, W - 2 * S, 1, 'fill="%s"' % hi)),
           g("left", r(x0, y0 + T, 1, H - T - S, L) + r(x0 + 1, y0 + T, S - 1, H - T - S, Sd)),
           g("right", r(x2, y0 + T, S - 1, H - T - S, Sd) + r(x0 + W - 1, y0 + T, 1, H - T - S, L)),
           g("bottomleft", r(x0, yb, S, S, L) + r(x0 + 1, yb, S - 1, S - 1, Sd)),
           g("bottomright", r(x2, yb, S, S, L) + r(x2, yb, S - 1, S - 1, Sd)),
           g("bottom", r(x0 + S, yb, W - 2 * S, S - 1, Sd) + r(x0 + S, y0 + H - 1, W - 2 * S, 1, L)),
           g("center", r(x0 + S, y0 + T, W - 2 * S, H - T - S, Sd))]
    return defs, "".join(out)

def write_deco(base, B, sub, label):
    """Aurorae theme for panel/title colour B: decoration.svg, one svg per button, <name>rc, metadata.desktop."""
    name = os.path.basename(os.path.normpath(base))
    lt = light(B)
    ink = "#1f2440" if lt else W
    Bi = mix(B, "#d4d8e4", .55)  # inactive: washed out
    classic = sub == "classic"
    S, ry, T, bs, c = (4, 7, 28, 21, 3) if classic else (5, 10, 30, 20, 5)
    def stops(b):
        return ([(0, mix(b, W, .4)), (.12, mix(b, W, .08)), (.5, b), (.85, mix(b, W, .1)), (1, mix(b, K, .15))] if classic
                else [(0, mix(b, W, .14)), (1, b)])
    svg(os.path.join(base, "decoration.svg"),
        [deco_frame("decoration", 10, T, S, ry, stops(B), mix(B, K, .05), mix(B, K, .45), mix(B, W, .5), "da"),
         deco_frame("decoration-inactive", T + 70, T, S, ry, stops(Bi), Bi, mix(Bi, K, .3), mix(Bi, W, .5), "di")], size=(130, 2 * T + 140))
    red = [(0, "#e8906c", 1), (1, "#c13c13", 1)]
    for btn in BUTTONS:
        frames = []
        for i, st in enumerate(("active", "hover", "pressed", "deactivated", "inactive", "hover-inactive", "pressed-inactive", "deactivated-inactive")):
            act, b = not st.endswith("inactive"), B if not st.endswith("inactive") else Bi
            k = {"hover": .25, "pressed": -.2}.get(st.split("-")[0], 0)
            tone = lambda h: mix(h, W, k) if k > 0 else mix(h, K, -k)
            gl = W if (btn == "close" or not lt) else ink
            if classic:
                fill = [(o, tone(col), 1) for o, col, _ in red] if btn == "close" else [(0, tone(mix(b, W, .4)), 1), (1, tone(mix(b, W, .02)), 1)]
                bd = (W, 1 if act else .6)
            else:  # modern: translucent, close turns red on hover/press
                hot = btn == "close" and st.split("-")[0] in ("hover", "pressed")
                fill = [(o, tone(col), 1) for o, col, _ in red] if hot else [(0, ink, {"hover": .32, "pressed": .12}.get(st.split("-")[0], .18)), (1, ink, {"hover": .24, "pressed": .08}.get(st.split("-")[0], .1))]
                bd = None
            op = .45 if st.startswith("deactivated") else 1 if act else .7
            s = bs - 2 * c - 2 if classic else bs - 2 * c  # glyph stays inside the center piece
            gly = '<path d="%s" transform="translate(%s,%s) scale(%s)" fill="none" stroke="%s" stroke-opacity="%s" stroke-width="%s" stroke-linecap="round" stroke-linejoin="round"/>' % (
                GLYPHS[btn], 10 + c + (bs - 2 * c - s) / 2, 10 + i * 40 + c + (bs - 2 * c - s) / 2, s, gl, op, round(2.0 / s, 3))
            frames.append(frame(st, 10, 10 + i * 40, bs, bs, c, bd, fill, gid="b%d" % i, margins=(c, c, c, c), center=gly))
        svg(os.path.join(base, btn + ".svg"), frames, size=(60, 8 * 40 + 20))
    rgbs = lambda h: "%d,%d,%d" % rgb(h)
    with open(os.path.join(base, name + "rc"), "w") as f:
        f.write("[General]\nActiveTextColor=%s\nInactiveTextColor=%s\nUseTextShadow=%s\nActiveTextShadowColor=%s\n"
                "InactiveTextShadowColor=%s\nTextShadowOffsetX=1\nTextShadowOffsetY=1\nTitleAlignment=Left\n"
                "TitleVerticalAlignment=Center\nAnimation=0\nShadow=true\n\n[Layout]\nBorderLeft=%d\nBorderRight=%d\n"
                "BorderBottom=%d\nTitleEdgeTop=%d\nTitleEdgeBottom=%d\nTitleEdgeLeft=%d\nTitleEdgeRight=%d\nTitleBorderLeft=4\n"
                "TitleBorderRight=4\nTitleHeight=%d\nButtonWidth=%d\nButtonHeight=%d\nButtonSpacing=2\nButtonMarginTop=0\n"
                "ExplicitButtonSpacer=8\nPaddingTop=0\nPaddingBottom=0\nPaddingLeft=0\nPaddingRight=0\n"
                % (rgbs(ink), rgbs(mix(ink, Bi, .35)), "false" if lt else "true", rgbs(mix(B, K, .6)), rgbs(mix(Bi, K, .3)),
                   S, S, S, (T - 22) // 2, (T - 22) // 2, S + 2, S + 2, 22, bs, bs))
    with open(os.path.join(base, "metadata.desktop"), "w") as f:
        f.write("[Desktop Entry]\nName=Start12 XP %s\nComment=Windows XP window decoration for the Start12 XP menu\n"
                "X-KDE-PluginInfo-Author=Start12\nX-KDE-PluginInfo-Name=%s\nX-KDE-PluginInfo-Version=1.0\n"
                "X-KDE-PluginInfo-License=LGPL\n" % (label, name))

if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("outdir", nargs="?")
    ap.add_argument("--custom")
    ap.add_argument("--sub", choices=("classic", "modern"), default="classic")
    ap.add_argument("--out")
    ap.add_argument("--taskbar", nargs="*", metavar="key=value")
    ap.add_argument("--deco", action="store_true", help="write Aurorae window decorations instead (T26a)")
    a = ap.parse_args()
    if a.deco:
        if a.custom:
            rgb(a.custom)
            write_deco(a.out, "#" + a.custom.lstrip("#")[-6:], a.sub, "%s %s" % (a.sub.title(), a.custom))
        else:
            for sub in ("classic", "modern"):
                for sch, B in DECO_BASES.items():
                    write_deco(os.path.join(a.outdir, "start12-xp-" + sub + ("" if sch == "blue" else "-" + sch)), B, sub,
                               "%s %s" % (sub.title(), sch.title()))
    elif a.taskbar is not None:
        taskbar(a.out, **dict(kv.split("=", 1) for kv in a.taskbar))
    elif a.custom:
        rgb(a.custom)  # rejects anything that is not a hex colour
        write(a.out, derive("#" + a.custom.lstrip("#")[-6:], a.sub), "%s %s" % (a.sub.title(), a.custom))
    else:
        for sub in ("classic", "modern"):
            write(os.path.join(a.outdir, "start12-xp-" + sub), BLUE[sub], sub.title())
            for sch, B in BASES.items():
                write(os.path.join(a.outdir, "start12-xp-%s-%s" % (sub, sch)), derive(B, sub), "%s %s" % (sub.title(), sch.title()))
