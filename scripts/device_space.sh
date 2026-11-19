#!/usr/bin/env bash
# Prints the emulator/device /data usage and fails if less than the minimum
# is free. CI runs it before and after the emulator journeys: a full /data
# ("installd: Failed to free up ... on /data") made app writes fail on the
# API 26 emulator (docs/qa/SAVE_INVESTIGATION.md).
# Usage: scripts/device_space.sh <label> [min_free_mb=1024]
set -uo pipefail
label="${1:-check}"
min_mb="${2:-1024}"
echo "---- df -h /data ($label) ----"
adb shell df -h /data
line="$(adb shell df -k /data | tr -d '\r' | tail -1)"
avail_kb="$(awk '{print $4}' <<<"$line")"
if ! [[ "$avail_kb" =~ ^[0-9]+$ ]]; then
  echo "device_space: FAIL ($label): could not read free space on /data from: $line"
  exit 1
fi
avail_mb=$((avail_kb / 1024))
if (( avail_mb < min_mb )); then
  echo "device_space: FAIL ($label): only ${avail_mb} MB free on /data, need at least ${min_mb} MB. The emulator's data partition is (nearly) full; app saves would fail. Not a game failure."
  exit 1
fi
echo "device_space: OK ($label): ${avail_mb} MB free on /data (minimum ${min_mb} MB)"
