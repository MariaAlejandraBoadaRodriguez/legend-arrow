#!/usr/bin/env bash
# Save stress test (v0.2 API 26 investigation, docs/qa/SAVE_INVESTIGATION.md).
#
# Each iteration:
#   1. wipe the app's data (the failing scenario was "first launch after a
#      data clear");
#   2. launch journey save_kill: finish the next level while a thread inside
#      the app SIGKILLs the process after kill_ms (a random point during the
#      commit write, right after it, or during the in-progress saves of play;
#      every 5th iteration does not kill, as a control);
#   3. relaunch with journey save_verify: the save must hold what the results
#      screen showed (when it showed anything) and never lose earlier
#      committed progress.
#
#   TARGET=android scripts/save_stress.sh <apk> [out_dir] [iterations]
#   TARGET=desktop GODOT=... scripts/save_stress.sh - [out_dir] [iterations]
# SEED makes the kill plan reproducible. Exit 1 on any mismatch.
set -uo pipefail
cd "$(dirname "$0")/.."
APK="${1:--}"
OUT="${2:-build/save-stress}"
N="${3:-120}"
TARGET="${TARGET:-android}"
SEED="${SEED:-20261119}"
PKG="com.mariaalejandraboada.legendarrow"
RANDOM=$SEED
rm -rf "$OUT"; mkdir -p "$OUT/logs"

# --- target: android ----------------------------------------------------------
if [[ "$TARGET" == "android" ]]; then
  source "$(dirname "$0")/android_probe.sh"
  retry() { local n out; for n in 1 2 3 4; do out="$("$@" 2>&1)" && { [[ -n "$out" ]] && echo "$out"; return 0; }; echo "retry $n: $* -> ${out:-<no output>}" >&2; adb wait-for-device || true; sleep 3; done; return 1; }
  adb wait-for-device
  if [[ -n "${E2E_WM_SIZE:-}" ]]; then adb shell wm size "$E2E_WM_SIZE"; fi
  if [[ -n "${E2E_WM_DENSITY:-}" ]]; then adb shell wm density "$E2E_WM_DENSITY"; fi
  echo "device: Android $(adb shell getprop ro.build.version.release | tr -d '\r'), $(adb shell cat /proc/meminfo | awk '/MemTotal/ {print int($2/1024) " MB RAM"}'), /data: $(adb shell df /data | tail -1 | tr -s ' ')"
  adb install -r -g "$APK" >/dev/null
  ACTIVITY="$(adb shell cmd package resolve-activity --brief "$PKG" | tr -d '\r' | tail -1)"
  t_clear() {
    adb shell pm clear "$PKG" >/dev/null
    adb shell am force-stop "$PKG"
    sleep 2
    retry adb shell "run-as $PKG sh -c 'mkdir -p files'"
  }
  t_put() { retry adb shell "run-as $PKG sh -c 'echo $2 > files/$1'"; }   # file, one-line value (no spaces in tokens)
  t_rm() { adb shell "run-as $PKG sh -c 'rm -f files/$1'" || true; }
  t_run() {   # journey, timeout_s, log
    local j="$1" to="$2" log="$3" since start
    t_put e2e_journey.txt "$j"
    adb logcat -c >/dev/null 2>&1 || true
    since="$(retry adb shell "date +'%m-%d %H:%M:%S.000'" | tr -d '\r')"
    retry adb shell am start -n "$ACTIVITY" >/dev/null
    start=$(date +%s)
    sleep 2
    while (( $(date +%s) - start < to )); do
      adb logcat -d -T "$since" 2>/dev/null | grep -qE "LEGEND_E2E (PASS|FAIL) $j" && break
      adb shell pidof "$PKG" >/dev/null 2>&1 || { sleep 1; adb shell pidof "$PKG" >/dev/null 2>&1 || break; }
      sleep 1
    done
    adb logcat -d -T "$since" > "$log.full" 2>/dev/null || true
    grep -E "LEGEND_E2E|Game: save|has died|lowmemorykiller: Kill|SCRIPT ERROR" "$log.full" > "$log" || true
    adb shell am force-stop "$PKG" || true
  }
  t_df() { adb shell df /data 2>/dev/null | tail -1 | tr -s ' '; }
# --- target: desktop ----------------------------------------------------------
else
  GODOT="${GODOT:-godot}"
  DATA="$(mktemp -d)"; export XDG_DATA_HOME="$DATA"
  DISP=":$(( 90 + RANDOM % 100 ))"
  Xvfb "$DISP" -screen 0 720x1280x24 >/dev/null 2>&1 & XVFB=$!
  trap 'kill -9 $XVFB 2>/dev/null; rm -rf "$DATA"' EXIT
  export DISPLAY="$DISP"; sleep 1
  udir() { ls -d "$DATA"/godot/app_userdata/*/ 2>/dev/null | head -1; }
  t_clear() { rm -rf "$DATA/godot"; }
  t_put() { local d; d="$(udir)"; [[ -n "$d" ]] || { mkdir -p "$DATA/godot/app_userdata/Legend Arrow"; d="$(udir)"; }; echo "$2" > "$d/$1"; }
  t_rm() { local d; d="$(udir)"; [[ -n "$d" ]] && rm -f "$d/$1"; }
  t_run() {
    local j="$1" to="$2" log="$3" pid
    "$GODOT" --path . --rendering-driver opengl3 --audio-driver Dummy --resolution 720x1280 -- "--e2e=$j" > "$log.full" 2>&1 & pid=$!
    for _ in $(seq 1 $((to * 10))); do
      grep -qE "LEGEND_E2E (PASS|FAIL) $j" "$log.full" && break
      kill -0 "$pid" 2>/dev/null || break
      sleep 0.1
    done
    kill -9 "$pid" 2>/dev/null; wait "$pid" 2>/dev/null
    grep -E "LEGEND_E2E|Game: save|SCRIPT ERROR" "$log.full" > "$log" || true
    rm -f "$log.full"
  }
  t_df() { df -h "$DATA" | tail -1 | tr -s ' '; }
fi

# --- iterations -----------------------------------------------------------------
pass=0; fail=0; committed_unshown=0; controls=0; before_shown=0; after_shown=0; late=0; nodata=0
: > "$OUT/results.tsv"
for i in $(seq 1 "$N"); do
  r=$((RANDOM % 100))
  if (( i % 5 == 0 )); then kill_ms=-1; phase=last
  elif (( r < 40 )); then kill_ms=$((RANDOM % 300)); phase=last           # the commit write itself
  elif (( r < 65 )); then kill_ms=$((300 + RANDOM % 1200)); phase=last    # right after the save
  elif (( r < 82 )); then kill_ms=$((1500 + RANDOM % 2000)); phase=last   # results already on screen
  else kill_ms=$((RANDOM % 2500)); phase=play; fi                          # in-progress saves while playing
  t_clear
  t_put e2e_param.txt "i=$i kill_ms=$kill_ms phase=$phase legacy=${LEGACY:-0}"
  t_rm e2e_expect.txt
  t_run save_kill 90 "$OUT/logs/$i-kill.log"
  shown="$(grep -oE 'SHOWN level=[a-z_0-9]+ stars=[0-9]+ time_ms=[0-9]+' "$OUT/logs/$i-kill.log" | head -1 | sed 's/^SHOWN //')"
  kverdict="$(grep -oE 'LEGEND_E2E (PASS|FAIL) save_kill.*' "$OUT/logs/$i-kill.log" | head -1)"
  if grep -q "KILL_LATE" "$OUT/logs/$i-kill.log"; then late=$((late + 1)); fi
  if (( kill_ms < 0 )); then controls=$((controls + 1)); kind=control
  elif [[ -n "$shown" ]]; then after_shown=$((after_shown + 1)); kind=killed_after_shown
  elif grep -q "PLAN " "$OUT/logs/$i-kill.log"; then before_shown=$((before_shown + 1)); kind=killed_before_shown
  else nodata=$((nodata + 1)); kind=no_plan; fi
  # A control run must reach its own PASS; a killed run must at least have planned.
  if [[ "$kind" == control && "$kverdict" != *" PASS "* ]]; then
    fail=$((fail + 1)); echo -e "$i\t$kill_ms\t$phase\t$kind\tFAIL\tcontrol journey: ${kverdict:-no verdict}" | tee -a "$OUT/results.tsv"; continue
  fi
  if [[ "$kind" == no_plan ]]; then
    echo -e "$i\t$kill_ms\t$phase\t$kind\tSKIP\tapp never reached the plan (${kverdict:-no verdict})" | tee -a "$OUT/results.tsv"; continue
  fi
  # Always tell save_verify which level was played; stars/time only if shown.
  plan_level="$(grep -oE 'PLAN .* level=[a-z_0-9]+' "$OUT/logs/$i-kill.log" | head -1 | grep -oE 'level=[a-z_0-9]+')"
  if [[ -n "$shown" ]]; then t_put e2e_expect.txt "$shown"; else t_put e2e_expect.txt "$plan_level"; fi
  t_run save_verify 60 "$OUT/logs/$i-verify.log"
  v="$(grep -oE 'LEGEND_E2E (PASS|FAIL) save_verify.*' "$OUT/logs/$i-verify.log" | head -1)"
  detail="$(grep -oE 'VERIFY .*' "$OUT/logs/$i-verify.log" | head -1)"
  if [[ "$v" == *" PASS "* ]]; then pass=$((pass + 1)); st=PASS; else fail=$((fail + 1)); st=FAIL; fi
  if grep -q "COMMITTED yes" "$OUT/logs/$i-verify.log" && [[ "$kind" == killed_before_shown ]]; then committed_unshown=$((committed_unshown + 1)); fi
  echo -e "$i\t$kill_ms\t$phase\t$kind\t$st\t${shown:--}\t$detail" >> "$OUT/results.tsv"
  if [[ "$st" == FAIL ]]; then
    echo "iteration $i FAIL ($kind, kill_ms=$kill_ms): ${v:-no verdict} | $detail"
    if [[ "$TARGET" == android ]]; then
      { echo "== iteration $i: kill run system lines"; probe_system_lines "$OUT/logs/$i-kill.log.full"
        echo "== verify run system lines"; probe_system_lines "$OUT/logs/$i-verify.log.full"; probe_data_dir; } | tee "$OUT/logs/$i-probe.txt"
    fi
  else
    rm -f "$OUT/logs/$i-kill.log.full" "$OUT/logs/$i-verify.log.full"
  fi
  if (( i % 10 == 0 )); then echo "after $i: pass=$pass fail=$fail | df: $(t_df)"; fi
done

{
  echo "# Save stress — $TARGET, $N iterations, seed $SEED, save code: $([[ "${LEGACY:-0}" == 1 ]] && echo 'OLD (pre-fix write path)' || echo 'NEW (verified write + retry)')"
  echo
  echo "| Measure | Count |"
  echo "|---|---|"
  echo "| Verified PASS | $pass |"
  echo "| Verified FAIL (save behind what was shown, or earlier progress lost) | $fail |"
  echo "| Control runs (no kill: plain first launch after a data clear) | $controls |"
  echo "| Killed before the results screen showed | $before_shown |"
  echo "| ... of which the completion was already committed (killed between save and screen) | $committed_unshown |"
  echo "| Killed after the results screen showed | $after_shown |"
  echo "| Kill planned but the app outlived it (KILL_LATE) | $late |"
  echo "| Skipped (app never reached the plan) | $nodata |"
} | tee "$OUT/summary.md"
(( fail == 0 )) && echo "save_stress: PASS" || { echo "save_stress: FAIL"; exit 1; }
