#!/usr/bin/env python3
"""Google Play listing assets: the expected files, how they are composed from
the game renders, and the checks (needs Pillow).

  python3 tools/store_assets.py compose BUILD_DIR   # build/store -> docs/store/play_console
  python3 tools/store_assets.py check [DIR]         # verify names, sizes, format, limits

Screenshots are real frames of the game (tools/capture_store.gd) with a
one-line caption band on top, set in the game's typeface (Inter) and colours.
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

OUT = "docs/store/play_console"
IVORY = (250, 249, 246)
GRAPHITE = (37, 40, 43)
SLATE = (71, 103, 124)
FONT = "assets/fonts/Inter-SemiBold.ttf"
MB = 1024 * 1024

# Device profiles: final size, game render size (the rest is the caption band).
PROFILES = {
    "phone": ((1080, 1920), (1080, 1704)),
    "tablet7": ((1200, 2133), (1200, 1920)),    # 10:16 tablet screen
    "tablet10": ((1440, 2560), (1440, 2304)),   # 10:16 tablet screen
}

CAPTIONS = {
    "home": "Calm puzzles. Legendary creatures.",
    "tutorial": "Tap an arrow with a clear way out",
    "puzzle": "Clear the board, arrow by arrow",
    "awakening": "Solve both puzzles to awaken it",
    "bestiary": "Collect 12 legends in 3 realms",
    "creature": "Every creature has its story",
}

PHONE = [("01_inicio", "home"), ("02_tutorial", "tutorial"), ("03_puzzle", "puzzle"),
         ("04_despertar", "awakening"), ("05_bestiario", "bestiary"), ("06_criatura", "creature")]
TABLET = [("01_inicio", "home"), ("02_puzzle", "puzzle"), ("03_despertar", "awakening"),
          ("04_bestiario", "bestiary")]


def expected():
    """[(file name, (w, h), mode, byte limit, source)] in Play Console order."""
    files = [
        ("01_Recursos_visuales_comunes__Icono_de_la_aplicacion__512x512.png", (512, 512), "RGBA", 1 * MB, "icon"),
        ("02_Recursos_visuales_comunes__Grafico_de_funciones__1024x500.png", (1024, 500), "RGB", 15 * MB, "feature"),
    ]
    for tag, shot in PHONE:
        files.append((f"03_Recursos_visuales_comunes__Capturas_telefono__{tag}__1080x1920.png",
                      (1080, 1920), "RGB", 8 * MB, ("phone", shot)))
    for prefix, profile, (w, h) in (("04_Recursos_para_tablet__Capturas_7_pulgadas", "tablet7", (1200, 2133)),
                                    ("05_Recursos_para_tablet__Capturas_10_pulgadas", "tablet10", (1440, 2560))):
        for tag, shot in TABLET:
            files.append((f"{prefix}__{tag}__{w}x{h}.png", (w, h), "RGB", 8 * MB, (profile, shot)))
    return files


def caption_band(width, height, text):
    band = Image.new("RGB", (width, height), IVORY)
    d = ImageDraw.Draw(band)
    margin = int(width * 0.07)
    size = int(height * 0.25)
    while True:
        font = ImageFont.truetype(FONT, size)
        x0, y0, x1, y1 = d.textbbox((0, 0), text, font=font)
        if x1 - x0 <= width - 2 * margin or size <= 20:
            break
        size -= 1
    tw, th = x1 - x0, y1 - y0
    ty = (height - th) // 2 - y0 - int(height * 0.04)
    d.text(((width - tw) // 2 - x0, ty), text, font=font, fill=GRAPHITE)
    rule_w, rule_h = int(width * 0.08), max(4, height // 45)
    ry = ty + y1 + int(height * 0.09)
    d.rectangle([(width - rule_w) // 2, ry, (width + rule_w) // 2, ry + rule_h], fill=SLATE)
    return band


def compose(build):
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    from make_icons import make
    os.makedirs(OUT, exist_ok=True)
    for name in os.listdir(OUT):
        if name.endswith(".png"):
            os.remove(os.path.join(OUT, name))
    for name, size, mode, _, source in expected():
        path = os.path.join(OUT, name)
        if source == "icon":
            make(512).convert("RGBA").save(path)
        elif source == "feature":
            Image.open(f"{build}/feature/feature.png").convert("RGB").save(path, optimize=True)
        else:
            profile, shot = source
            final, game_size = PROFILES[profile]
            game = Image.open(f"{build}/{profile}/{shot}.png").convert("RGB")
            assert game.size == game_size, f"{profile}/{shot}: rendered {game.size}, expected {game_size}"
            im = Image.new("RGB", final, IVORY)
            im.paste(caption_band(final[0], final[1] - game_size[1], CAPTIONS[shot]), (0, 0))
            im.paste(game, (0, final[1] - game_size[1]))
            im.save(path, optimize=True)


def check(folder=OUT):
    ok = True
    want = {name for name, *_ in expected()}
    have = {n for n in os.listdir(folder) if n.endswith(".png")}
    for name in sorted(have - want):
        print(f"FAIL  unexpected file {name}")
        ok = False
    print(f"{'result':6} {'file':84} {'size':>11} {'mode':5} {'KB':>6}  limit")
    for name, size, mode, limit, _ in expected():
        path = os.path.join(folder, name)
        if not os.path.exists(path):
            print(f"FAIL   {name:84} missing")
            ok = False
            continue
        im = Image.open(path)
        problems = []
        if im.format != "PNG":
            problems.append(f"format {im.format}")
        if im.size != size:
            problems.append(f"size {im.size[0]}x{im.size[1]} != {size[0]}x{size[1]}")
        if im.mode != mode:
            problems.append(f"mode {im.mode} != {mode}")
        if im.mode == "RGBA" and im.getchannel("A").getextrema() != (255, 255):
            problems.append("has transparent pixels")
        if os.path.getsize(path) > limit:
            problems.append(f"over {limit // MB} MB")
        status = "FAIL" if problems else "ok"
        ok = ok and not problems
        print(f"{status:6} {name:84} {im.size[0]:>5}x{im.size[1]:<5} {im.mode:5} "
              f"{os.path.getsize(path) // 1024:>6}  {limit // MB} MB  {'; '.join(problems)}")
    print(f"store assets: {'PASS' if ok else 'FAIL'} ({len(want)} files expected, {len(have)} present)")
    return ok


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "compose":
        compose(sys.argv[2] if len(sys.argv) > 2 else "build/store")
        sys.exit(0 if check() else 1)
    sys.exit(0 if check(sys.argv[2] if len(sys.argv) > 2 else OUT) else 1)
