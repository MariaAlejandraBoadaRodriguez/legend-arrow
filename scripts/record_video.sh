#!/usr/bin/env bash
# Records a gameplay + awakening video of the real game with Godot's Movie
# Maker (deterministic, fixed 30 fps, every frame rendered): the fresh_install
# journey (Home -> tutorial -> Forest Drake's two puzzles -> awakening ->
# creature detail), driven by DeviceE2E. Needs Xvfb + ffmpeg.
#
#   GODOT=/path/to/godot scripts/record_video.sh [out.mp4]
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
OUT="${1:-build/video/legend_arrow_gameplay.mp4}"
mkdir -p "$(dirname "$OUT")"
WORK="$(mktemp -d)"
export XDG_DATA_HOME="$WORK/data"
DISP=":$(( 150 + RANDOM % 100 ))"
Xvfb "$DISP" -screen 0 720x1280x24 >/dev/null 2>&1 &
XVFB=$!
trap 'kill -9 $XVFB 2>/dev/null || true; rm -rf "$WORK"' EXIT
export DISPLAY="$DISP"
sleep 1
"$GODOT" --path . --rendering-driver opengl3 --audio-driver Dummy --resolution 720x1280 \
  --write-movie "$WORK/movie.avi" --fixed-fps 30 -- --e2e=fresh_install >"$WORK/log.txt" 2>&1 &
pid=$!
verdict=""
for _ in $(seq 1 600); do
  verdict="$(grep -oE "LEGEND_E2E (PASS|FAIL) fresh_install" "$WORK/log.txt" | head -1 || true)"
  [[ -n "$verdict" ]] && break
  kill -0 "$pid" 2>/dev/null || break
  sleep 1
done
sleep 1
kill -INT "$pid" 2>/dev/null || true   # graceful quit finalises the AVI
for _ in $(seq 1 20); do kill -0 "$pid" 2>/dev/null || break; sleep 0.5; done
kill -9 "$pid" 2>/dev/null || true
[[ "$verdict" == *PASS* ]] || { cat "$WORK/log.txt"; echo "record_video: journey did not pass" >&2; exit 1; }
ffmpeg -v error -y -i "$WORK/movie.avi" -vf "scale=trunc(iw/2)*2:trunc(ih/2)*2" \
  -c:v libx264 -pix_fmt yuv420p -crf 24 -movflags +faststart -an "$OUT"
dur="$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$OUT")"
echo "record_video: $OUT ${dur}s $(stat -c %s "$OUT") bytes"
awk -v d="$dur" 'BEGIN { exit !(d > 5) }' || { echo "record_video: video too short" >&2; exit 1; }
