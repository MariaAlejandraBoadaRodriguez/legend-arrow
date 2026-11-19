#!/usr/bin/env python3
"""Unit tests for the art import checks (no rembg needed: synthetic images).

  python3 -m unittest tools/art/test_import_art.py
"""
import os
import sys
import tempfile
import unittest

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import import_art as ia  # noqa: E402

BG = np.array([186.0, 185.0, 184.0])


def _png(path, w, h, fmt="PNG"):
    Image.new("RGB", (w, h), (186, 185, 184)).save(path, fmt)


def _cut(alpha, rgb=(40, 120, 60)):
    a = np.asarray(alpha, dtype=np.uint8)
    h, w = a.shape
    px = np.dstack([np.full((h, w), rgb[0]), np.full((h, w), rgb[1]), np.full((h, w), rgb[2]), a]).astype(np.uint8)
    return Image.fromarray(px, "RGBA")


class Validate(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.mkdtemp()

    def test_missing(self):
        self.assertEqual(ia.validate(os.path.join(self.dir, "nope.png")), ["missing"])

    def test_good_portrait(self):
        p = os.path.join(self.dir, "ok.png")
        _png(p, 1024, 1536)
        self.assertEqual(ia.validate(p), [])

    def test_too_small_and_wrong_aspect(self):
        p = os.path.join(self.dir, "small.png")
        _png(p, 800, 800)
        errs = " ".join(ia.validate(p))
        self.assertIn("width 800", errs)
        self.assertIn("aspect", errs)

    def test_not_png(self):
        p = os.path.join(self.dir, "x.png")
        _png(p, 1024, 1536, fmt="JPEG")
        self.assertIn("format JPEG", " ".join(ia.validate(p)))

    def test_unreadable(self):
        p = os.path.join(self.dir, "bad.png")
        open(p, "wb").write(b"not an image")
        self.assertIn("not a readable image", ia.validate(p)[0])


class Quality(unittest.TestCase):
    size = (1024, 1536)

    def test_clean_subject_passes(self):
        a = np.zeros((600, 500))
        a[50:550, 50:450] = 255
        self.assertEqual(ia.quality(_cut(a), (200, 300, 700, 900), self.size, BG), [])

    def test_backdrop_left_in_is_rejected(self):
        a = np.full((1536, 1024), 255.0)
        errs = " ".join(ia.quality(_cut(a), (0, 0, 1024, 1536), self.size, BG))
        self.assertIn("almost everything kept", errs)
        self.assertIn("touches 4 image edges", errs)

    def test_nothing_kept_is_rejected(self):
        a = np.zeros((40, 40))
        a[10:20, 10:20] = 255
        self.assertIn("almost nothing kept", " ".join(ia.quality(_cut(a), (500, 500, 540, 540), self.size, BG)))

    def test_gray_halo_is_rejected(self):
        a = np.zeros((600, 500))
        a[50:550, 50:450] = 255
        a[40:50, 40:460] = 140          # semi-transparent rim ...
        a[550:560, 40:460] = 140
        img = _cut(a)
        px = np.asarray(img).copy()
        px[40:50, 40:460, :3] = BG      # ... still backdrop coloured
        px[550:560, 40:460, :3] = BG
        errs = ia.quality(Image.fromarray(px, "RGBA"), (200, 300, 700, 900), self.size, BG)
        self.assertTrue(any("halo" in e for e in errs), errs)

    def test_decontamination_removes_the_backdrop_from_edges(self):
        rgb = np.zeros((60, 60, 3)) + BG
        rgb[20:40, 20:40] = (40, 120, 60)
        al = np.zeros((60, 60))
        al[20:40, 20:40] = 255
        al[18:20, 20:40] = 128           # half-covered edge: half dragon, half backdrop
        rgb[18:20, 20:40] = 0.5 * np.array([40, 120, 60]) + 0.5 * BG
        img = Image.fromarray(np.dstack([rgb, al]).astype(np.uint8), "RGBA")
        cut, box = ia.clean(img, BG)
        px = np.asarray(cut).astype(float)
        edge = px[(px[..., 3] > 60) & (px[..., 3] < 200)][:, :3]
        self.assertGreater(len(edge), 0)
        self.assertLess(np.abs(edge.mean(0) - np.array([40, 120, 60])).max(), 40, "edge colour is the dragon's, not gray")


if __name__ == "__main__":
    unittest.main()
