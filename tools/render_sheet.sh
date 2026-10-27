#!/usr/bin/env bash
# Renders a creature's awakening frames and joins them into one strip:
#   tools/render_sheet.sh <creature_id>   -> build/shots/<id>_strip.png
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-$("$ROOT/scripts/install_godot.sh")}"
xvfb-run -a "$GODOT" --path "$ROOT" --rendering-driver opengl3 --audio-driver Dummy -s res://tools/render_creature.gd -- "$1" >/dev/null 2>&1
python3 - "$ROOT/build/shots" "$1" <<'PY'
import sys
from PIL import Image
d, cid = sys.argv[1], sys.argv[2]
names = ["final", "t0.6", "t1.6", "t2.5", "t3.3", "t4.2", "t5.2"]
ims = [Image.open(f"{d}/{cid}_{n}.png").convert("RGB") for n in names]
w, h = ims[0].size
crop = [im.crop((0, int(h * 0.30), w, int(h * 0.78))) for im in ims]
out = Image.new("RGB", (w * len(crop), crop[0].height), "white")
for i, im in enumerate(crop):
    out.paste(im, (i * w, 0))
out.save(f"{d}/{cid}_strip.png")
print(f"{d}/{cid}_strip.png")
PY
