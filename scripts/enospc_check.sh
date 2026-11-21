#!/usr/bin/env bash
# Real disk-full regression check (0.2.1 save hardening, RELEASE_CHECKLIST
# item 18; docs/qa/SAVE_INVESTIGATION.md). Mounts a 24 MB tmpfs (above the 10 MB low-space threshold once freed), writes a good save,
# fills the filesystem, then writes a larger save so the real write hits
# ENOSPC. The new save code must report the failure, keep the previous save
# readable as main, and load it without a recovery message. The pre-fix code
# is run as the baseline and must still show the defect (proves the check
# can fail). Needs sudo for the mount (CI runners have it).
#   GODOT=/path/to/godot scripts/enospc_check.sh
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-$(scripts/install_godot.sh)}"
MNT="$(mktemp -d)"
SUDO=""; [[ "$(id -u)" == 0 ]] || SUDO=sudo
$SUDO mount -t tmpfs -o size=24m,mode=1777 tmpfs "$MNT"
trap '$SUDO umount "$MNT" 2>/dev/null || true; rmdir "$MNT" 2>/dev/null || true' EXIT

run() { "$GODOT" --headless --path . -s res://tools/enospc_check.gd -- "$MNT" "$1" 2>/dev/null | grep -E '^(RESULT|RECOVERY)' || true; }
old="$(run old)"; out="$(run new)"
new="$(grep '^RESULT' <<<"$out" || true)"; rec="$(grep '^RECOVERY' <<<"$out" || true)"
echo "baseline: $old"
echo "fixed:    $new"
echo "recovery: $rec"
fail=0
[[ "$new" == *"second_write_err=0 "* ]] && { echo "FAIL new code reported success on a full disk"; fail=1; }
[[ "$new" == *"main_readable=true"* ]] || { echo "FAIL new code left main unreadable"; fail=1; }
[[ "$new" == *"load_source=0 recovered=false"* ]] || { echo "FAIL new code did not load the previous save as main"; fail=1; }
[[ "$new" == *"has_forest_drake=true"* ]] || { echo "FAIL new code lost the previous progress"; fail=1; }
[[ "$new" == *"storage_message=true"* ]] || { echo "FAIL the storage-full message would not show"; fail=1; }
[[ "$rec" == *"write_err=0 has_big=true storage_message=false"* ]] || { echo "FAIL no recovery after space was freed"; fail=1; }
# The baseline must still fail, or this check could not detect a regression.
[[ "$old" == *"main_readable=false"* ]] || { echo "FAIL baseline no longer shows the defect: the check is not discriminating"; fail=1; }
(( fail == 0 )) && echo "enospc_check: PASS" || { echo "enospc_check: FAIL"; exit 1; }
