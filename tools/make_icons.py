#!/usr/bin/env python3
"""Regenerates the launcher icons in assets/icon/ (needs Pillow).

Ivory field with a slate-blue bent arrow, matching the in-game arrows.
Run from the repo root: python3 tools/make_icons.py
"""
from PIL import Image, ImageDraw

ACCENT = (71, 103, 124)
BACKGROUND = (250, 249, 246)


def draw_arrow(d, s, color):
    w = int(s * 0.075)
    pts = [(s * 0.30, s * 0.78), (s * 0.30, s * 0.52), (s * 0.62, s * 0.52), (s * 0.62, s * 0.36)]
    d.line(pts, fill=color, width=w, joint="curve")
    for x, y in pts[:-1]:
        d.ellipse([x - w / 2, y - w / 2, x + w / 2, y + w / 2], fill=color)
    hx, hy = s * 0.62, s * 0.20
    d.polygon([(hx, hy), (hx - s * 0.11, hy + s * 0.17), (hx + s * 0.11, hy + s * 0.17)], fill=color)


def make(size, background=True, scale=1.0):
    big = size * 4  # supersample, then downscale for smooth edges
    im = Image.new("RGBA", (big, big), BACKGROUND + (255,) if background else (0, 0, 0, 0))
    art = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    draw_arrow(ImageDraw.Draw(art), big, ACCENT)
    if scale != 1.0:  # adaptive icons keep the art inside the safe zone
        inner = int(big * scale)
        art = art.resize((inner, inner), Image.LANCZOS)
        off = (big - inner) // 2
        im.alpha_composite(art, (off, off))
    else:
        im.alpha_composite(art)
    return im.resize((size, size), Image.LANCZOS)


if __name__ == "__main__":
    make(192).save("assets/icon/icon_192.png")
    make(512).save("assets/icon/icon_512.png")
    make(432, background=False, scale=0.62).save("assets/icon/adaptive_foreground_432.png")
    Image.new("RGBA", (432, 432), BACKGROUND + (255,)).save("assets/icon/adaptive_background_432.png")
    make(432, background=False, scale=0.62).convert("LA").save("assets/icon/monochrome_432.png")
