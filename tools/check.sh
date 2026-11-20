#!/usr/bin/env bash
# Headless verification gate. Run from anywhere: tools/check.sh [--quick]
#   import -> parse-check every script -> unit tests -> smoke run of the main scene
# Exits non-zero on the first failing stage. GODOT overrides the binary path.
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-$HOME/.local/share/godot/4.6/godot}"
LOG="$(mktemp -d)"
# Engine noise at shutdown that is present in the untouched course project too.
IGNORE='resources still in use at exit|ObjectDB instances leaked|at: cleanup|at: clear'
fail=0

stage() { printf '\n== %s\n' "$1"; }
errors_in() { grep -E 'ERROR|SCRIPT ERROR|Parse Error|Failed to load|Invalid (call|get|set|access)' "$1" | grep -vE "$IGNORE"; }

stage "import"
"$GODOT" --path . --headless --import >"$LOG/import.log" 2>&1
if errors_in "$LOG/import.log"; then fail=1; fi

stage "parse-check scripts"
"$GODOT" --path . --headless res://tools/parse_check.tscn >"$LOG/parse.log" 2>&1
rc=$?
grep -E '^(PARSEFAIL|PARSED)' "$LOG/parse.log"
if [ "$rc" -ne 0 ]; then errors_in "$LOG/parse.log" | head -40; fail=1; fi

stage "script size (limit 300 lines)"
git ls-files -co --exclude-standard '*.gd' | xargs wc -l | awk '$2 != "total" && $1 > 300 {print "OVER: " $1 " " $2}'

if [ "$fail" -ne 0 ]; then echo; echo "FAILED before tests"; exit 1; fi

stage "unit tests"
"$GODOT" --path . --headless res://tests/test_runner.tscn >"$LOG/tests.log" 2>&1
rc=$?
grep -E '^(PASS|FAIL|TESTS)' "$LOG/tests.log"
errors_in "$LOG/tests.log" && fail=1
[ "$rc" -ne 0 ] && fail=1

if [ "${1:-}" != "--quick" ]; then
	stage "smoke run (300 frames)"
	timeout 120 "$GODOT" --path . --headless --quit-after 300 >"$LOG/run.log" 2>&1
	rc=$?
	errors_in "$LOG/run.log" | sort | uniq -c | head -30 && fail=1
	[ "$rc" -ne 0 ] && { echo "smoke run exit code $rc"; fail=1; }
fi

echo
if [ "$fail" -ne 0 ]; then echo "FAILED (logs in $LOG)"; exit 1; fi
echo "OK"
