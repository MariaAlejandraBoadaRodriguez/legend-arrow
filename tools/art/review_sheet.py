#!/usr/bin/env python3
"""docs/store/art_review_sheet.png (v0.2 §4 / §9.4): every imported cut-out,
on a dark and a light half to expose halos or leftover backdrop, next to its
puzzle silhouette (the level's arrows drawn on its grid), grouped by world.
Needs Pillow. Run after scripts/import_art.sh and the level build:

  python3 tools/art/review_sheet.py [out.png]
"""
import json
import os
import sys

from PIL import Image, ImageDraw, ImageFont

FONT = "assets/fonts/Inter-SemiBold.ttf"
FONT_R = "assets/fonts/Inter-Regular.ttf"
TILE_W, TILE_H = 150, 170
GAP = 10


def cutout_tile(did):
    p = f"assets/creatures/art/{did}.webp"
    tile = Image.new("RGB", (TILE_W, TILE_H), (32, 36, 44))
    d = ImageDraw.Draw(tile)
    d.rectangle([TILE_W // 2, 0, TILE_W, TILE_H], fill=(236, 234, 228))  # light half
    if os.path.exists(p):
        im = Image.open(p).convert("RGBA")
        s = min((TILE_W - 8) / im.width, (TILE_H - 8) / im.height)
        im = im.resize((max(1, int(im.width * s)), max(1, int(im.height * s))), Image.LANCZOS)
        tile.paste(im, ((TILE_W - im.width) // 2, (TILE_H - im.height) // 2), im)
    else:
        d.text((8, TILE_H // 2), "ART PENDING", fill=(220, 80, 60), font=ImageFont.truetype(FONT, 14))
    return tile


def puzzle_tile(did):
    tile = Image.new("RGB", (TILE_W, TILE_H), (250, 249, 246))
    p = f"data/levels/{did}.json"
    if not os.path.exists(p):
        return tile
    lvl = json.load(open(p))
    w, h = lvl["width"], lvl["height"]
    c = min((TILE_W - 10) / w, (TILE_H - 10) / h)
    ox, oy = (TILE_W - w * c) / 2, (TILE_H - h * c) / 2
    d = ImageDraw.Draw(tile)
    for a in lvl["arrows"]:
        pts = [(ox + (x + 0.5) * c, oy + (y + 0.5) * c) for x, y in a["cells"]]
        d.line(pts, fill=(37, 40, 43), width=max(3, int(c * 0.5)))
    return tile


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else "docs/store/art_review_sheet.png"
    roster = json.load(open("data/roster.json", encoding="utf-8"))
    cols = 5                                  # dragons per row (each = 2 tiles)
    pair_w = TILE_W * 2 + 4
    row_h = TILE_H + 26
    head = 34
    W = GAP + cols * (pair_w + GAP)
    H = 70 + len(roster["worlds"]) * (head + 2 * (row_h + GAP))
    sheet = Image.new("RGB", (W, H), (246, 245, 241))
    d = ImageDraw.Draw(sheet)
    tf, hf, nf = ImageFont.truetype(FONT, 26), ImageFont.truetype(FONT, 18), ImageFont.truetype(FONT_R, 13)
    d.text((GAP, 18), "Legend Arrow — art review: cut-out (dark | light) and its puzzle silhouette", font=tf, fill=(24, 27, 31))
    y = 70
    by_id = {x["id"]: x for x in roster["dragons"]}
    for w in roster["worlds"]:
        d.text((GAP, y + 6), f"World {w['number']} — {w['name']}", font=hf, fill=(24, 27, 31))
        y += head
        for i, did in enumerate(w["dragons"]):
            r, c = divmod(i, cols)
            x0 = GAP + c * (pair_w + GAP)
            y0 = y + r * (row_h + GAP)
            sheet.paste(cutout_tile(did), (x0, y0))
            sheet.paste(puzzle_tile(did), (x0 + TILE_W + 4, y0))
            d.text((x0, y0 + TILE_H + 4), f"{by_id[did]['number']:03d} {by_id[did]['name']}", font=nf, fill=(60, 64, 70))
        y += 2 * (row_h + GAP)
    sheet.save(out, optimize=True)
    print(out, sheet.size)


if __name__ == "__main__":
    main()
