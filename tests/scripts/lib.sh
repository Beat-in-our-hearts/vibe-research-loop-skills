# shellcheck disable=SC1091,SC2016,SC2034 # Sourced helpers, literal test strings, and variables used across files.
# Helpers for the script tests: a temp folder per test file, the fakes first on PATH, and checks.
# Source it from a *.test.sh file, define test_* functions, and end with `run_tests`.

set -u
SCRIPTS="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../skills/vrl-init-workspace/scripts" && pwd)"
FAKES="$(cd "$(dirname "${BASH_SOURCE[0]}")/fakes" && pwd)"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/vrl-tests.XXXXXX")"
TMP_ROOT="$(cd "$TMP_ROOT" && pwd -P)"
PASS=0 FAIL=0 OUT="" RC=0

# run <command...>: run it, keeping its output in OUT and its exit code in RC.
run() {
	OUT="$("$@" 2>&1)"
	RC=$?
}

# Each expectation that fails is reported and marks the test failed, even if later lines pass.
FAILED=0
expect_rc() { [ "$RC" = "$1" ] || { echo "expected exit code $1, got $RC; output: $OUT"; FAILED=1; return 1; }; }
expect_out() { case "$OUT" in *"$1"*) return 0 ;; esac; echo "expected output to contain: $1; output: $OUT"; FAILED=1; return 1; }
expect_no_out() { case "$OUT" in *"$1"*) echo "expected output not to contain: $1"; FAILED=1; return 1 ;; esac; }
expect() { "$@" || { echo "failed: $*"; FAILED=1; return 1; }; }

run_tests() {
	local t msg
	for t in $(declare -F | awk '{ print $3 }' | grep '^test_'); do
		msg="$( (set -u; FAILED=0; "$t"; rc=$?; [ "$rc" = 0 ] && rc=$FAILED; exit "$rc") 2>&1)"
		if [ $? -eq 0 ]; then
			PASS=$((PASS + 1))
			printf 'ok   %s\n' "$t"
		else
			FAIL=$((FAIL + 1))
			printf 'FAIL %s\n' "$t"
			printf '%s\n' "$msg" | sed 's/^/     /' | tail -n 30
		fi
	done
	cleanup_all
	printf '%s: %d passed, %d failed\n' "$(basename "$0")" "$PASS" "$FAIL"
	[ "$FAIL" = 0 ]
}

cleanup_all() {
	if [ -d "$TMP_ROOT/state" ] && [ -f "$TMP_ROOT/state/master" ]; then kill "$(cat "$TMP_ROOT/state/master")" 2>/dev/null; fi
	[ -z "${CLEANUP_HOOK:-}" ] || eval "$CLEANUP_HOOK"
	rm -rf "$TMP_ROOT"
}
