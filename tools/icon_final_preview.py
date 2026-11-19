#!/usr/bin/env python3
"""Preview sheet for the final app icon (owner artwork, D-44): Play icon,
launcher circle + rounded-square masks, real 48 dp size on light and dark
simulated home screens (1 px per dp) among generic colourful icons, a 48 px
close-up (1:1 and x4) and the themed monochrome layer.

  python3 tools/make_icons.py && python3 tools/icon_final_preview.py [out.png]
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from icon_concepts_v2 import FONT, FONT_R, home_screen, _rounded  # noqa: E402
from make_icons import adaptive_preview  # noqa: E402


def sheet(out):
    pad = 28
    W, H = 1500, 1080
    im = Image.new("RGBA", (W, H), (246, 245, 241, 255))
    d = ImageDraw.Draw(im)
    d.text((pad, 24), "Legend Arrow — final app icon (owner artwork)", font=ImageFont.truetype(FONT, 32), fill=(24, 27, 31))
    d.text((pad, 70), "Play Store 512 px · launcher masks (circle, rounded square) · real 48 dp on light and dark home "
                      "screens · 48 px close-up 1:1 and ×4 · themed (monochrome) icon", font=ImageFont.truetype(FONT_R, 16),
           fill=(80, 84, 90))
    top = 120
    store = Image.open("assets/icon/icon_512.png").convert("RGBA").resize((260, 260), Image.LANCZOS)
    im.alpha_composite(_rounded(store, 50), (pad, top))
    im.alpha_composite(adaptive_preview(120, "circle"), (pad, top + 290))
    im.alpha_composite(adaptive_preview(120, "squircle"), (pad + 140, top + 290))
    sf = ImageFont.truetype(FONT_R, 13)
    d.text((pad, top + 268), "Play Store icon", font=sf, fill=(80, 84, 90))
    d.text((pad, top + 418), "launcher: circle / rounded square", font=sf, fill=(80, 84, 90))
    # themed icon
    mono = Image.open("assets/icon/monochrome_432.png").convert("RGBA")
    tile = Image.new("RGBA", (432, 432), (204, 226, 205, 255))
    tinted = Image.new("RGBA", (432, 432), (28, 60, 34, 255))
    tinted.putalpha(mono.getchannel("A"))
    tile.alpha_composite(tinted)
    vp = 288
    o = (432 - vp) // 2
    th = tile.crop((o, o, o + vp, o + vp)).resize((120, 120), Image.LANCZOS)
    m = Image.new("L", (120, 120), 0)
    ImageDraw.Draw(m).ellipse([0, 0, 119, 119], fill=255)
    th.putalpha(m)
    im.alpha_composite(th, (pad, top + 450))
    d.text((pad, top + 578), "themed icon (Android 13+)", font=sf, fill=(80, 84, 90))
    x = pad + 300
    for dark in (False, True):
        hs = home_screen(None, dark, ours_fn=lambda s: adaptive_preview(s, "circle"))
        frame = Image.new("RGBA", (372, 732), (20, 20, 22, 255))
        frame.alpha_composite(hs, (6, 6))
        im.alpha_composite(_rounded(frame, 34), (x - 6, top - 6))
        d.text((x, top + 736), ("light" if not dark else "dark") + " wallpaper, icon at 48 dp (1 px = 1 dp)",
               font=sf, fill=(80, 84, 90))
        x += 360 + pad
    small = adaptive_preview(48, "circle")
    for i, bgc in enumerate([(250, 249, 246), (18, 22, 30)]):
        yy = top + i * 330
        t = Image.new("RGBA", (72, 72), bgc + (255,))
        t.alpha_composite(small, (12, 12))
        im.alpha_composite(t, (x, yy))
        z = Image.new("RGBA", (192, 192), bgc + (255,))
        z.alpha_composite(small.resize((192, 192), Image.NEAREST))
        im.alpha_composite(z, (x, yy + 84))
        d.text((x, yy + 282), ("light" if i == 0 else "dark") + ": 48 px 1:1 (top), ×4 (below)", font=sf, fill=(80, 84, 90))
    im.convert("RGB").save(out, optimize=True)
    return out


if __name__ == "__main__":
    print(sheet(sys.argv[1] if len(sys.argv) > 1 else "docs/store/icon_final_preview.png"))
