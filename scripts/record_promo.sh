#!/usr/bin/env bash
# Records the store promo footage: the real game, played by the "promo"
# journey (scripts/e2e/device_e2e.gd) with real taps, captured by Godot's
# Movie Maker at a fixed 30 fps in portrait 1080x1920 with the game's own
# music and sound effects. Writes <work>/promo.avi and <work>/marks.txt
# ("<scene> <frame>"), then scripts/make_promo_video.sh edits the videos.
# Needs Xvfb.
#
#   GODOT=/path/to/godot scripts/record_promo.sh <work_dir>
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
WORK="${1:?work dir}"
mkdir -p "$WORK"
DATA="$(mktemp -d)"
export XDG_DATA_HOME="$DATA"
DISP=":$(( 150 + RANDOM % 100 ))"
Xvfb "$DISP" -screen 0 1080x1920x24 >/dev/null 2>&1 &
XVFB=$!
# Movie Maker records the window; the project's window override is a small
# desktop preview size, so a temporary override.cfg (untracked, removed on
# exit) sets the window to a full-HD portrait phone screen.
[[ ! -e override.cfg ]] || { echo "record_promo: override.cfg already exists" >&2; exit 1; }
printf '[display]\n\nwindow/size/window_width_override=1080\nwindow/size/window_height_override=1920\n' > override.cfg
trap 'kill -9 $XVFB 2>/dev/null || true; rm -rf "$DATA"; rm -f override.cfg' EXIT
export DISPLAY="$DISP"
sleep 1
"$GODOT" --path . --rendering-driver opengl3 --resolution 1080x1920 \
  --write-movie "$WORK/promo.avi" --fixed-fps 30 -- --e2e=promo >"$WORK/log.txt" 2>&1 &
pid=$!
verdict=""
for _ in $(seq 1 3000); do
  verdict="$(grep -oE "LEGEND_E2E (PASS|FAIL) promo.*" "$WORK/log.txt" | head -1 || true)"
  [[ -n "$verdict" ]] && break
  kill -0 "$pid" 2>/dev/null || break
  sleep 1
done
for _ in $(seq 1 120); do kill -0 "$pid" 2>/dev/null || break; sleep 0.5; done
kill -9 "$pid" 2>/dev/null || true
[[ "$verdict" == *PASS* ]] || { grep -E "LEGEND_E2E|ERROR" "$WORK/log.txt" | tail -40; echo "record_promo: journey did not pass" >&2; exit 1; }
grep -oE "LEGEND_E2E MARK [a-z0-9_]+ frame=[0-9]+" "$WORK/log.txt" | awk '{split($4,a,"="); print $3, a[2]}' > "$WORK/marks.txt"
echo "record_promo: $(wc -l < "$WORK/marks.txt") marks, $(stat -c %s "$WORK/promo.avi") bytes"
