#!/usr/bin/env bash
# Single verification entry point (spec §19). Exits nonzero if any check fails.
#   1. import the project headlessly and fail on script/parse errors
#   2. compile every project script
#   3. run every GUT test (unit, property, content, integration)
#   4. gate the JUnit report: no failures, no pending, no assertion-free tests,
#      no empty discovery, every test file reported
# Env: GODOT=/path/to/godot to skip the pinned download.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
REPORTS="$ROOT/build/reports"
mkdir -p "$REPORTS"
rm -f "$REPORTS"/junit.xml "$REPORTS"/*.log

GODOT="${GODOT:-$("$ROOT/scripts/install_godot.sh")}"
echo "== Godot: $("$GODOT" --version)"

fail_on_errors() {  # $1 = log file, $2 = step name
  if grep -nE "SCRIPT ERROR|Parse Error|Compile Error|Failed to load script|Invalid call|Cannot call" "$1"; then
    echo "!! $2: errors found in $1" >&2
    exit 1
  fi
}

echo "== [1/4] Import project"
"$GODOT" --headless --path "$ROOT" --import >"$REPORTS/import.log" 2>&1 || { cat "$REPORTS/import.log"; exit 1; }
fail_on_errors "$REPORTS/import.log" "import"

echo "== [2/4] Compile all scripts"
"$GODOT" --headless --path "$ROOT" -s res://tools/check_scripts.gd 2>&1 | tee "$REPORTS/check_scripts.log"
status=${PIPESTATUS[0]}
[[ $status -eq 0 ]] || { echo "!! script check failed ($status)" >&2; exit 1; }
fail_on_errors "$REPORTS/check_scripts.log" "script check"

echo "== [3/4] Run GUT tests"
set +e
"$GODOT" --headless --path "$ROOT" -s res://addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json >"$REPORTS/gut.log" 2>&1
gut_status=$?
set -e
tail -n 40 "$REPORTS/gut.log"
fail_on_errors "$REPORTS/gut.log" "tests"
# Reference cycles between RefCounted objects never free; catch them here.
if grep -nE "ObjectDB instances were leaked at exit|resources still in use at exit" "$REPORTS/gut.log"; then
  echo "!! tests: objects or resources leaked at exit (reference cycle?)" >&2
  exit 1
fi
[[ $gut_status -eq 0 ]] || { echo "!! GUT exited with $gut_status" >&2; exit 1; }

echo "== [4/4] Gate JUnit report"
mapfile -t test_scripts < <(cd "$ROOT" && find tests -name 'test_*.gd' | sort | sed 's|^|res://|')
python3 "$ROOT/scripts/check_junit.py" "$REPORTS/junit.xml" \
  --min-tests "${MIN_TESTS:-1}" --summary-json "$REPORTS/summary.json" \
  --expect-scripts "${test_scripts[@]}"

echo "== verify_all: PASS"
