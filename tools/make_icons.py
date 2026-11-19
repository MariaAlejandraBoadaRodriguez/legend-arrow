#!/usr/bin/env python3
"""Builds every app icon from the owner's artwork (needs Pillow + numpy).

Source: assets/icon/icon_source.png, owner-generated with ChatGPT (paid
plan, commercial use; D-44). Its green dragon head on light gray is kept as
designed.

Outputs (assets/icon/):
  icon_512.png                 Play Store icon: the source, 512x512, opaque
  icon_192.png                 legacy launcher icon (same framing)
  adaptive_background_432.png  the source's own gray vignette, without the dragon
  adaptive_foreground_432.png  cut-out dragon, head scaled into the 66 dp safe
                               circle (eye, horns, snout never clipped)
  monochrome_432.png           themed-icon silhouette (eye cut out)
and docs/store/play_console/01_Graphics__App_icon__512x512.png.

The cut-out is a colour key: the backdrop is neutral gray (saturation < 0.03)
and the dragon is saturated green/gold, so alpha = smooth step on saturation,
with interior holes filled and a 1 px feather. Deterministic.

  python3 tools/make_icons.py            # write all outputs
  python3 tools/make_icons.py --check    # verify outputs exist and are valid
"""
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

SRC = "assets/icon/icon_source.png"
OUT = "assets/icon"
STORE = "docs/store/play_console/01_Graphics__App_icon__512x512.png"

# Key points of the head in source pixels (horn tips, snout tip, chin, eye),
# read off the 1254 px artwork. They must all land inside the safe circle.
KEY_POINTS = [(188, 214), (265, 193), (1060, 600), (1030, 700), (760, 485), (600, 240)]
EYE_BOX = (680, 425, 830, 545)

CANVAS = 432                     # 108 dp at 4x
SAFE_R = 132                     # 66 dp safe-zone circle radius (33 dp) at 4x
FIT_R = SAFE_R - 8               # margin inside the safe circle


def source():
    im = Image.open(SRC).convert("RGB")
    if im.size[0] != im.size[1] or im.size[0] < 1024:
        raise SystemExit(f"icon source must be square and >= 1024 px, got {im.size}")
    return im


def alpha_mask(im):
    a = np.asarray(im).astype(np.float32)
    mx, mn = a.max(2), a.min(2)
    sat = (mx - mn) / np.maximum(mx, 1.0)
    alpha = np.clip((sat - 0.12) / 0.10, 0.0, 1.0)
    # Fill interior holes: anything not reachable from the border through
    # transparent pixels belongs to the dragon (eye glints, pale scales).
    hard = Image.fromarray(((alpha > 0.5) * 255).astype(np.uint8))
    filled = hard.copy()
    ImageDraw.floodfill(filled, (0, 0), 128)
    outside = np.asarray(filled) == 128
    alpha = np.where(~outside, np.maximum(alpha, (np.asarray(hard) == 0) * 1.0), alpha)
    m = Image.fromarray((alpha * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.8))
    return m


def background_field(im, mask, size):
    """Radial profile of the source's own gray backdrop (dragon excluded)."""
    a = np.asarray(im).astype(np.float32)
    m = np.asarray(mask) < 8
    h, w = m.shape
    cy, cx = h * 0.42, w * 0.52            # brightest area of the vignette
    yy, xx = np.mgrid[0:h, 0:w]
    r = np.hypot((xx - cx) / w, (yy - cy) / h)
    bins = np.linspace(0, r.max() + 1e-6, 40)
    idx = np.digitize(r, bins)
    prof = []
    for i in range(1, len(bins)):
        sel = m & (idx == i)
        prof.append(np.median(a[sel], axis=0) if sel.sum() > 50 else None)
    # fill gaps by nearest known value
    known = [i for i, p in enumerate(prof) if p is not None]
    prof = [prof[min(known, key=lambda k: abs(k - i))] for i in range(len(prof))]
    centers = (bins[:-1] + bins[1:]) / 2
    yy, xx = np.mgrid[0:size, 0:size]
    rr = np.hypot((xx + 0.5) / size - cx / w, (yy + 0.5) / size - cy / h)
    out = np.stack([np.interp(rr, centers, [p[c] for p in prof]) for c in range(3)], -1)
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), "RGB")


def fit_transform(src_size):
    """Scale + offset so every key point lies within FIT_R of the canvas centre."""
    pts = np.array(KEY_POINTS, dtype=np.float64)
    # minimal enclosing circle (brute force on pairs/triples is overkill: use
    # bounding-box centre refined by a few iterations of the "move to farthest" rule)
    c = pts.mean(0)
    for _ in range(200):
        d = np.hypot(*(pts - c).T)
        far = pts[d.argmax()]
        c = c + (far - c) * 0.02
    rad = np.hypot(*(pts - c).T).max()
    scale = FIT_R / rad
    offset = np.array([CANVAS / 2, CANVAS / 2]) - c * scale
    return scale, offset


def foreground(im, mask):
    scale, (ox, oy) = fit_transform(im.size[0])
    n = int(round(im.size[0] * scale))
    rgba = im.convert("RGBA")
    rgba.putalpha(mask)
    rgba = rgba.resize((n, n), Image.LANCZOS)
    canvas = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    canvas.alpha_composite(rgba, (int(round(ox)), int(round(oy))))
    return canvas, scale, (ox, oy)


def eye_mask(im):
    a = np.asarray(im).astype(np.int32)
    x0, y0, x1, y1 = EYE_BOX
    box = a[y0:y1, x0:x1]
    r, g, b = box[..., 0], box[..., 1], box[..., 2]
    yellow = (r > 150) & (g > 110) & (b < 110) & (r - b > 70)
    ys, xs = np.nonzero(yellow)
    full = Image.new("L", im.size, 0)
    if len(xs):
        ImageDraw.Draw(full).ellipse([x0 + xs.min() - 3, y0 + ys.min() - 3, x0 + xs.max() + 3, y0 + ys.max() + 3],
                                     fill=255)
    return full


def monochrome(im, mask):
    m = np.asarray(mask).astype(np.float32) / 255
    e = np.asarray(eye_mask(im)).astype(np.float32) / 255
    sil = Image.fromarray((np.clip(m - e, 0, 1) * 255).astype(np.uint8))
    scale, (ox, oy) = fit_transform(im.size[0])
    n = int(round(im.size[0] * scale))
    sil = sil.resize((n, n), Image.LANCZOS)
    a = Image.new("L", (CANVAS, CANVAS), 0)
    a.paste(sil, (int(round(ox)), int(round(oy))))
    out = Image.new("RGBA", (CANVAS, CANVAS), (255, 255, 255, 0))
    out.putalpha(a)
    return out


def adaptive_preview(size, shape="circle"):
    """What a launcher shows: background + foreground, cropped to the 72 dp
    viewport (inner 2/3 of the 108 dp layer), then masked."""
    bg = Image.open(os.path.join(OUT, "adaptive_background_432.png")).convert("RGBA")
    fg = Image.open(os.path.join(OUT, "adaptive_foreground_432.png")).convert("RGBA")
    full = Image.alpha_composite(bg, fg)
    vp = CANVAS * 72 // 108
    o = (CANVAS - vp) // 2
    view = full.crop((o, o, o + vp, o + vp)).resize((size * 4, size * 4), Image.LANCZOS)
    m = Image.new("L", view.size, 0)
    d = ImageDraw.Draw(m)
    if shape == "circle":
        d.ellipse([0, 0, view.size[0] - 1, view.size[1] - 1], fill=255)
    else:
        d.rounded_rectangle([0, 0, view.size[0] - 1, view.size[1] - 1], int(view.size[0] * 0.24), fill=255)
    view.putalpha(m)
    return view.resize((size, size), Image.LANCZOS)


def build():
    im = source()
    mask = alpha_mask(im)
    store = im.resize((512, 512), Image.LANCZOS).convert("RGBA")
    store.save(os.path.join(OUT, "icon_512.png"))
    store.save(STORE)
    im.resize((192, 192), Image.LANCZOS).convert("RGBA").save(os.path.join(OUT, "icon_192.png"))
    background_field(im, mask, CANVAS).convert("RGBA").save(os.path.join(OUT, "adaptive_background_432.png"))
    fg, scale, off = foreground(im, mask)
    fg.save(os.path.join(OUT, "adaptive_foreground_432.png"))
    monochrome(im, mask).save(os.path.join(OUT, "monochrome_432.png"))
    print(f"make_icons: scale {scale:.4f}, offset ({off[0]:.1f}, {off[1]:.1f})")
    return check()


def check():
    """Asserts the outputs exist with the right size/mode/opacity and that every
    key point is inside the safe circle."""
    problems = []
    specs = {"icon_512.png": 512, "icon_192.png": 192, "adaptive_background_432.png": CANVAS,
             "adaptive_foreground_432.png": CANVAS, "monochrome_432.png": CANVAS}
    for name, size in specs.items():
        p = os.path.join(OUT, name)
        if not os.path.exists(p):
            problems.append(f"{name}: missing")
            continue
        im = Image.open(p)
        if im.size != (size, size):
            problems.append(f"{name}: size {im.size}")
        if name in ("icon_512.png", "icon_192.png", "adaptive_background_432.png"):
            if im.convert("RGBA").getextrema()[3][0] != 255:
                problems.append(f"{name}: has transparency")
    st = Image.open(STORE)
    if st.size != (512, 512) or st.convert("RGBA").getextrema()[3][0] != 255:
        problems.append("store icon not 512x512 opaque")
    scale, (ox, oy) = fit_transform(source().size[0])
    for x, y in KEY_POINTS:
        d = math.hypot(x * scale + ox - CANVAS / 2, y * scale + oy - CANVAS / 2)
        if d > SAFE_R:
            problems.append(f"key point {(x, y)} at {d:.1f} px > safe radius {SAFE_R}")
    fg = np.asarray(Image.open(os.path.join(OUT, "adaptive_foreground_432.png")))[..., 3]
    if fg[CANVAS // 2 - 40:CANVAS // 2 + 40, CANVAS // 2 - 40:CANVAS // 2 + 40].mean() < 100:
        problems.append("foreground centre is mostly transparent")
    for p in problems:
        print("FAIL", p)
    print(f"icons: {'PASS' if not problems else 'FAIL'}")
    return 0 if not problems else 1


if __name__ == "__main__":
    sys.exit(check() if "--check" in sys.argv else build())
