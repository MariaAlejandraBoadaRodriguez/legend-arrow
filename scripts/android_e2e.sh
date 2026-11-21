#!/usr/bin/env bash
# Android end-to-end suite on a running emulator/device (adb). Installs the
# debug APK on a clean data dir and runs the DeviceE2E journeys inside the real
# app, one launch per journey; "_a" -> "_b" pairs are separated by
# `am force-stop` (process killed, no graceful quit). Ads are the in-app mock:
# no live ad request is made.
#
#   scripts/android_e2e.sh build/android/legend-arrow-debug.apk [out_dir]
#
# Evidence in out_dir: per-journey logcat, in-app result files and PNGs, a
# system screencap per journey and junit.xml. Exits non-zero on any failure.
set -euo pipefail
APK="${1:?usage: android_e2e.sh <apk> [out_dir]}"
OUT="${2:-build/e2e-android}"
PKG="com.mariaalejandraboada.legendarrow"
JOURNEYS=(${E2E_JOURNEYS:-fresh_install partial_a partial_b blocked_undo hint_ad awakening_replay settings_a settings_b replay_times background_resume rotate world_unlock memory_transitions})
TIMEOUT_S="${E2E_TIMEOUT_S:-300}"
rm -rf "$OUT"
mkdir -p "$OUT/app" "$OUT/screencap" "$OUT/logcat"

adb wait-for-device
adb shell getprop ro.build.version.release | sed 's/^/android: /'
# Profile override (v0.2 §8/§9.3): exact screen size and density.
if [[ -n "${E2E_WM_SIZE:-}" ]]; then adb shell wm size "$E2E_WM_SIZE"; fi
if [[ -n "${E2E_WM_DENSITY:-}" ]]; then adb shell wm density "$E2E_WM_DENSITY"; fi
adb shell wm size | sed 's/^/display: /'
adb shell wm density | sed 's/^/density: /'
adb install -r -g "$APK" >/dev/null
ACTIVITY="$(adb shell cmd package resolve-activity --brief "$PKG" | tr -d '\r' | tail -1)"
echo "launch activity: $ACTIVITY"
[[ "$ACTIVITY" == "$PKG/"* ]] || { echo "android_e2e: launcher activity not found" >&2; exit 1; }

# A single `pidof` miss is not death: adb on CI emulators drops calls
# ("device offline", "protocol fault"). Require 3 consecutive misses over a
# working adb link before killing the journey (CI run 40561130695 force-stopped
# a healthy, slowly starting app on one miss).
app_dead() {
  local misses=0
  for _ in 1 2 3; do
    adb shell echo ok 2>/dev/null | grep -q ok || return 1   # adb itself unhealthy: unknown, not dead
    if adb shell pidof "$PKG" >/dev/null 2>&1; then return 1; fi
    misses=$((misses + 1))
    sleep 2
  done
  (( misses == 3 ))
}

# Fresh app data before a journey. Not `pm clear`: on CI emulators it took
# effect up to ~25 s after the command returned (run 44934453130, API 34: the
# clear killed the app and wiped its data 18 s into the first journey; the
# 0.2.0 API 26 "save missing right after install + pm clear" had the same
# shape). Instead: stop the app, wait until its process is gone, delete the
# app's own data with run-as, and check it is empty. Every step is
# synchronous, so nothing lands later in the middle of a journey.
clear_data() {
  adb shell am force-stop "$PKG"
  for _ in $(seq 1 20); do
    adb shell pidof "$PKG" >/dev/null 2>&1 || break
    sleep 1
  done
  if adb shell pidof "$PKG" >/dev/null 2>&1; then
    echo "android_e2e: $PKG still running after force-stop" >&2; exit 1
  fi
  retry adb shell "run-as $PKG sh -c 'rm -rf files cache code_cache no_backup shared_prefs databases app_* && mkdir files'"
  local left
  left="$(adb shell "run-as $PKG sh -c 'ls -A files shared_prefs databases 2>/dev/null'" | tr -d '\r' || true)"
  [[ -z "$left" ]] || { echo "android_e2e: app data not empty after reset: $left" >&2; exit 1; }
}

# Device actions a journey asks for with "LEGEND_E2E ACTION <name>"; the
# journey waits until files/e2e_action_done exists.
do_action() {
  case "$1" in
    home)     # background the app, wait, bring the same task back
      adb shell input keyevent KEYCODE_HOME
      sleep 8
      adb shell am start -n "$ACTIVITY" >/dev/null ;;
    rotate)   # force landscape for a few seconds, then portrait again
      adb shell settings put system accelerometer_rotation 0
      adb shell settings put system user_rotation 1
      sleep 4
      adb shell settings put system user_rotation 0
      sleep 2 ;;
  esac
  retry adb shell "run-as $PKG sh -c 'touch files/e2e_action_done'"
  echo "action $1 done"
}

# `logcat -c` fails on some images (API 26: "failed to clear the 'main'
# log", CI run 44458808071), so each journey reads logcat from a device-side
# start time instead of relying on a clear.
mark_log() {
  adb logcat -c >/dev/null 2>&1 || true
  SINCE="$(retry adb shell "date +'%m-%d %H:%M:%S.000'" | tr -d '\r')"
}
logs() { adb logcat -d -T "$SINCE" 2>/dev/null || true; }

retry() {
  local n
  for n in 1 2 3 4; do
    "$@" && return 0
    echo "retry $n: $*" >&2
    adb wait-for-device || true
    sleep 3
  done
  return 1
}

results=()
fail=0
clear_data
for j in "${JOURNEYS[@]}"; do
  # E2E_CLEAR_EACH=1: wipe app data before every journey (reproduces
  # "first launch right after a data clear", e.g. E2E_JOURNEYS repeated).
  if [[ "${E2E_CLEAR_EACH:-0}" == "1" ]]; then clear_data; fi
  start=$(date +%s)
  # Trigger file in the app's private files dir (debuggable build: run-as).
  # adb drops calls on loaded CI emulators; one failed call must not end the
  # whole run under `set -e` (run 44466657570 stopped after its first journey).
  retry adb shell "run-as $PKG sh -c 'mkdir -p files && echo $j > files/e2e_journey.txt'"
  mark_log
  retry adb shell am start -W -n "$ACTIVITY" >/dev/null
  verdict=""
  done_actions=0
  while (( $(date +%s) - start < TIMEOUT_S )); do
    actions=( $(logs | grep -oE "LEGEND_E2E ACTION [a-z]+" | awk '{print $3}' | tr -d '\r' || true) )
    while (( done_actions < ${#actions[@]} )); do
      do_action "${actions[$done_actions]}"
      done_actions=$((done_actions + 1))
    done
    verdict="$(logs | grep -oE "LEGEND_E2E (PASS|FAIL) $j.*" | head -1 | tr -d '\r' || true)"
    [[ -n "$verdict" ]] && break
    if (( $(date +%s) - start > 60 )) && app_dead; then
      verdict="LEGEND_E2E FAIL $j: app process died"
      break
    fi
    sleep 2
  done
  [[ -n "$verdict" ]] || verdict="LEGEND_E2E FAIL $j: no verdict within ${TIMEOUT_S}s"
  adb exec-out screencap -p > "$OUT/screencap/$j.png" || true
  logs > "$OUT/logcat/$j.txt"
  adb shell am force-stop "$PKG" || true
  secs=$(( $(date +%s) - start ))
  echo "$verdict (${secs}s)"
  grep -oE "LEGEND_E2E TAPSTATS.*" "$OUT/logcat/$j.txt" | tr -d '\r' | head -1 || true
  results+=("$j|$verdict|$secs")
  case "$verdict" in
    *" PASS "*) ;;
    *) fail=1
       # Case-insensitive: native crashes log as "F libc : Fatal signal …".
       # Two lists, so system log spam cannot push the app's own lines out.
       echo "---- $j: app lines from logcat (pid of $PKG, godot, LEGEND_E2E) ----"
       grep -E "LEGEND_E2E| godot |$PKG|SCRIPT ERROR|USER ERROR" "$OUT/logcat/$j.txt" \
         | grep -vE "GodotPluginRegistry: Registering|GL_MAX_FRAGMENT|Program linking|_display_error_with_code|_compile_specialization" | tail -60 || true
       echo "---- $j: system crash / kill lines from logcat ----"
       grep -iE "fatal|tombstone|backtrace|SIGSEGV|SIGABRT|ANR in|has died|am_kill|lowmemorykiller: Kill|lmkd|Killing|Force stopping|installd|PackageManager: (Install|Package|Update)" \
         "$OUT/logcat/$j.txt" | grep -vE "NamespaceManager|crashrecovery|Scheduling restart" | tail -40 || true
       # Storage and memory at the first failure (what filled /data, who uses RAM).
       if [[ -z "${_space_dumped:-}" ]]; then _space_dumped=1; "$(dirname "$0")/device_space.sh" "at-failure-$j" 0 || true; fi
       echo "---- $j: in-app step log ----"
       adb shell "run-as $PKG cat files/e2e/result_$j.txt" 2>/dev/null | tr -d '\r' | tail -60 || true
       echo "---- end $j ----" ;;
  esac
done

# In-app evidence (result files + viewport PNGs).
adb exec-out run-as "$PKG" tar -c -C files e2e 2>/dev/null | tar -x -C "$OUT/app" || echo "android_e2e: could not pull in-app evidence" >&2

# First-launch smoke without a trigger, on cleared data: the real product
# path, including the real UMP + Google Mobile Ads start-up with Google's
# test IDs (no live ads, nothing is clicked). The app must come up and stay up.
clear_data
mark_log
adb shell am start -W -n "$ACTIVITY" | tr -d '\r' | grep -E "Status|TotalTime|WaitTime" | sed 's/^/cold start: /' || true
sleep 30
if ! app_dead && ! logs | grep -qiE "FATAL EXCEPTION|Fatal signal"; then
  echo "LEGEND_E2E PASS cold_start_smoke"
  results+=("cold_start_smoke|LEGEND_E2E PASS cold_start_smoke|8")
else
  echo "LEGEND_E2E FAIL cold_start_smoke"
  logs | grep -iE "fatal|crash|tombstone|backtrace|SIGSEGV|SIGABRT|ANR in|has died|am_kill|godot|Ads|UserMessaging" | tail -80 || true
  results+=("cold_start_smoke|LEGEND_E2E FAIL cold_start_smoke: not running|8")
  fail=1
fi
adb exec-out screencap -p > "$OUT/screencap/cold_start.png" || true
logs > "$OUT/logcat/cold_start.txt"
adb shell am force-stop "$PKG"


# JUnit for the report gate / artifacts.
{
  n=${#results[@]}; failures=0
  for r in "${results[@]}"; do [[ "$r" == *"PASS"* ]] || failures=$((failures+1)); done
  echo '<?xml version="1.0" encoding="UTF-8"?>'
  echo "<testsuites><testsuite name=\"android_e2e\" tests=\"$n\" failures=\"$failures\">"
  for r in "${results[@]}"; do
    IFS='|' read -r name verdict secs <<<"$r"
    echo "  <testcase classname=\"android_e2e\" name=\"$name\" time=\"$secs\">"
    [[ "$verdict" == "LEGEND_E2E PASS"* ]] || \
      echo "    <failure message=\"$(echo "$verdict" | sed 's/[<>&\"]/_/g')\"/>"
    echo "  </testcase>"
  done
  echo "</testsuite></testsuites>"
} > "$OUT/junit.xml"

echo "screenshots: $(ls "$OUT"/app/e2e/*.png 2>/dev/null | wc -l) in-app, $(ls "$OUT"/screencap/*.png | wc -l) screencap"
if (( fail )); then echo "android_e2e: FAIL"; exit 1; fi
echo "android_e2e: PASS"
