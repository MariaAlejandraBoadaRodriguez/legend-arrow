#!/usr/bin/env bash
# Performance / memory / startup measurements on a connected Android device
# (or emulator) over adb. Needs the debug APK (it drives the fresh_install
# journey for load). Writes a Markdown report.
#
#   scripts/measure_device.sh build/android/legend-arrow-debug.apk [out_dir]
#
# For the owner's physical-device evidence: plug in a low/mid-tier phone with
# USB debugging on and run the command above. Emulator numbers are NOT device
# evidence (software GPU, host CPU) — the report says which one it was.
set -euo pipefail
APK="${1:?usage: measure_device.sh <debug apk> [out_dir]}"
OUT="${2:-build/device-measure}"
PKG="com.mariaalejandraboada.legendarrow"
RUNS="${COLD_START_RUNS:-5}"
mkdir -p "$OUT"
REPORT="$OUT/device_report.md"

adb wait-for-device
model="$(adb shell getprop ro.product.model | tr -d '\r')"
maker="$(adb shell getprop ro.product.manufacturer | tr -d '\r')"
android="$(adb shell getprop ro.build.version.release | tr -d '\r')"
abi="$(adb shell getprop ro.product.cpu.abi | tr -d '\r')"
is_emu="$(adb shell getprop ro.kernel.qemu | tr -d '\r')"
ram_kb="$(adb shell cat /proc/meminfo | awk '/MemTotal/ {print $2}')"
kind="physical device"; [[ "$is_emu" == "1" ]] && kind="EMULATOR (not device evidence)"

adb install -r -g "$APK" >/dev/null
ACTIVITY="$(adb shell cmd package resolve-activity --brief "$PKG" | tr -d '\r' | tail -1)"

# 1. Cold start (process killed before each launch).
starts=()
for i in $(seq 1 "$RUNS"); do
  adb shell am force-stop "$PKG"
  sleep 1
  t="$(adb shell am start -W -n "$ACTIVITY" | tr -d '\r' | awk -F': ' '/TotalTime/ {print $2}')"
  starts+=("${t:-NA}")
  sleep 3
done
adb shell am force-stop "$PKG"

# 2. Load: fresh install journey (tutorial, 2 puzzles, awakening) while sampling.
adb shell pm clear "$PKG" >/dev/null
adb shell "run-as $PKG sh -c 'mkdir -p files && echo fresh_install > files/e2e_journey.txt'"
adb logcat -c
adb shell am start -n "$ACTIVITY" >/dev/null
peak_pss=0; samples=0; died=""
start=$(date +%s)
LOAD_TIMEOUT_S="${LOAD_TIMEOUT_S:-360}"
while (( $(date +%s) - start < LOAD_TIMEOUT_S )); do
  pss="$(adb shell dumpsys meminfo "$PKG" 2>/dev/null | tr -d '\r' | awk '/TOTAL PSS:/ {print $3; exit} /^ *TOTAL / {print $2; exit}' || true)"
  if [[ "$pss" =~ ^[0-9]+$ ]] && (( pss > peak_pss )); then peak_pss=$pss; fi
  samples=$((samples + 1))
  if adb logcat -d 2>/dev/null | grep -qE "LEGEND_E2E (PASS|FAIL) fresh_install"; then break; fi
  if (( $(date +%s) - start > 20 )) && ! adb shell pidof "$PKG" >/dev/null 2>&1; then died="app process died"; break; fi
  sleep 2
done
# Never exit silently: every probe below tolerates "no match".
verdict="$(adb logcat -d 2>/dev/null | grep -oE "LEGEND_E2E (PASS|FAIL) fresh_install.*" | head -1 | tr -d '\r' || true)"
[[ -n "$verdict" ]] || verdict="no verdict (${died:-timeout after ${LOAD_TIMEOUT_S}s}); see logcat.txt"
frametimes="$(adb logcat -d 2>/dev/null | grep -oE "FRAMETIME [a-z]+ p50=[0-9.]+ p95=[0-9.]+ n=[0-9]+" | tr -d '\r' | sed 's/^FRAMETIME //' | paste -sd ';' - || true)"
gfx="$(adb shell dumpsys gfxinfo "$PKG" 2>/dev/null | tr -d '\r' | grep -E "Total frames rendered|Janky frames|50th percentile|90th percentile|99th percentile" || true)"
thermal="$(adb shell dumpsys thermalservice 2>/dev/null | tr -d '\r' | grep -E "Thermal Status|mValue" | head -5 || true)"
adb shell dumpsys meminfo "$PKG" > "$OUT/meminfo_end.txt" 2>/dev/null || true
adb logcat -d > "$OUT/logcat.txt" 2>/dev/null || true
adb shell am force-stop "$PKG"

{
  echo "# Device measurement — $maker $model"
  echo
  echo "| Item | Value |"
  echo "|---|---|"
  echo "| Kind | **$kind** |"
  echo "| Android | $android ($abi), RAM $((ram_kb / 1024)) MB |"
  echo "| Date | $(date -u +%Y-%m-%dT%H:%MZ) |"
  echo "| APK SHA-256 | $(sha256sum "$APK" | cut -c1-16)… |"
  echo "| Cold start TotalTime (ms), $RUNS runs | ${starts[*]} |"
  echo "| Load journey | ${verdict:-no verdict} |"
  echo "| Peak PSS during journey | $((peak_pss / 1024)) MB ($samples samples) |"
  echo "| In-game frame time, ms (fresh_install journey) | ${frametimes:-n/a} |"
  echo "| APK size | $(( $(stat -c %s "$APK") / 1048576 )) MB (debug, all test ABIs) |"
  echo
  echo "## gfxinfo"
  echo '```'; echo "${gfx:-(Godot renders to its own surface; HWUI frame stats may be empty)}"; echo '```'
  echo "## Thermal"
  echo '```'; echo "${thermal:-n/a}"; echo '```'
  echo
  echo "Budgets (spec §14, named 3 GB low-tier phone): launch to usable Home <= 5 s; puzzle frame p95 <= 16.7 ms;"
  echo "cinematic (awakening) p95 <= 33.3 ms on the low tier; PSS <= 300 MB in a puzzle, <= 400 MB at awakening peak;"
  echo "download <= 120 MB. am start TotalTime is time to first frame, a lower bound for 'usable Home'."
} > "$REPORT"
cat "$REPORT"
if [[ "$verdict" != *"PASS"* ]]; then
  echo "measure_device: load journey did not pass: $verdict" >&2
  grep -E "LEGEND_E2E|FATAL|AndroidRuntime|lowmemorykiller|ANR in|SCRIPT ERROR" "$OUT/logcat.txt" | tail -40 >&2 || true
  exit 1
fi
