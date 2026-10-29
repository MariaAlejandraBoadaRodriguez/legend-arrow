#!/usr/bin/env bash
# Builds every Google Play listing asset in docs/store/play_console/ from the
# real game, then checks names, sizes, format and limits (tools/store_assets.py).
# Screenshots are rendered by Godot at each device size (tools/capture_store.gd);
# the icon is tools/make_icons.py (the launcher artwork). Needs Xvfb + Pillow.
#   GODOT=/path/to/godot tools/make_store_graphics.sh
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-$(scripts/install_godot.sh)}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
export XDG_DATA_HOME="$WORK/data"   # fresh save, never the developer's
export PYTHONDONTWRITEBYTECODE=1
rm -rf build/store
# profile  mode    render size (game area; tools/store_assets.py PROFILES)
while read -r profile mode size; do
  xvfb-run -a -s "-screen 0 3000x3000x24" "$GODOT" --path . --rendering-driver opengl3 \
    --audio-driver Dummy --resolution "$size" -s res://tools/capture_store.gd -- "$mode" "res://build/store/$profile" \
    >"$WORK/$profile.log" 2>&1
  grep -q "capture_store: wrote" "$WORK/$profile.log" || { cat "$WORK/$profile.log"; exit 1; }
done <<'EOF'
phone    phone   1080x1704
tablet7  tablet  1200x1920
tablet10 tablet  1440x2304
feature  feature 1024x500
EOF
python3 tools/store_assets.py compose build/store
