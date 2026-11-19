#!/usr/bin/env bash
# v0.2 §9.4: captures every screen on profiles P1-P7 (tools/capture_matrix.gd)
# and builds docs/qa/screen_matrix.png. Needs Xvfb + Mesa + Pillow.
#   GODOT=/path/to/godot scripts/screen_matrix.sh [P1 P2 ...]
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-$(scripts/install_godot.sh)}"
PROFILES=("${@:-P1 P2 P3 P4 P5 P6 P7}")
PROFILES=(${PROFILES[@]})
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
for p in "${PROFILES[@]}"; do
  rm -rf "docs/qa/screens/$p"
  xvfb-run -a -s "-screen 0 1700x2700x24" "$GODOT" --path . --rendering-driver opengl3 --audio-driver Dummy \
    -s res://tools/capture_matrix.gd -- "$p" 2>&1 | grep -E "capture_matrix|SCRIPT ERROR" || true
  n=$(ls "docs/qa/screens/$p"/*.png 2>/dev/null | wc -l)
  [[ "$n" -eq 19 ]] || { echo "screen_matrix: $p has $n of 19 screens" >&2; exit 1; }
done
python3 tools/screen_matrix.py
