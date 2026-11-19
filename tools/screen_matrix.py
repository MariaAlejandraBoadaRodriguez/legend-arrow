#!/usr/bin/env python3
"""Builds docs/qa/screen_matrix.png from docs/qa/screens/<profile>/<screen>.png
(rows = screens, columns = profiles P1-P7). Needs Pillow.

The matrix is built from the full-colour captures; afterwards every capture
and the matrix are stored as 256-colour PNGs (about 28% of the size, enough to
review layout, clipping and overlap) so they can live in the repository."""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = "docs/qa/screens"
PROFILES = ["P1", "P2", "P3", "P4", "P5", "P6", "P7"]
CELL_H = 300
FONT = "assets/fonts/Inter-SemiBold.ttf"


def small(im):
    return im.convert("RGB").quantize(256, method=Image.Quantize.FASTOCTREE, dither=Image.Dither.NONE)


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else "docs/qa/screen_matrix.png"
    screens = sorted({f[:-4] for p in PROFILES if os.path.isdir(os.path.join(ROOT, p))
                      for f in os.listdir(os.path.join(ROOT, p)) if f.endswith(".png")})
    widths = {}
    for p in PROFILES:
        for s in screens:
            f = os.path.join(ROOT, p, s + ".png")
            if os.path.exists(f):
                im = Image.open(f)
                widths[p] = max(widths.get(p, 0), int(im.width * CELL_H / im.height))
    lab_w, head_h, gap = 230, 40, 8
    W = lab_w + sum(widths.get(p, 0) + gap for p in PROFILES)
    H = head_h + len(screens) * (CELL_H + gap)
    sheet = Image.new("RGB", (W, H), (246, 245, 241))
    d = ImageDraw.Draw(sheet)
    f = ImageFont.truetype(FONT, 18)
    x = lab_w
    for p in PROFILES:
        d.text((x + 4, 10), p, font=f, fill=(24, 27, 31))
        x += widths.get(p, 0) + gap
    for r, s in enumerate(screens):
        y = head_h + r * (CELL_H + gap)
        d.text((8, y + CELL_H // 2 - 10), s, font=f, fill=(24, 27, 31))
        x = lab_w
        for p in PROFILES:
            fp = os.path.join(ROOT, p, s + ".png")
            if os.path.exists(fp):
                im = Image.open(fp).convert("RGB")
                im = im.resize((int(im.width * CELL_H / im.height), CELL_H), Image.LANCZOS)
                sheet.paste(im, (x, y))
            else:
                d.text((x + 8, y + CELL_H // 2), "missing", font=f, fill=(180, 60, 50))
            x += widths.get(p, 0) + gap
    small(sheet).save(out, optimize=True)
    for p in PROFILES:
        for s in screens:
            fp = os.path.join(ROOT, p, s + ".png")
            if os.path.exists(fp) and Image.open(fp).mode != "P":
                small(Image.open(fp)).save(fp, optimize=True)
    print(out, sheet.size, f"{len(screens)} screens x {len(PROFILES)} profiles")


if __name__ == "__main__":
    main()
