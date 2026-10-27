#!/usr/bin/env bash
# Runs the DeviceE2E journeys against the desktop build (Xvfb + OpenGL), with
# a throw-away user data dir, in the same order and with the same
# kill/relaunch points as scripts/android_e2e.sh. Fast feedback before the
# emulator; it does not replace it.
#
#   GODOT=/path/to/godot scripts/desktop_e2e.sh [out_dir]
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
OUT="${1:-build/e2e-desktop}"
RES="${E2E_RES:-720x1280}"
rm -rf "$OUT"
mkdir -p "$OUT"
DATA="$(mktemp -d)"
export XDG_DATA_HOME="$DATA"
# One X server for the whole run; Godot is started directly so $! is Godot.
DISP=":$(( 90 + RANDOM % 100 ))"
Xvfb "$DISP" -screen 0 "${RES}x24" >/dev/null 2>&1 &
XVFB=$!
trap 'kill -9 $XVFB 2>/dev/null || true; rm -rf "$DATA"' EXIT
export DISPLAY="$DISP"
sleep 1

JOURNEYS=(${E2E_JOURNEYS:-fresh_install partial_a partial_b blocked_undo hint_ad awakening_replay settings_a settings_b})
fail=0
for j in "${JOURNEYS[@]}"; do
  log="$OUT/$j.log"
  # Each journey is a separate process launch; "_a" -> "_b" is a kill + relaunch.
  "$GODOT" --path . --rendering-driver opengl3 \
    --audio-driver Dummy --resolution "$RES" -- "--e2e=$j" >"$log" 2>&1 &
  pid=$!
  verdict=""
  for _ in $(seq 1 1800); do  # 180 s
    verdict="$(grep -oE "LEGEND_E2E (PASS|FAIL) $j.*" "$log" | head -1 || true)"
    [ -n "$verdict" ] && break
    kill -0 "$pid" 2>/dev/null || break
    sleep 0.1
  done
  # Kill like the OS would (no graceful quit) so "_b" journeys prove disk state.
  kill -9 "$pid" 2>/dev/null || true
  wait "$pid" 2>/dev/null || true
  if kill -0 "$pid" 2>/dev/null; then echo "desktop_e2e: Godot for $j survived the kill" >&2; exit 1; fi
  [ -n "$verdict" ] || verdict="LEGEND_E2E FAIL $j: no verdict (crash or timeout)"
  echo "$verdict"
  case "$verdict" in *" PASS "*) ;; *) fail=1; grep -E "LEGEND_E2E|SCRIPT ERROR|ERROR" "$log" | head -20 || true ;; esac
done
cp -r "$DATA"/godot/app_userdata/*/e2e/. "$OUT"/ 2>/dev/null || true
echo "screenshots: $(ls "$OUT"/*.png 2>/dev/null | wc -l) in $OUT"
[ $fail -eq 0 ] && echo "desktop_e2e: PASS" || { echo "desktop_e2e: FAIL"; exit 1; }
