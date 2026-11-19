#!/usr/bin/env python3
"""Builds the v0.2 campaign: 10 worlds x 10 dragons = 100 levels (D-47).

  GODOT=/path/to/godot python3 tools/build_campaign.py [dragon_id ...]

1. Silhouette mask of each dragon from its real image
   (assets/creatures/raw/<id>.png): the studio backdrop is modelled as a
   smooth quadratic surface fitted to the border, pixels far from it are the
   dragon, neutral darker pixels near it are the cast shadow; holes filled,
   specks and detached shadow blobs dropped. Saved to build/masks/<id>.png.
   Milestone D replaces this with the rembg cut-out mask; levels are then
   re-certified.
2. A difficulty plan per level (arrow count, dependency target, grid) from the
   world/index curve below.
3. tools/generate_campaign.gd generates each level from the mask (seed
   search, deterministic), validates and certifies it with the exact solver,
   and writes data/levels/<id>.json; then data/campaign.json and
   data/creatures/<id>.json are written here.
Deterministic: same images + same plan -> same files. Needs Pillow + numpy.
"""
import json
import math
import os
import subprocess
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

GODOT = os.environ.get("GODOT", "godot")
ROSTER = "data/roster.json"
RAW = "assets/creatures/raw"
MASKS = "build/masks"
PLAN = "build/campaign_plan.json"
# DEEPEN=1: wider seed search that strongly favours deeper dependency chains,
# used to rebalance the shallowest boards of the later worlds (D-47).
DEEPEN = os.environ.get("DEEPEN", "") == "1"
SILHOUETTES = "assets/creatures/silhouettes"
MASK_W, MASK_H = 256, 384

MAX_W, MAX_H = 18, 24          # board size cap (large boards use pan/zoom on phones)
CELLS_PER_ARROW = 3.6          # silhouette cells budgeted per arrow
MAX_ASPECT = 0.95              # widest board (cols/rows) before stretching vertically (portrait screens)
MAX_STRETCH = 2.0              # most a side-view silhouette is stretched vertically


# --- difficulty curve ------------------------------------------------------

def arrows_for(world, k):
    """World 1: 6-12 arrows ... world 10: 41-60, rising inside each world."""
    lo = 6 + (41 - 6) * (world - 1) / 9.0
    hi = 12 + (60 - 12) * (world - 1) / 9.0
    return int(round(lo + (hi - lo) * k / 9.0))


def depth_target(world, k):
    return 2 + int(round((world - 1) * 0.75 + k * 0.12))


def difficulty_for(n):
    return "easy" if n <= 12 else "medium" if n <= 24 else "hard" if n <= 40 else "expert"


def max_len_for(world):
    return 4 if world <= 6 else 5


# --- masks -----------------------------------------------------------------

def dragon_mask(path):
    im = Image.open(path).convert("RGB").resize((MASK_W, MASK_H), Image.LANCZOS)
    a = np.asarray(im).astype(np.float64)
    h, w, _ = a.shape
    yy, xx = np.mgrid[0:h, 0:w]
    border = np.zeros((h, w), bool)
    border[:6, :] = border[-6:, :] = border[:, :6] = border[:, -6:] = True

    def feats(x, y):
        return np.stack([np.ones_like(x), x, y, x * x, y * y, x * y], 1)

    f_b = feats(xx[border] / w, yy[border] / h)
    f_all = feats(xx.ravel() / w, yy.ravel() / h)
    bg = np.zeros_like(a)
    for c in range(3):
        coef, *_ = np.linalg.lstsq(f_b, a[..., c][border], rcond=None)
        bg[..., c] = (f_all @ coef).reshape(h, w)
    dist = np.sqrt(((a - bg) ** 2).sum(2))
    sat = (a.max(2) - a.min(2)) / np.maximum(a.max(2), 1)
    bsat = (bg.max(2) - bg.min(2)) / np.maximum(bg.max(2), 1)
    shadow = (a.mean(2) < bg.mean(2)) & (np.abs(sat - bsat) < 0.06) & (dist < 60)
    fg = (dist > 22) & ~shadow
    m = Image.fromarray((fg * 255).astype(np.uint8)).filter(ImageFilter.MedianFilter(5))
    m = _fill_holes(m)
    return _keep_main_components(m)


def _fill_holes(m):
    f = m.copy()
    ImageDraw.floodfill(f, (0, 0), 128)
    return Image.fromarray(((np.asarray(f) != 128) * 255).astype(np.uint8))


def _keep_main_components(m):
    """Drops components smaller than 4% of the largest (specks, shadow blobs)."""
    arr = (np.asarray(m) > 127).astype(np.uint8) * 255
    work = Image.fromarray(arr).copy()  # a numpy-backed image is read-only: floodfill would no-op
    comps = []
    label = 1
    for y, x in zip(*np.nonzero(arr == 255)):
        if work.getpixel((int(x), int(y))) != 255:
            continue
        ImageDraw.floodfill(work, (int(x), int(y)), label)
        size = int((np.asarray(work) == label).sum())
        comps.append((size, label))
        label += 1
        if label >= 250:
            break
    if not comps:
        return m
    biggest = max(s for s, _ in comps)
    keep = {lab for s, lab in comps if s >= 0.04 * biggest}
    w = np.asarray(work)
    return Image.fromarray((np.isin(w, list(keep)) * 255).astype(np.uint8))


def write_silhouette(did):
    """Small white-on-transparent silhouette (bbox + margin, 256 px tall) for
    locked tiles and the interim SilhouetteRig."""
    m = Image.open(os.path.join(MASKS, did + ".png"))
    a = np.asarray(m) > 127
    ys, xs = np.nonzero(a)
    pad = 4
    box = (max(0, xs.min() - pad), max(0, ys.min() - pad), min(MASK_W, xs.max() + 1 + pad), min(MASK_H, ys.max() + 1 + pad))
    crop = m.crop(box)
    h = 256
    w = max(1, int(round(crop.width * h / crop.height)))
    if w > 384:
        w, h = 384, max(1, int(round(crop.height * 384 / crop.width)))
    alpha = crop.resize((w, h), Image.LANCZOS)
    out = Image.new("LA", (w, h), (255, 0))
    out.putalpha(alpha)
    out.save(os.path.join(SILHOUETTES, did + ".png"), optimize=True)


def grid_rows(mask_img, cols, rows, threshold):
    """Mask bbox -> cols x rows cells; a cell is on when >= threshold covered."""
    a = np.asarray(mask_img) > 127
    ys, xs = np.nonzero(a)
    x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
    crop = Image.fromarray((a[y0:y1, x0:x1] * 255).astype(np.uint8)).resize((cols * 8, rows * 8), Image.BOX)
    c = np.asarray(crop).astype(np.float64) / 255
    cov = c.reshape(rows, 8, cols, 8).mean(axis=(1, 3))
    return ["".join("#" if cov[r, q] >= threshold else "." for q in range(cols)) for r in range(rows)]


def dilate(rows):
    h, w = len(rows), len(rows[0])
    on = {(x, y) for y in range(h) for x in range(w) if rows[y][x] == "#"}
    out = set(on)
    for x, y in on:
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            if 0 <= x + dx < w and 0 <= y + dy < h:
                out.add((x + dx, y + dy))
    return ["".join("#" if (x, y) in out else "." for x in range(w)) for y in range(h)]


def plan_grid(mask_img, arrows, grow=0):
    """Picks a grid whose silhouette offers about CELLS_PER_ARROW cells per
    arrow, within MAX_W x MAX_H. Wide side-view dragons are stretched
    vertically (at most MAX_STRETCH) so they use the portrait screen;
    the silhouette is thickened (up to 3 cells) when still short of cells.
    Returns (cols, rows, mask rows, dilation steps, vertical stretch)."""
    a = np.asarray(mask_img) > 127
    ys, xs = np.nonzero(a)
    bw, bh = xs.max() - xs.min() + 1, ys.max() - ys.min() + 1
    fill = a.sum() / float(bw * bh)
    need = arrows * CELLS_PER_ARROW * (1 + 0.15 * grow)
    aspect = bw / float(bh)
    stretch = min(MAX_STRETCH, max(1.0, aspect / MAX_ASPECT))
    eff = aspect / stretch
    area = need / max(fill, 0.15)
    cols = max(5, int(round(math.sqrt(area * eff))))
    rows = max(5, int(round(cols / eff)))
    scale = min(1.0, MAX_W / cols, MAX_H / rows)
    cols, rows = max(5, int(cols * scale)), max(5, int(rows * scale))
    m = grid_rows(mask_img, cols, rows, 0.30)
    dil = 0
    while sum(r.count("#") for r in m) < need and dil < 3:
        m = dilate(m)
        dil += 1
    return cols, rows, m, dil, round(stretch, 2)


# --- build -----------------------------------------------------------------

def main():
    only = set(sys.argv[1:])
    for attempt in range(4):   # failed levels retry on a larger silhouette
        status, failed = build_once(only)
        if status == 0:
            write_campaign(json.load(open(ROSTER, encoding="utf-8")))
            return 0
        only = set(failed)
        print(f"build_campaign: retrying {sorted(only)} (attempt {attempt + 2})")
    return 1


def build_once(only):
    roster = json.load(open(ROSTER, encoding="utf-8"))
    os.makedirs(MASKS, exist_ok=True)
    plan = []
    grow = {}
    if os.path.exists("build/campaign_grow.json"):
        grow = json.load(open("build/campaign_grow.json"))
    for w in roster["worlds"]:
        for k, did in enumerate(w["dragons"]):
            if only and did not in only:
                continue
            mp = os.path.join(MASKS, did + ".png")
            if not os.path.exists(mp):
                dragon_mask(os.path.join(RAW, did + ".png")).save(mp)
            mask = Image.open(mp)
            n = arrows_for(w["number"], k)
            cols, rows, cells, dil, stretch = plan_grid(mask, n, grow.get(did, 0))
            plan.append({"id": did, "world": w["number"], "index": k, "arrows": n,
                         "difficulty": difficulty_for(n), "min_depth": depth_target(w["number"], k),
                         "max_len": max_len_for(w["number"]), "width": cols, "height": rows,
                         "free_weight": round(2.0 + 0.8 * (w["number"] - 1), 2),
                         "depth_weight": round(10.0 + 1.5 * (w["number"] - 1), 2) * (6 if DEEPEN else 1),
                         "seeds": 240 if DEEPEN else 0,
                         "dilated": dil, "stretch": stretch, "mask": cells})
    with open(PLAN, "w") as fh:
        json.dump(plan, fh)
    print(f"build_campaign: planned {len(plan)} levels -> {PLAN}")
    r = subprocess.run([GODOT, "--headless", "--path", ".", "-s", "res://tools/generate_campaign.gd", "--", PLAN],
                       capture_output=True, text=True)
    sys.stdout.write("\n".join(l for l in r.stdout.splitlines() if l.startswith(("GEN", "FAIL", "generate"))) + "\n")
    if r.returncode != 0:
        sys.stderr.write(r.stderr[-3000:])
        failed = [l.split()[1] for l in r.stdout.splitlines() if l.startswith("FAIL")]
        for f in failed:
            grow[f] = grow.get(f, 0) + 1
        with open("build/campaign_grow.json", "w") as fh:
            json.dump(grow, fh)
        return 1, failed
    return 0, []


def write_campaign(roster):
    camp = {"schema_version": 2, "worlds": [], "dragons": []}
    for w in roster["worlds"]:
        camp["worlds"].append({"id": w["id"], "number": w["number"], "name_key": "WORLD_%s" % w["id"].upper(),
                               "tone": w["tone"]})
        for did in w["dragons"]:
            camp["dragons"].append({"id": did, "world": w["id"], "name_key": "CREATURE_%s" % did.upper(),
                                    "levels": [did]})
    with open("data/campaign.json", "w") as fh:
        json.dump(camp, fh, indent=1)
        fh.write("\n")
    os.makedirs("data/creatures", exist_ok=True)
    os.makedirs(SILHOUETTES, exist_ok=True)
    for d in roster["dragons"]:
        write_silhouette(d["id"])
        meta = {"schema_version": 2, "id": d["id"], "world": d["world"], "number": d["number"],
                "name_key": "CREATURE_%s" % d["id"].upper(), "lore_key": "CREATURE_%s_LORE" % d["id"].upper(),
                "source_image": "assets/creatures/raw/%s" % d["file"],
                "credits": "ChatGPT image generation, owner-generated, commercial use."}
        rig = "scenes/creatures/%s.tscn" % d["id"]
        if os.path.exists(rig):   # v0.1 layered rig kept until the photoreal art (D-47)
            meta["art"] = "res://" + rig
        with open("data/creatures/%s.json" % d["id"], "w") as fh:
            json.dump(meta, fh, indent=1)
            fh.write("\n")
    print("build_campaign: wrote data/campaign.json and 100 creature files")


if __name__ == "__main__":
    sys.exit(main())
