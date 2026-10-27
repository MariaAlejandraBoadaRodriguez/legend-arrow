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
JOURNEYS=(${E2E_JOURNEYS:-fresh_install partial_a partial_b blocked_undo hint_ad awakening_replay settings_a settings_b})
TIMEOUT_S="${E2E_TIMEOUT_S:-300}"
rm -rf "$OUT"
mkdir -p "$OUT/app" "$OUT/screencap" "$OUT/logcat"

adb wait-for-device
adb shell getprop ro.build.version.release | sed 's/^/android: /'
adb shell wm size | sed 's/^/display: /'
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

# `pm clear` force-stops the package asynchronously; a launch issued right
# after it can be killed (CI runs 40578441238, 40576384695: first launch after
# a clear died with no app output). Wait until the clear has settled.
clear_data() {
  adb shell pm clear "$PKG" >/dev/null
  adb shell am force-stop "$PKG"
  for _ in $(seq 1 15); do
    adb shell "run-as $PKG sh -c 'mkdir -p files && test -w files'" >/dev/null 2>&1 && break
    sleep 1
  done
  sleep 2
}

results=()
fail=0
clear_data
for j in "${JOURNEYS[@]}"; do
  start=$(date +%s)
  # Trigger file in the app's private files dir (debuggable build: run-as).
  adb shell "run-as $PKG sh -c 'mkdir -p files && echo $j > files/e2e_journey.txt'"
  adb logcat -c
  adb shell am start -W -n "$ACTIVITY" >/dev/null
  verdict=""
  while (( $(date +%s) - start < TIMEOUT_S )); do
    verdict="$(adb logcat -d 2>/dev/null | grep -oE "LEGEND_E2E (PASS|FAIL) $j.*" | head -1 | tr -d '\r' || true)"
    [[ -n "$verdict" ]] && break
    if (( $(date +%s) - start > 60 )) && app_dead; then
      verdict="LEGEND_E2E FAIL $j: app process died"
      break
    fi
    sleep 2
  done
  [[ -n "$verdict" ]] || verdict="LEGEND_E2E FAIL $j: no verdict within ${TIMEOUT_S}s"
  adb exec-out screencap -p > "$OUT/screencap/$j.png" || true
  adb logcat -d > "$OUT/logcat/$j.txt" || true
  adb shell am force-stop "$PKG"
  secs=$(( $(date +%s) - start ))
  echo "$verdict (${secs}s)"
  results+=("$j|$verdict|$secs")
  case "$verdict" in
    *" PASS "*) ;;
    *) fail=1
       # Case-insensitive: native crashes log as "F libc : Fatal signal …".
       echo "---- $j: crash / kill / app lines from logcat ----"
       grep -iE "LEGEND_E2E|fatal|crash|tombstone|backtrace|SIGSEGV|SIGABRT|ANR in|has died|am_kill|lowmemorykiller|Force stopping|SCRIPT ERROR|USER ERROR|godot" \
         "$OUT/logcat/$j.txt" | grep -v "GodotPluginRegistry: Registering" | tail -80 || true
       echo "---- end $j ----" ;;
  esac
done

# In-app evidence (result files + viewport PNGs).
adb exec-out run-as "$PKG" tar -c -C files e2e 2>/dev/null | tar -x -C "$OUT/app" || echo "android_e2e: could not pull in-app evidence" >&2

# First-launch smoke without a trigger, on cleared data: the real product
# path, including the real UMP + Google Mobile Ads start-up with Google's
# test IDs (no live ads, nothing is clicked). The app must come up and stay up.
clear_data
adb logcat -c
adb shell am start -W -n "$ACTIVITY" | tr -d '\r' | grep -E "Status|TotalTime|WaitTime" | sed 's/^/cold start: /' || true
sleep 30
if ! app_dead && ! adb logcat -d | grep -qiE "FATAL EXCEPTION|Fatal signal"; then
  echo "LEGEND_E2E PASS cold_start_smoke"
  results+=("cold_start_smoke|LEGEND_E2E PASS cold_start_smoke|8")
else
  echo "LEGEND_E2E FAIL cold_start_smoke"
  adb logcat -d | grep -iE "fatal|crash|tombstone|backtrace|SIGSEGV|SIGABRT|ANR in|has died|am_kill|godot|Ads|UserMessaging" | tail -80 || true
  results+=("cold_start_smoke|LEGEND_E2E FAIL cold_start_smoke: not running|8")
  fail=1
fi
adb exec-out screencap -p > "$OUT/screencap/cold_start.png" || true
adb logcat -d > "$OUT/logcat/cold_start.txt" || true
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
