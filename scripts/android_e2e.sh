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
adb shell pm clear "$PKG" >/dev/null
ACTIVITY="$(adb shell cmd package resolve-activity --brief "$PKG" | tr -d '\r' | tail -1)"
echo "launch activity: $ACTIVITY"
[[ "$ACTIVITY" == "$PKG/"* ]] || { echo "android_e2e: launcher activity not found" >&2; exit 1; }

results=()
fail=0
for j in "${JOURNEYS[@]}"; do
  start=$(date +%s)
  # Trigger file in the app's private files dir (debuggable build: run-as).
  adb shell "run-as $PKG sh -c 'mkdir -p files && echo $j > files/e2e_journey.txt'"
  adb logcat -c
  rec=0
  if [[ "$j" == "fresh_install" ]]; then  # gameplay + awakening video
    adb shell rm -f /sdcard/legend_arrow_gameplay.mp4
    adb shell screenrecord --time-limit 180 --size 540x1200 --bit-rate 3000000 /sdcard/legend_arrow_gameplay.mp4 &
    rec=$!
    sleep 1
  fi
  adb shell am start -W -n "$ACTIVITY" >/dev/null
  verdict=""
  while (( $(date +%s) - start < TIMEOUT_S )); do
    verdict="$(adb logcat -d 2>/dev/null | grep -oE "LEGEND_E2E (PASS|FAIL) $j.*" | head -1 | tr -d '\r' || true)"
    [[ -n "$verdict" ]] && break
    if ! adb shell pidof "$PKG" >/dev/null 2>&1 && (( $(date +%s) - start > 20 )); then
      verdict="LEGEND_E2E FAIL $j: app process died"
      break
    fi
    sleep 2
  done
  [[ -n "$verdict" ]] || verdict="LEGEND_E2E FAIL $j: no verdict within ${TIMEOUT_S}s"
  adb exec-out screencap -p > "$OUT/screencap/$j.png" || true
  adb logcat -d > "$OUT/logcat/$j.txt" || true
  if (( rec )); then
    adb shell pkill -INT screenrecord || true
    wait "$rec" 2>/dev/null || true
    sleep 2
    adb pull /sdcard/legend_arrow_gameplay.mp4 "$OUT/legend_arrow_gameplay.mp4" >/dev/null 2>&1 || echo "android_e2e: no video recorded" >&2
  fi
  adb shell am force-stop "$PKG"
  secs=$(( $(date +%s) - start ))
  echo "$verdict (${secs}s)"
  results+=("$j|$verdict|$secs")
  case "$verdict" in
    *" PASS "*) ;;
    *) fail=1; grep -E "LEGEND_E2E|FATAL|AndroidRuntime|SCRIPT ERROR|USER ERROR" "$OUT/logcat/$j.txt" | head -30 || true ;;
  esac
done

# Cold-start smoke without a trigger: the app must come up and stay up.
adb logcat -c
adb shell am start -W -n "$ACTIVITY" | tr -d '\r' | grep -E "Status|TotalTime|WaitTime" | sed 's/^/cold start: /' || true
sleep 8
if adb shell pidof "$PKG" >/dev/null 2>&1 && ! adb logcat -d | grep -q "FATAL EXCEPTION"; then
  echo "LEGEND_E2E PASS cold_start_smoke"
  results+=("cold_start_smoke|LEGEND_E2E PASS cold_start_smoke|8")
else
  echo "LEGEND_E2E FAIL cold_start_smoke"
  results+=("cold_start_smoke|LEGEND_E2E FAIL cold_start_smoke: not running|8")
  fail=1
fi
adb exec-out screencap -p > "$OUT/screencap/cold_start.png" || true
adb logcat -d > "$OUT/logcat/cold_start.txt" || true
adb shell am force-stop "$PKG"

# In-app evidence (result files + viewport PNGs).
adb exec-out run-as "$PKG" tar -c -C files e2e 2>/dev/null | tar -x -C "$OUT/app" || echo "android_e2e: could not pull in-app evidence" >&2

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
