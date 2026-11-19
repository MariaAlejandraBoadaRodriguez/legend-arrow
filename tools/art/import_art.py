#!/usr/bin/env python3
"""Photoreal dragon art import pipeline (v0.2 §4, D-49).

For every roster dragon (data/roster.json) this reads
assets/creatures/raw/<dragon_id>.png (owner-generated with ChatGPT, paid plan,
commercial use) and:

  1. validates the name against the roster, the format (PNG), the size
     (>= 1024 px wide) and the aspect (~2:3 portrait, 1.40-1.60);
  2. removes the background with rembg (pinned, model isnet-general-use,
     SHA-256 checked);
  3. cleans the cut-out: un-mixes the studio backdrop from semi-transparent
     edge pixels (no gray halo), drops alpha < 3%, removes specks (< 0.4% of
     the largest part), trims to the subject + margin and feathers the edge;
  4. checks the cut quality and FAILS LOUDLY when it looks wrong: almost
     nothing or almost everything kept, the subject touching 2+ image edges
     (backdrop left in), a gray fringe still present, or several large parts;
  5. writes, within the size budget:
       assets/creatures/art/<id>.webp     full cut-out (<= 1200 px tall, q 82)
       assets/creatures/thumbs/<id>.webp  still thumbnail (256 px tall)
       assets/creatures/masks/<id>.png    silhouette mask, 256x384 frame
       assets/creatures/silhouettes/<id>.png  locked-tile silhouette
  6. prints a per-file report, writes build/art/report.json and
     docs/ART_STATUS.md, and exits 1 if any file is missing, misnamed,
     wrong-sized or badly cut.

  scripts/import_art.sh [dragon_id ...]       (sets up the pinned venv)
  python3 tools/art/import_art.py --status    (ART_STATUS.md only, no rembg)
"""
import hashlib
import json
import os
import sys
import time

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROSTER = "data/roster.json"
RAW = "assets/creatures/raw"
OUT_ART = "assets/creatures/art"
OUT_THUMB = "assets/creatures/thumbs"
OUT_MASK = "assets/creatures/masks"
OUT_SIL = "assets/creatures/silhouettes"
REPORT = "build/art/report.json"
STATUS = "docs/ART_STATUS.md"

MODEL = "isnet-general-use"
MODEL_SHA256 = "60920e99c45464f2ba57bee2ad08c919a52bbf852739e96947fbb4358c0d964a"
MIN_WIDTH = 1024
ASPECT = (1.40, 1.60)          # height / width, ~2:3 portrait
ART_MAX_H = 1200
THUMB_H = 256
MASK_W, MASK_H = 256, 384
WEBP_Q = 82
BUDGET_ART = 450 * 1024        # bytes per full image
BUDGET_TOTAL = 60 * 1024 * 1024


def load_roster():
    return json.load(open(ROSTER, encoding="utf-8"))


def validate(path):
    errs = []
    if not os.path.exists(path):
        return ["missing"]
    try:
        im = Image.open(path)
        im.verify()
        im = Image.open(path)
    except Exception as e:  # noqa: BLE001
        return [f"not a readable image ({e})"]
    if im.format != "PNG":
        errs.append(f"format {im.format}, expected PNG")
    w, h = im.size
    if w < MIN_WIDTH:
        errs.append(f"width {w} < {MIN_WIDTH}")
    if not (ASPECT[0] <= h / float(w) <= ASPECT[1]):
        errs.append(f"aspect {h}/{w} = {h / float(w):.2f}, expected ~2:3 portrait ({ASPECT[0]}-{ASPECT[1]})")
    return errs


def backdrop_colour(rgb):
    a = np.asarray(rgb).astype(np.float64)
    border = np.concatenate([a[:8].reshape(-1, 3), a[-8:].reshape(-1, 3), a[:, :8].reshape(-1, 3), a[:, -8:].reshape(-1, 3)])
    return np.median(border, axis=0)


def clean(rgba, bg):
    """Un-mix the backdrop from edge pixels, drop specks, trim, feather."""
    a = np.asarray(rgba).astype(np.float64)
    rgb, al = a[..., :3], a[..., 3] / 255.0
    al[al < 0.03] = 0.0
    # colour decontamination: I = a*F + (1-a)*B  ->  F = (I - (1-a)B) / a
    edge = (al > 0.0) & (al < 0.98)
    safe = np.maximum(al, 0.25)[..., None]
    un = (rgb - (1.0 - safe) * bg[None, None, :]) / safe
    rgb = np.where(edge[..., None], np.clip(un, 0, 255), rgb)
    keep = _main_parts(al > 0.5)
    al = np.where(keep, al, 0.0)
    out = Image.fromarray(np.dstack([rgb, al * 255.0]).astype(np.uint8), "RGBA")
    alpha = out.getchannel("A").filter(ImageFilter.GaussianBlur(0.6))
    out.putalpha(alpha)
    box = out.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox()
    if box is None:
        return out, None
    pad = 12
    box = (max(0, box[0] - pad), max(0, box[1] - pad), min(out.width, box[2] + pad), min(out.height, box[3] + pad))
    return out.crop(box), box


def _main_parts(hard):
    """Keeps parts >= 0.4% of the largest one (specks and stray blobs go)."""
    small = Image.fromarray((hard * 255).astype(np.uint8)).resize((hard.shape[1] // 4, hard.shape[0] // 4), Image.NEAREST)
    work = small.copy()
    arr = np.asarray(small) == 255
    comps, label = [], 1
    for y, x in zip(*np.nonzero(arr)):
        if work.getpixel((int(x), int(y))) != 255:
            continue
        ImageDraw.floodfill(work, (int(x), int(y)), label)
        comps.append(((np.asarray(work) == label).sum(), label))
        label += 1
        if label >= 250:
            break
    if not comps:
        return hard
    big = max(s for s, _ in comps)
    keep = [lab for s, lab in comps if s >= 0.004 * big]
    lab_full = np.asarray(Image.fromarray(np.asarray(work)).resize((hard.shape[1], hard.shape[0]), Image.NEAREST))
    near = np.isin(lab_full, keep)
    # keep soft/thin structure (whiskers) adjacent to kept parts: dilate the kept area
    near = np.asarray(Image.fromarray((near * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(9))) > 0
    return near


def quality(cut, box, size, bg):
    """Returns a list of problems that make the cut unusable."""
    errs = []
    al = np.asarray(cut.getchannel("A")).astype(np.float64) / 255.0
    w, h = size
    cover = (al > 0.5).sum() / float(w * h)
    if cover < 0.03:
        errs.append(f"almost nothing kept ({cover:.1%} of the image)")
    if cover > 0.70:
        errs.append(f"almost everything kept ({cover:.1%}): background not removed")
    if box is not None:
        touches = sum([box[0] <= 2, box[1] <= 2, box[2] >= w - 2, box[3] >= h - 2])
        if touches >= 2:
            errs.append(f"subject touches {touches} image edges: backdrop likely left in")
    # gray fringe: opaque-ish edge pixels whose colour is still the backdrop
    rgb = np.asarray(cut.convert("RGB")).astype(np.float64)
    ring = (al > 0.35) & (al < 0.9)
    if ring.sum() > 50:
        d = np.sqrt(((rgb[ring] - bg[None, :]) ** 2).sum(1))
        fringe = (d < 18).mean()
        if fringe > 0.35:
            errs.append(f"gray halo: {fringe:.0%} of edge pixels still backdrop-coloured")
    return errs


def write_outputs(did, cut):
    os.makedirs(OUT_ART, exist_ok=True)
    os.makedirs(OUT_THUMB, exist_ok=True)
    os.makedirs(OUT_MASK, exist_ok=True)
    os.makedirs(OUT_SIL, exist_ok=True)
    art = cut
    if art.height > ART_MAX_H:
        art = art.resize((max(1, round(art.width * ART_MAX_H / art.height)), ART_MAX_H), Image.LANCZOS)
    q = WEBP_Q
    p_art = os.path.join(OUT_ART, did + ".webp")
    while True:
        art.save(p_art, "WEBP", quality=q, method=6, alpha_quality=90)
        if os.path.getsize(p_art) <= BUDGET_ART or q <= 60:
            break
        q -= 6
    th = cut.resize((max(1, round(cut.width * THUMB_H / cut.height)), THUMB_H), Image.LANCZOS)
    th.save(os.path.join(OUT_THUMB, did + ".webp"), "WEBP", quality=80, method=6)
    # mask in a fixed 256x384 frame (subject fitted, centred) for level shapes
    a = cut.getchannel("A")
    s = min(MASK_W / a.width, MASK_H / a.height)
    a2 = a.resize((max(1, round(a.width * s)), max(1, round(a.height * s))), Image.LANCZOS)
    frame = Image.new("L", (MASK_W, MASK_H), 0)
    frame.paste(a2, ((MASK_W - a2.width) // 2, (MASK_H - a2.height) // 2))
    frame.point(lambda v: 255 if v > 110 else 0).save(os.path.join(OUT_MASK, did + ".png"), optimize=True)
    sh = 256
    sw = max(1, round(a.width * sh / a.height))
    if sw > 384:
        sw, sh = 384, max(1, round(a.height * 384 / a.width))
    sil = Image.new("LA", (sw, sh), (255, 0))
    sil.putalpha(a.resize((sw, sh), Image.LANCZOS))
    sil.save(os.path.join(OUT_SIL, did + ".png"), optimize=True)
    return {"art_bytes": os.path.getsize(p_art), "webp_quality": q, "art_size": list(art.size)}


def session():
    from rembg import new_session  # imported late: --status needs no rembg
    s = new_session(MODEL)
    path = os.path.expanduser(f"~/.u2net/{MODEL}.onnx")
    digest = hashlib.sha256(open(path, "rb").read()).hexdigest()
    if digest != MODEL_SHA256:
        raise SystemExit(f"import_art: model {MODEL} checksum {digest} != pinned {MODEL_SHA256}")
    return s


def write_status(roster, results):
    imported = [d for d in roster["dragons"] if results.get(d["id"], {}).get("status") == "IMPORTED"]
    keep = ""
    if os.path.exists(STATUS):
        old = open(STATUS, encoding="utf-8").read()
        if "## Review notes" in old:   # human review notes survive re-imports
            keep = old[old.index("## Review notes"):old.index("| # | Dragon")]
    lines = ["# Art status", "",
             "Generated by `tools/art/import_art.py` (D-49). Owner images: `assets/creatures/raw/<dragon_id>.png`.",
             "A release AAB is never produced while any dragon is ART PENDING or REJECTED (CLAUDE.md).", "",
             f"**Imported: {len(imported)} / {len(roster['dragons'])}** · "
             f"ART PENDING: {sum(1 for d in roster['dragons'] if results.get(d['id'], {}).get('status', 'ART PENDING') == 'ART PENDING')} · "
             f"REJECTED: {sum(1 for d in roster['dragons'] if results.get(d['id'], {}).get('status') == 'REJECTED')}", "",
             keep.rstrip(), "",
             "| # | Dragon | World | Status | Notes |", "|---|---|---|---|---|"]
    for d in roster["dragons"]:
        r = results.get(d["id"], {"status": "ART PENDING", "problems": ["no image yet"]})
        note = "; ".join(r.get("problems", [])) or (f"{r.get('art_bytes', 0) // 1024} KB webp" if r.get("art_bytes") else "")
        lines.append(f"| {d['number']:03d} | {d['name']} (`{d['id']}`) | {d['world']} | {r['status']} | {note} |")
    open(STATUS, "w", encoding="utf-8").write("\n".join(lines) + "\n")


def main():
    roster = load_roster()
    ids = [d["id"] for d in roster["dragons"]]
    only = [a for a in sys.argv[1:] if not a.startswith("--")]
    prev = json.load(open(REPORT)) if os.path.exists(REPORT) else {}
    results = dict(prev)
    if "--status" in sys.argv:
        write_status(roster, results)
        print(f"import_art: wrote {STATUS}")
        return 0
    failures = 0
    unknown = sorted({f[:-4] for f in os.listdir(RAW) if f.endswith(".png")} - set(ids)) if os.path.isdir(RAW) else []
    for u in unknown:
        print(f"FAIL {u}.png: not in the roster (misnamed?)")
        failures += 1
    for f in sorted(os.listdir(RAW)) if os.path.isdir(RAW) else []:
        if not f.endswith(".png") and not f.startswith(".") and not f.endswith(".import"):
            print(f"FAIL {f}: not a .png named <dragon_id>.png")
            failures += 1
    targets = only or ids
    sess = None
    t0 = time.time()
    for did in targets:
        if did not in ids:
            print(f"FAIL {did}: not a roster id")
            failures += 1
            continue
        path = os.path.join(RAW, did + ".png")
        errs = validate(path)
        if errs == ["missing"]:
            results[did] = {"status": "ART PENDING", "problems": ["no image yet"]}
            print(f"PEND {did}: missing (ART PENDING)")
            continue
        if errs:
            results[did] = {"status": "REJECTED", "problems": errs}
            print(f"FAIL {did}: {'; '.join(errs)}")
            failures += 1
            continue
        if sess is None:
            sess = session()
        from rembg import remove
        src = Image.open(path).convert("RGB")
        bg = backdrop_colour(src)
        cut, box = clean(remove(src, session=sess).convert("RGBA"), bg)
        problems = quality(cut, box, src.size, bg) if box else ["nothing kept"]
        if problems:
            results[did] = {"status": "REJECTED", "problems": problems}
            print(f"FAIL {did}: {'; '.join(problems)}")
            failures += 1
            continue
        info = write_outputs(did, cut)
        results[did] = {"status": "IMPORTED", "problems": [], **info}
        print(f"OK   {did}: {info['art_size'][0]}x{info['art_size'][1]} webp q{info['webp_quality']} "
              f"{info['art_bytes'] // 1024} KB")
    total = sum(os.path.getsize(os.path.join(OUT_ART, f)) for f in os.listdir(OUT_ART)) if os.path.isdir(OUT_ART) else 0
    if total > BUDGET_TOTAL:
        print(f"FAIL size budget: full images total {total // 1024 // 1024} MB > {BUDGET_TOTAL // 1024 // 1024} MB")
        failures += 1
    os.makedirs(os.path.dirname(REPORT), exist_ok=True)
    json.dump(results, open(REPORT, "w"), indent=1, sort_keys=True)
    write_status(roster, results)
    n_ok = sum(1 for r in results.values() if r.get("status") == "IMPORTED")
    print(f"import_art: {n_ok}/{len(ids)} imported, {failures} failure(s), art total {total / 1024 / 1024:.1f} MB, "
          f"{time.time() - t0:.0f} s")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
