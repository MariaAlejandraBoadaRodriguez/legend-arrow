#!/usr/bin/env bash
# Real disk-full regression check (v0.2 save investigation,
# docs/qa/SAVE_INVESTIGATION.md). Mounts a 2 MB tmpfs, writes a good save,
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
$SUDO mount -t tmpfs -o size=2m,mode=1777 tmpfs "$MNT"
trap '$SUDO umount "$MNT" 2>/dev/null || true; rmdir "$MNT" 2>/dev/null || true' EXIT

run() { "$GODOT" --headless --path . -s res://tools/enospc_check.gd -- "$MNT" "$1" 2>/dev/null | grep '^RESULT' || true; }
old="$(run old)"; new="$(run new)"
echo "baseline: $old"
echo "fixed:    $new"
fail=0
[[ "$new" == *"second_write_err=0 "* ]] && { echo "FAIL new code reported success on a full disk"; fail=1; }
[[ "$new" == *"main_readable=true"* ]] || { echo "FAIL new code left main unreadable"; fail=1; }
[[ "$new" == *"load_source=0 recovered=false"* ]] || { echo "FAIL new code did not load the previous save as main"; fail=1; }
[[ "$new" == *"has_forest_drake=true"* ]] || { echo "FAIL new code lost the previous progress"; fail=1; }
# The baseline must still fail, or this check could not detect a regression.
[[ "$old" == *"main_readable=false"* ]] || { echo "FAIL baseline no longer shows the defect: the check is not discriminating"; fail=1; }
(( fail == 0 )) && echo "enospc_check: PASS" || { echo "enospc_check: FAIL"; exit 1; }
