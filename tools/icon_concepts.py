#!/usr/bin/env python3
"""Draws the three app icon concepts and a preview sheet (needs Pillow).

Each concept is a full-bleed 512x512 opaque square (Play applies the mask).
The sheet shows each at 512 px and 48 px on light and dark backgrounds,
with Play's rounded mask applied for preview only.
Run from the repo root: python3 tools/icon_concepts.py [out.png]
"""
import math
import sys

from PIL import Image, ImageDraw, ImageFont

IVORY = (250, 249, 246)
GRAPHITE = (37, 40, 43)
SLATE = (71, 103, 124)
GRID = (217, 216, 210)
SS = 4            # supersampling factor
S = 512 * SS      # working canvas


def _canvas(bg=IVORY):
    """bg=None gives a transparent canvas (adaptive icon foreground)."""
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0)) if bg is None else Image.new("RGB", (S, S), bg)
    return im, ImageDraw.Draw(im)


def _poly_stroke(d, pts, w, color):
    """Thick orthogonal polyline with square joints."""
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        d.rectangle([min(x0, x1) - w / 2, min(y0, y1) - w / 2, max(x0, x1) + w / 2, max(y0, y1) + w / 2], fill=color)


def _head(d, tip, direction, size, color):
    x, y = tip
    dx, dy = direction
    px, py = -dy, dx
    d.polygon([(x, y), (x - dx * size + px * size * 0.62, y - dy * size + py * size * 0.62),
               (x - dx * size - px * size * 0.62, y - dy * size - py * size * 0.62)], fill=color)


def _round_stroke(d, pts, w, color):
    """Thick polyline with round joints and caps, like the in-game arrows."""
    d.line(pts, fill=color, width=int(w), joint="curve")
    for x, y in pts[:-1]:
        d.ellipse([x - w / 2, y - w / 2, x + w / 2, y + w / 2], fill=color)


def concept_a():
    """One bold orthogonal arrow path drawn as a wyvern head in profile:
    the neck rises from the bottom edge, turns along the crown, steps down at
    the brow and runs out as the snout; the arrowhead is the jaw and snout tip."""
    im, d = _canvas()
    u = S / 16
    w = u * 2.5
    pts = [(5.0, 17.0), (5.0, 4.4), (7.4, 4.4), (7.4, 7.4), (11.0, 7.4)]
    _round_stroke(d, [(x * u, y * u) for x, y in pts], w, GRAPHITE)
    _head(d, (14.2 * u, 7.4 * u), (1, 0), 3.6 * u, GRAPHITE)
    # Swept-back horn: a short stub off the crown, same weight family.
    d.polygon([(3.9 * u, 3.6 * u), (1.6 * u, 1.6 * u), (5.6 * u, 3.3 * u)], fill=GRAPHITE)
    # Slate-blue eye with an ivory slit, under the brow step.
    e = 0.85 * u
    cx, cy = 6.6 * u, 6.2 * u
    d.ellipse([cx - e, cy - e * 0.7, cx + e, cy + e * 0.7], fill=SLATE)
    d.polygon([(cx, cy - e * 0.6), (cx + e * 0.18, cy), (cx, cy + e * 0.6), (cx - e * 0.18, cy)], fill=IVORY)
    return im.resize((512, 512), Image.LANCZOS)


# Wyvern silhouette on a 14x14 board: raised wing, head right, tail low left.
B_MASK = [
    "..............",
    "......#.......",
    ".....##.......",
    "....###.......",
    "...####....##.",
    "..#####...###.",
    "..######.####.",
    "...#########..",
    "....#######...",
    "....######....",
    "....#...#.....",
    "..##....##....",
    ".#............",
    "#.............",
]


def concept_b(size=512, bg=IVORY):
    """A wyvern drawn as a board of short arrows, as in the game; one
    slate-blue arrow has just slid out past the snout. Chosen app icon
    (tools/make_icons.py)."""
    im, d = _canvas(bg)
    n = len(B_MASK)
    cell = S * 0.80 / n
    off = S * 0.08
    w = cell * 0.24
    for r, row in enumerate(B_MASK):
        for c, ch in enumerate(row):
            if ch != "#":
                continue
            cx, cy = off + (c + 0.5) * cell, off + (r + 0.5) * cell
            # Body flows right, the wing points up, legs and tail point down/left.
            if r <= 5 and c <= 6:
                dx, dy = 0, -1
            elif r >= 10:
                dx, dy = (-1, 0) if c <= 3 else (0, 1)
            else:
                dx, dy = 1, 0
            a = (cx - dx * cell * 0.34, cy - dy * cell * 0.34)
            b = (cx + dx * cell * 0.05, cy + dy * cell * 0.05)
            _poly_stroke(d, [a, b], w, GRAPHITE)
            _head(d, (cx + dx * cell * 0.42, cy + dy * cell * 0.42), (dx, dy), cell * 0.40, GRAPHITE)
    y = off + 2.5 * cell
    _poly_stroke(d, [(off + 11.4 * cell, y), (off + 13.0 * cell, y)], w * 1.3, SLATE)
    _head(d, (off + 14.0 * cell, y), (1, 0), cell * 0.95, SLATE)
    return im.resize((size, size), Image.LANCZOS)


def _quad(p0, p1, p2, steps=80):
    return [((1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t * t * p2[0],
             (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t * t * p2[1])
            for t in (i / steps for i in range(steps + 1))]


def concept_c():
    """Minimal emblem: a dragon eye whose upper lid is one graphite arrow that
    sweeps on past the corner like a wing tip; slate-blue iris, ivory slit."""
    im, d = _canvas()
    L = (S * 0.12, S * 0.58)
    R = (S * 0.74, S * 0.50)
    w = S * 0.06
    upper = _quad(L, (S * 0.40, S * 0.18), R)
    sweep = _quad(R, (S * 0.80, S * 0.47), (S * 0.84, S * 0.40), 20)
    _round_stroke(d, upper + sweep[1:], w, GRAPHITE)
    ang = math.atan2(sweep[-1][1] - sweep[-4][1], sweep[-1][0] - sweep[-4][0])
    tip = (sweep[-1][0] + math.cos(ang) * S * 0.12, sweep[-1][1] + math.sin(ang) * S * 0.12)
    _head(d, tip, (math.cos(ang), math.sin(ang)), S * 0.17, GRAPHITE)
    lower = _quad(L, (S * 0.44, S * 0.88), R)
    _round_stroke(d, lower, w * 0.5, GRAPHITE)
    # Iris and slit pupil, tucked under the lid.
    cx, cy, ir = S * 0.44, S * 0.555, S * 0.135
    d.ellipse([cx - ir, cy - ir, cx + ir, cy + ir], fill=SLATE)
    d.polygon([(cx, cy - ir * 0.86), (cx + ir * 0.2, cy), (cx, cy + ir * 0.86), (cx - ir * 0.2, cy)], fill=IVORY)
    # Re-draw the lid over the iris so the eye reads as hooded.
    _round_stroke(d, upper, w, GRAPHITE)
    return im.resize((512, 512), Image.LANCZOS)


CONCEPTS = {"A": concept_a, "B": concept_b, "C": concept_c}


def masked(icon, size, bg):
    """Preview only: Play's rounded-square mask (~20% radius) on a background."""
    big = icon.resize((size * 4, size * 4), Image.LANCZOS)
    mask = Image.new("L", big.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, big.width - 1, big.height - 1], radius=int(big.width * 0.2), fill=255)
    tile = Image.new("RGB", big.size, bg)
    tile.paste(big, (0, 0), mask)
    m = mask.resize((size, size), Image.LANCZOS)
    return tile.resize((size, size), Image.LANCZOS), m


def sheet(out):
    font = ImageFont.truetype("assets/fonts/Inter-SemiBold.ttf", 34)
    small = ImageFont.truetype("assets/fonts/Inter-Regular.ttf", 22)
    light, dark = (236, 235, 230), GRAPHITE
    pad, big = 40, 512
    col_small = 360
    W = pad + big + pad + big + pad + col_small + pad
    H = 110 + 3 * (big + 90)
    img = Image.new("RGB", (W, H), IVORY)
    d = ImageDraw.Draw(img)
    d.text((pad, 34), "Legend Arrow - icon concepts (512 px and 48 px, light and dark)", font=font, fill=GRAPHITE)
    names = {"A": "A  Orthogonal arrow path = wyvern head",
             "B": "B  Wyvern made of short arrows, one leaving",
             "C": "C  Arrow curling into a dragon eye"}
    y = 110
    for key, fn in CONCEPTS.items():
        icon = fn()
        d.text((pad, y), names[key], font=font, fill=GRAPHITE)
        y0 = y + 56
        x = pad
        for bg in (light, dark):
            d.rectangle([x, y0, x + big, y0 + big], fill=bg)
            t, m = masked(icon, big - 40, bg)
            img.paste(t, (x + 20, y0 + 20), m)
            x += big + pad
        # 48 px at actual size, light and dark, plus a 4x nearest zoom of 48 px.
        d.rectangle([x, y0, x + col_small, y0 + big], fill=light)
        d.rectangle([x, y0 + big // 2, x + col_small, y0 + big], fill=dark)
        for i, bg in enumerate((light, dark)):
            t, m = masked(icon, 48, bg)
            yy = y0 + i * big // 2
            img.paste(t, (x + 24, yy + 24), m)
            zoom = t.resize((192, 192), Image.NEAREST)
            zm = m.resize((192, 192), Image.NEAREST)
            img.paste(zoom, (x + 140, yy + 32), zm)
            d.text((x + 24, yy + 84), "48 px", font=small, fill=GRAPHITE if i == 0 else IVORY)
            d.text((x + 140, yy + 228), "48 px, zoomed 4x", font=small, fill=GRAPHITE if i == 0 else IVORY)
        y += big + 90
    img.save(out, optimize=True)
    return img


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "docs/store/icon_concepts.png"
    sheet(out)
    for key, fn in CONCEPTS.items():
        im = fn()
        assert im.size == (512, 512) and im.mode == "RGB"
    print(out)
