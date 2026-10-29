#!/usr/bin/env bash
# Builds the Google Play listing graphics in docs/store/ from the real game:
#   icon_512.png            512x512, 32-bit PNG, fully opaque (Play app icon)
#   feature_graphic.png     1024x500, 24-bit PNG (no alpha)
#   phone_1..4_*.png        1080x1920, 24-bit PNG (no alpha)
# Screens and the feature graphic are rendered by Godot (tools/capture_store.gd);
# the icon is the launcher icon artwork (tools/make_icons.py). Needs Xvfb + Pillow.
#   GODOT=/path/to/godot tools/make_store_graphics.sh
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-$(scripts/install_godot.sh)}"
OUT=docs/store
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
export XDG_DATA_HOME="$WORK/data"   # fresh save, never the developer's
rm -rf build/store
for spec in "screens 1080x1920" "feature 1024x500"; do
  set -- $spec
  xvfb-run -a -s "-screen 0 2200x2200x24" "$GODOT" --path . --rendering-driver opengl3 \
    --audio-driver Dummy --resolution "$2" -s res://tools/capture_store.gd -- "$1" >"$WORK/$1.log" 2>&1
  grep -q "capture_store: wrote" "$WORK/$1.log" || { cat "$WORK/$1.log"; exit 1; }
done
mkdir -p "$OUT"
PYTHONDONTWRITEBYTECODE=1 python3 - "$OUT" <<'PY'
import sys
from PIL import Image
sys.path.insert(0, "tools")
import make_icons

out = sys.argv[1]
icon = make_icons.make(512).convert("RGBA")
icon.save(f"{out}/icon_512.png")
Image.open("build/store/feature.png").convert("RGB").save(f"{out}/feature_graphic.png", optimize=True)
for i, name in enumerate(["home", "puzzle", "awakening", "bestiary"], 1):
    Image.open(f"build/store/{name}.png").convert("RGB").save(f"{out}/phone_{i}_{name}.png", optimize=True)

# Play Console requirements.
import os
checks = [("icon_512.png", (512, 512), "RGBA", 1 << 20)]
checks.append(("feature_graphic.png", (1024, 500), "RGB", 15 << 20))
checks += [(f"phone_{i}_{n}.png", (1080, 1920), "RGB", 8 << 20)
           for i, n in enumerate(["home", "puzzle", "awakening", "bestiary"], 1)]
for name, size, mode, limit in checks:
    path = f"{out}/{name}"
    im = Image.open(path)
    assert im.size == size, f"{name}: {im.size} != {size}"
    assert im.mode == mode, f"{name}: mode {im.mode} != {mode}"
    if mode == "RGBA":
        assert im.getextrema()[3] == (255, 255), f"{name}: has transparency"
    assert os.path.getsize(path) <= limit, f"{name}: too large"
    print(f"ok  {name:28s} {size[0]}x{size[1]} {mode} {os.path.getsize(path) // 1024} KB")
PY
