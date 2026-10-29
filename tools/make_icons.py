#!/usr/bin/env python3
"""Regenerates the launcher icons in assets/icon/ (needs Pillow).

The app icon is concept B from tools/icon_concepts.py: a wyvern drawn as a
board of short graphite arrows on ivory, one slate-blue arrow leaving.
The Play Store icon (512 px) and the phone launcher use the same artwork.
Run from the repo root: python3 tools/make_icons.py
"""
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from icon_concepts import IVORY, concept_b  # noqa: E402

BACKGROUND = IVORY


def make(size, background=True, scale=1.0):
    """Full-bleed icon, or (background=False) the art alone, shrunk by `scale`
    so adaptive icons keep it inside the 66/108 safe zone."""
    if background and scale == 1.0:
        return concept_b(size).convert("RGBA")
    art = concept_b(size * 2, bg=None)
    inner = int(size * 2 * scale)
    art = art.resize((inner, inner), Image.LANCZOS)
    im = Image.new("RGBA", (size * 2, size * 2), BACKGROUND + (255,) if background else (0, 0, 0, 0))
    off = (size * 2 - inner) // 2
    im.alpha_composite(art, (off, off))
    return im.resize((size, size), Image.LANCZOS)


if __name__ == "__main__":
    make(192).save("assets/icon/icon_192.png")
    make(512).save("assets/icon/icon_512.png")
    # 0.56 keeps every pixel of the wyvern inside the adaptive safe zone (a
    # 264 px circle on the 432 px canvas), so no launcher mask can clip it.
    make(432, background=False, scale=0.56).save("assets/icon/adaptive_foreground_432.png")
    Image.new("RGBA", (432, 432), BACKGROUND + (255,)).save("assets/icon/adaptive_background_432.png")
    make(432, background=False, scale=0.56).convert("LA").save("assets/icon/monochrome_432.png")
