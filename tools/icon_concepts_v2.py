#!/usr/bin/env python3
"""v0.2 app icon concepts A-D and their home-screen preview sheet (Pillow).

Brief (owner, v0.2 section 5): bold, high-contrast, a strong dragon silhouette
or head, dark slate/graphite background with ONE bright accent, readable at
48 px, no text. Each concept is an opaque full-bleed square drawn from vector
shapes in a 0..100 unit space (supersampled), so it scales to any size and to
the adaptive-icon layers.

  python3 tools/icon_concepts_v2.py [docs/store/icon_concepts_v2.png]

The preview sheet shows every concept at 512 px, at real launcher size
(48 dp = 48 px at the 1x reference density) inside simulated Android home
screens among generic colourful app icons on a light and a dark wallpaper,
and a 48 px close-up (1:1 and magnified). The neighbour icons are generic
shapes, not real apps.
"""
import math
import os
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

SS = 8
FONT = "assets/fonts/Inter-SemiBold.ttf"
FONT_R = "assets/fonts/Inter-Regular.ttf"

GRAPHITE = (24, 27, 31)
SLATE = (33, 44, 54)
BONE = (238, 233, 221)


def _u(pts, size):
    k = size / 100.0
    return [(x * k, y * k) for x, y in pts]


def _mirror(half):
    """Right half (x >= 50, listed top to bottom) -> closed symmetric outline."""
    return half + [(100 - x, y) for x, y in reversed(half)]


def _bg(size, top, bottom):
    im = Image.new("RGB", (size, size), top)
    d = ImageDraw.Draw(im)
    for y in range(size):
        t = y / max(1, size - 1)
        d.line([(0, y), (size, y)], fill=tuple(int(a + (b - a) * t) for a, b in zip(top, bottom)))
    return im


def _layer(size):
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    return im, ImageDraw.Draw(im)


# --- A: Ember Eye — bone dragon head in profile, one amber eye -------------
AMBER = (255, 168, 28)

HEAD_PROFILE = [
    (93, 47), (82, 41), (70, 38), (62, 31),                      # snout ridge to brow
    (58, 30), (24, 12), (50, 37),                                # long swept horn
    (46, 39), (22, 30), (44, 45),                                # second horn
    (40, 47), (29, 50), (38, 55), (27, 61), (36, 65),            # crest spikes
    (26, 73), (34, 77), (28, 97), (64, 97),                      # neck
    (60, 82), (63, 68), (80, 62), (91, 56), (88, 53), (93, 51),  # throat, jaw, fang
]


def concept_a(size, bg=True):
    s = size * SS
    base = _bg(s, (34, 40, 47), GRAPHITE).convert("RGBA") if bg else Image.new("RGBA", (s, s), (0, 0, 0, 0))
    lay, d = _layer(s)
    d.polygon(_u(HEAD_PROFILE, s), fill=BONE + (255,))
    # mouth line + nostril cut back into the dark
    d.line(_u([(92, 51), (74, 54), (66, 59)], s), fill=GRAPHITE + (255,), width=int(s * 0.02))
    d.ellipse(_box(87, 45.5, 1.5, s), fill=GRAPHITE + (255,))
    # glowing amber eye
    glow, gd = _layer(s)
    gd.ellipse(_box(65, 42, 9, s), fill=AMBER + (120,))
    glow = glow.filter(ImageFilter.GaussianBlur(s * 0.03))
    lay = Image.alpha_composite(lay, glow)
    d = ImageDraw.Draw(lay)
    d.polygon(_u([(57, 42), (66, 37.5), (74, 42), (64, 45.5)], s), fill=AMBER + (255,))
    d.polygon(_u([(65, 38.6), (66.6, 42), (65, 44.8), (63.6, 42)], s), fill=GRAPHITE + (255,))
    return _finish(base, lay, size)


# --- B: Arrow Wyvern — heraldic wings-up wyvern in electric cyan -----------
CYAN = (40, 224, 255)

WYVERN_HALF = [
    (50, 9), (53, 10), (58, 3), (56, 13), (56, 18),              # head, horn
    (53, 24), (54, 30),                                          # neck
    (57, 32), (72, 15), (97, 9),                                 # arm, wrist, outer finger
    (90, 25), (97, 36),                                          # scallop, finger
    (85, 37), (88, 52),                                          # scallop, finger
    (76, 47), (74, 60),                                          # scallop, finger
    (65, 53), (59, 58),                                          # scallop to body
    (61, 67), (66, 79), (68, 85), (60, 83), (56, 74),            # leg + foot
    (53, 80), (50, 82),                                          # tail root
]


def concept_b(size, bg=True):
    s = size * SS
    base = _bg(s, SLATE, GRAPHITE).convert("RGBA") if bg else Image.new("RGBA", (s, s), (0, 0, 0, 0))
    lay, d = _layer(s)
    d.polygon(_u(_mirror(WYVERN_HALF), s), fill=CYAN + (255,))
    # wing bones cut back in, so it reads as a membrane wing, not feathers
    dark = GRAPHITE + (255,)
    for side in (1, -1):
        for tip in ((97, 36), (88, 52), (74, 60)):
            d.line(_u([(50 + side * 22, 15.5), (50 + side * (tip[0] - 50) * 0.92, tip[1] * 0.92 + 1)], s),
                   fill=SLATE + (255,), width=int(s * 0.012))
        d.polygon(_u([(50 + side * 1.6, 13), (50 + side * 4.6, 11.5), (50 + side * 3.6, 15)], s), fill=dark)
    # long tail swinging right with an arrowhead tip
    tail = _u(_bezier([(50, 80), (48, 92), (68, 90), (74, 96)], 24), s)
    for p0, p1 in zip(tail, tail[1:]):
        d.line([p0, p1], fill=CYAN + (255,), width=int(s * 0.04))
    d.polygon(_u([(84, 98), (71, 99.5), (74, 91)], s), fill=CYAN + (255,))
    return _finish(base, lay, size)


# --- C: Crowned Head — front-facing horned head in ember orange ------------
EMBER = (255, 96, 48)

FRONT_HALF = [
    (50, 26), (58, 24), (66, 14), (80, 4), (74, 20), (70, 30),   # horn
    (82, 28), (74, 38),                                          # side frill spike
    (72, 48), (84, 52), (72, 58),                                # cheek spike
    (66, 70), (60, 82), (56, 90), (50, 92),                      # jaw to chin
]


def concept_c(size, bg=True):
    s = size * SS
    base = _bg(s, (30, 34, 39), (17, 19, 22)).convert("RGBA") if bg else Image.new("RGBA", (s, s), (0, 0, 0, 0))
    lay, d = _layer(s)
    pts = _mirror(FRONT_HALF)
    d.polygon(_u([(x, y + 3) for x, y in pts], s), fill=EMBER + (255,))
    dark = GRAPHITE + (255,)
    for side in (1, -1):  # angled eyes and nostrils cut out
        e = [(50 + side * 7, 49), (50 + side * 22, 41), (50 + side * 18, 53)]
        d.polygon(_u(e, s), fill=dark)
        d.ellipse(_box(50 + side * 4.2, 85, 1.6, s), fill=dark)
    d.polygon(_u([(44, 36), (50, 44), (56, 36), (50, 40)], s), fill=dark)   # brow V
    d.line(_u([(46, 62), (50, 74), (54, 62)], s), fill=dark, width=int(s * 0.012))  # snout ridge
    return _finish(base, lay, size)


# --- D: Dragon Arrow — the arrow IS the dragon: neck shaft, horned head ----
GOLD = (255, 200, 40)


def _rot(pts, ang, origin):
    c, sn = math.cos(ang), math.sin(ang)
    ox, oy = origin
    return [(ox + x * c - y * sn, oy + x * sn + y * c) for x, y in pts]


def concept_d(size, bg=True):
    s = size * SS
    base = _bg(s, (31, 38, 45), GRAPHITE).convert("RGBA") if bg else Image.new("RGBA", (s, s), (0, 0, 0, 0))
    lay, d = _layer(s)
    col = GOLD + (255,)
    ang, org = -math.pi / 4, (55, 45)          # arrow flies up-right
    R = lambda pts: _u(_rot(pts, ang, org), s)  # noqa: E731
    d.polygon(R([(-52, -4.5), (2, -4.5), (2, 4.5), (-52, 4.5)]), fill=col)            # shaft / neck
    for side in (1, -1):                                                              # swept fletching
        for x0 in (-30, -42):
            d.polygon(R([(x0, side * 4), (x0 - 12, side * 16), (x0 - 20, side * 16), (x0 - 9, side * 4)]),
                      fill=col)
    head = [(-4, -6), (6, -12), (17, -12), (31, -7), (45, -1), (30, 1.5), (40, 7),
            (24, 11), (6, 10), (-4, 6)]
    d.polygon(R(head), fill=col)
    d.polygon(R([(6, -11), (-16, -26), (0, -7)]), fill=col)                            # horn
    d.polygon(R([(14, -11.5), (2, -24), (10, -10)]), fill=col)                         # second horn
    dark = GRAPHITE + (255,)
    d.polygon(R([(14, -7), (23, -8), (19, -3.5)]), fill=dark)                          # eye
    d.ellipse(_box(*_rot([(40, -2.5)], ang, org)[0], 1.0, s), fill=dark)              # nostril
    return _finish(base, lay, size)


def _bezier(p, n):
    return [_bez(p, i / (n - 1)) for i in range(n)]


def _bez(p, t):
    (x0, y0), (x1, y1), (x2, y2), (x3, y3) = p
    u = 1 - t
    return (u**3 * x0 + 3 * u * u * t * x1 + 3 * u * t * t * x2 + t**3 * x3,
            u**3 * y0 + 3 * u * u * t * y1 + 3 * u * t * t * y2 + t**3 * y3)


def _bez_point_normal(p, t):
    a, b = _bez(p, t), _bez(p, t + 0.01)
    dx, dy = b[0] - a[0], b[1] - a[1]
    n = math.hypot(dx, dy) or 1
    return a, (dy / n, -dx / n)


def _box(cx, cy, r, s):
    k = s / 100.0
    return [(cx - r) * k, (cy - r) * k, (cx + r) * k, (cy + r) * k]


def _finish(base, lay, size):
    im = Image.alpha_composite(base, lay)
    return im.resize((size, size), Image.LANCZOS)


CONCEPTS = {
    "A": ("Ember Eye", "Bone dragon head in profile, one glowing amber eye", concept_a),
    "B": ("Arrow Wyvern", "Wings-up wyvern in electric cyan, arrow-tipped tail", concept_b),
    "C": ("Crowned Head", "Front-facing horned head in ember orange", concept_c),
    "D": ("Dragon Arrow", "Gold arrow whose head is a horned dragon", concept_d),
}


# --- preview sheet ----------------------------------------------------------

def adaptive(fn, size, scale=0.82):
    """What a launcher shows: the concept's background full-bleed and the art
    scaled into the adaptive-icon visible area (the mask crops the outer edge)."""
    bg = fn(size)                       # background gradient sampled from the full icon's edges
    full = _bg(size, bg.getpixel((1, 1))[:3], bg.getpixel((1, size - 2))[:3]).convert("RGBA")
    art = fn(size * 2, bg=False)
    inner = int(size * 2 * scale)
    art = art.resize((inner, inner), Image.LANCZOS)
    layer = Image.new("RGBA", (size * 2, size * 2), (0, 0, 0, 0))
    off = (size * 2 - inner) // 2
    layer.alpha_composite(art, (off, off))
    full.alpha_composite(layer.resize((size, size), Image.LANCZOS))
    return full


def _mask(icon, size):
    """Circle mask (the most common Android launcher shape) for preview."""
    m = Image.new("L", (size * 4, size * 4), 0)
    ImageDraw.Draw(m).ellipse([0, 0, size * 4 - 1, size * 4 - 1], fill=255)
    m = m.resize((size, size), Image.LANCZOS)
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.paste(icon.resize((size, size), Image.LANCZOS).convert("RGBA"), (0, 0), m)
    return out


def _generic_icon(kind, color, size):
    """Simple colourful placeholder app icons (not real apps)."""
    s = size * SS
    im = Image.new("RGBA", (s, s), color + (255,))
    d = ImageDraw.Draw(im)
    w = (255, 255, 255, 255)
    k = s / 100
    if kind == "camera":
        d.rounded_rectangle([20 * k, 32 * k, 80 * k, 72 * k], 8 * k, fill=w)
        d.ellipse([38 * k, 40 * k, 62 * k, 64 * k], fill=color + (255,))
    elif kind == "mail":
        d.rectangle([20 * k, 30 * k, 80 * k, 70 * k], fill=w)
        d.line([20 * k, 30 * k, 50 * k, 55 * k, 80 * k, 30 * k], fill=color + (255,), width=int(5 * k))
    elif kind == "music":
        d.ellipse([26 * k, 58 * k, 44 * k, 74 * k], fill=w)
        d.rectangle([40 * k, 26 * k, 46 * k, 66 * k], fill=w)
        d.polygon([(40 * k, 26 * k), (70 * k, 20 * k), (70 * k, 32 * k), (46 * k, 38 * k)], fill=w)
    elif kind == "pin":
        d.ellipse([32 * k, 20 * k, 68 * k, 56 * k], fill=w)
        d.polygon([(34 * k, 44 * k), (66 * k, 44 * k), (50 * k, 80 * k)], fill=w)
        d.ellipse([43 * k, 31 * k, 57 * k, 45 * k], fill=color + (255,))
    elif kind == "chat":
        d.rounded_rectangle([20 * k, 26 * k, 80 * k, 64 * k], 12 * k, fill=w)
        d.polygon([(30 * k, 60 * k), (30 * k, 80 * k), (48 * k, 62 * k)], fill=w)
    elif kind == "sun":
        d.ellipse([34 * k, 34 * k, 66 * k, 66 * k], fill=w)
        for i in range(8):
            a = i * math.pi / 4
            d.line([50 * k + math.cos(a) * 22 * k, 50 * k + math.sin(a) * 22 * k,
                    50 * k + math.cos(a) * 32 * k, 50 * k + math.sin(a) * 32 * k], fill=w, width=int(5 * k))
    elif kind == "clock":
        d.ellipse([22 * k, 22 * k, 78 * k, 78 * k], fill=w)
        d.line([50 * k, 50 * k, 50 * k, 32 * k], fill=color + (255,), width=int(5 * k))
        d.line([50 * k, 50 * k, 64 * k, 58 * k], fill=color + (255,), width=int(5 * k))
    elif kind == "photo":
        for i, c in enumerate([(255, 90, 90), (255, 200, 60), (80, 200, 120), (70, 140, 255)]):
            a = i * 90
            d.pieslice([24 * k, 24 * k, 76 * k, 76 * k], a, a + 90, fill=c + (255,))
    elif kind == "cart":
        d.polygon([(22 * k, 30 * k), (78 * k, 30 * k), (70 * k, 60 * k), (32 * k, 60 * k)], fill=w)
        d.ellipse([34 * k, 66 * k, 44 * k, 76 * k], fill=w)
        d.ellipse([58 * k, 66 * k, 68 * k, 76 * k], fill=w)
    elif kind == "note":
        d.rectangle([28 * k, 20 * k, 72 * k, 80 * k], fill=w)
        for y in (34, 46, 58):
            d.line([36 * k, y * k, 64 * k, y * k], fill=color + (255,), width=int(4 * k))
    elif kind == "game":
        d.rounded_rectangle([18 * k, 36 * k, 82 * k, 68 * k], 16 * k, fill=w)
        d.rectangle([30 * k, 49 * k, 42 * k, 55 * k], fill=color + (255,))
        d.rectangle([33 * k, 46 * k, 39 * k, 58 * k], fill=color + (255,))
        d.ellipse([60 * k, 46 * k, 68 * k, 54 * k], fill=color + (255,))
    elif kind == "play":
        d.polygon([(38 * k, 28 * k), (38 * k, 72 * k), (74 * k, 50 * k)], fill=w)
    else:
        d.ellipse([30 * k, 30 * k, 70 * k, 70 * k], fill=w)
    return im.resize((size, size), Image.LANCZOS)


NEIGHBOURS = [
    ("camera", (66, 66, 72), "Camera"), ("mail", (220, 68, 55), "Mail"), ("music", (255, 85, 140), "Music"),
    ("pin", (52, 168, 83), "Maps"), ("chat", (37, 211, 102), "Chat"), ("sun", (255, 179, 0), "Weather"),
    ("clock", (63, 81, 181), "Clock"), ("photo", (245, 245, 245), "Photos"), ("cart", (255, 112, 67), "Shop"),
    ("note", (255, 202, 40), "Notes"), ("game", (126, 87, 194), "Games"), ("play", (229, 57, 53), "Video"),
    ("dot", (0, 172, 193), "Fitness"), ("chat", (33, 150, 243), "Messages"), ("music", (29, 185, 84), "Radio"),
    ("photo", (40, 40, 40), "Gallery"), ("sun", (3, 169, 244), "Sky"), ("clock", (0, 150, 136), "Alarm"),
    ("cart", (156, 39, 176), "Market"),
]


def _wallpaper(w, h, dark):
    im = Image.new("RGB", (w, h))
    d = ImageDraw.Draw(im)
    a, b = ((236, 226, 214), (196, 214, 232)) if not dark else ((18, 22, 44), (52, 30, 70))
    for y in range(h):
        t = y / (h - 1)
        d.line([(0, y), (w, y)], fill=tuple(int(x + (z - x) * t) for x, z in zip(a, b)))
    # soft blobs so the wallpaper is not flat
    blob = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    bd = ImageDraw.Draw(blob)
    cols = [(255, 190, 150, 90), (150, 200, 255, 90)] if not dark else [(90, 60, 160, 90), (30, 90, 140, 90)]
    bd.ellipse([-w * 0.3, h * 0.15, w * 0.7, h * 0.55], fill=cols[0])
    bd.ellipse([w * 0.4, h * 0.5, w * 1.3, h * 0.95], fill=cols[1])
    blob = blob.filter(ImageFilter.GaussianBlur(40))
    return Image.alpha_composite(im.convert("RGBA"), blob)


def home_screen(icon_fn, dark, slot=7, w=360, h=720, icon=48):
    """A 360x720 dp phone home screen at 1 px per dp: 4 columns, icons 48 dp."""
    im = _wallpaper(w, h, dark)
    d = ImageDraw.Draw(im)
    label_col = (255, 255, 255) if dark else (30, 30, 34)
    font = ImageFont.truetype(FONT_R, 11)
    # status bar
    sb = (255, 255, 255) if dark else (30, 30, 34)
    d.text((16, 6), "12:30", font=ImageFont.truetype(FONT, 12), fill=sb)
    d.rectangle([w - 34, 9, w - 16, 17], outline=sb)
    # clock widget area
    d.text((w // 2, 92), "12:30", font=ImageFont.truetype(FONT_R, 56), fill=label_col, anchor="mm")
    cols, x0, y0, cw, rh = 4, 0, 200, w / 4, 92
    items = list(NEIGHBOURS)
    ours = ("ours", None, "Legend Arrow")
    items.insert(slot, ours)
    for i, (kind, color, label) in enumerate(items[:16]):
        r, c = divmod(i, cols)
        cx = x0 + cw * c + cw / 2
        top = y0 + r * rh
        ic = adaptive(icon_fn, icon) if kind == "ours" else _generic_icon(kind, color, icon)
        ic = _mask(ic, icon)
        im.alpha_composite(ic, (int(cx - icon / 2), int(top)))
        d.text((cx, top + icon + 12), label, font=font, fill=label_col, anchor="mm")
    # dock
    dock = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(dock).rounded_rectangle([12, h - 96, w - 12, h - 24], 28,
                                           fill=(255, 255, 255, 90) if not dark else (255, 255, 255, 34))
    im.alpha_composite(dock)
    d = ImageDraw.Draw(im)
    for i, (kind, color, _) in enumerate(NEIGHBOURS[:4]):
        cx = 12 + (w - 24) / 4 * i + (w - 24) / 8
        im.alpha_composite(_mask(_generic_icon(kind, color, icon), icon), (int(cx - icon / 2), h - 84))
    # gesture bar
    d.rounded_rectangle([w / 2 - 54, h - 10, w / 2 + 54, h - 6], 2, fill=label_col)
    return im


def sheet(out):
    pad, hero = 28, 300
    hw, hh = 360, 720
    zoom = 4
    col_w = [hero, hw, hw, 48 * zoom + 96]
    W = pad * (len(col_w) + 1) + sum(col_w)
    row_h = hh + 70
    H = 150 + len(CONCEPTS) * (row_h + pad) + 40
    im = Image.new("RGBA", (W, H), (246, 245, 241, 255))
    d = ImageDraw.Draw(im)
    tf, hf, bf = ImageFont.truetype(FONT, 34), ImageFont.truetype(FONT, 24), ImageFont.truetype(FONT_R, 16)
    d.text((pad, 30), "Legend Arrow — app icon concepts v2 (choose A, B, C or D)", font=tf, fill=(24, 27, 31))
    d.text((pad, 80), "Each row: Play Store icon (512 px, shown at 300) and the round launcher version · real launcher size "
                      "(48 dp) on a light and a dark home screen · 48 px close-up at 1:1 and ×4. "
                      "Neighbour icons are generic placeholders.",
           font=bf, fill=(80, 84, 90))
    y = 150
    for key, (name, desc, fn) in CONCEPTS.items():
        x = pad
        d.text((x, y), f"{key} — {name}", font=hf, fill=(24, 27, 31))
        d.text((x, y + 32), desc, font=bf, fill=(80, 84, 90))
        top = y + 64
        big = fn(512).resize((hero, hero), Image.LANCZOS).convert("RGBA")
        im.alpha_composite(_rounded(big, 60), (x, top))
        im.alpha_composite(_mask(adaptive(fn, 512), 140), (x + 80, top + hero + 30))
        x += hero + pad
        for dark in (False, True):
            hs = home_screen(fn, dark)
            frame = Image.new("RGBA", (hw + 12, hh + 12), (20, 20, 22, 255))
            frame.alpha_composite(hs, (6, 6))
            im.alpha_composite(_rounded(frame, 34), (x - 6, top - 6))
            x += hw + pad
        # 48 px close-up: 1:1 and x4 (nearest neighbour, so every real pixel shows)
        small = _mask(adaptive(fn, 48), 48)
        sf = ImageFont.truetype(FONT_R, 13)
        for i, bgc in enumerate([(250, 249, 246), (18, 22, 30)]):
            yy = top + i * (48 * zoom + 70)
            tile = Image.new("RGBA", (72, 72), bgc + (255,))
            tile.alpha_composite(small, (12, 12))
            im.alpha_composite(tile, (x, yy))
            big_tile = Image.new("RGBA", (48 * zoom, 48 * zoom), bgc + (255,))
            big_tile.alpha_composite(small.resize((48 * zoom, 48 * zoom), Image.NEAREST))
            im.alpha_composite(big_tile, (x + 84, yy))
            d.text((x, yy + 48 * zoom + 10), ("light" if i == 0 else "dark") + ": 48 px at 1:1 (left), x4 (right)",
                   font=sf, fill=(80, 84, 90))
        y += row_h + pad
    im.convert("RGB").save(out, optimize=True)
    return out


def _rounded(img, r):
    m = Image.new("L", img.size, 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, img.size[0] - 1, img.size[1] - 1], r, fill=255)
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    out.paste(img, (0, 0), m)
    return out


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "docs/store/icon_concepts_v2.png"
    os.makedirs(os.path.dirname(out), exist_ok=True)
    print(sheet(out))
