#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2016,SC2034 # Sourced helpers, literal test strings, and variables used across files.
# Tests for launch_run.sh, in a throwaway workspace.
. "$(dirname "$0")/lib.sh"
L="$SCRIPTS/launch_run.sh"
WS="$TMP_ROOT/ws"
mkdir -p "$WS/docs/plans" "$TMP_ROOT/bin"
cd "$WS" || exit 1
printf 'XDG_CACHE_HOME=%s/.cache\nTZ=Asia/Dubai\nPYTHONPATH=$PYTHONPATH:/x\n' "$WS" >.env
COM=(--nohup --no-gpu --machine box --code none)
SESSION="vrltest$$"
CLEANUP_HOOK='tmux kill-session -t "$SESSION" 2>/dev/null; pkill -f "sleep 4[0-9][0-9]" 2>/dev/null'
count() { pgrep -f "$1" | wc -l | tr -d ' '; }
session_pid() { sed -n 's/.*PID \([0-9][0-9]*\).*/\1/p' "$1" | tail -n 1; }

test_kill_stops_compound_commands_nohup() {
	run bash "$L" --log logs/d/a.log --purpose 'd / a' "${COM[@]}" -- 'cd /tmp && sleep 401; echo after | cat; sleep 402 | cat'
	expect_rc 0 || return 1
	sleep 1
	[ "$(count 'sleep 40[12]')" -ge 1 ] || { echo "the run did not start"; return 1; }
	kill "$(session_pid logs/d/a.log)"
	sleep 3
	[ "$(count 'sleep 40[12]')" = 0 ] || { echo "processes survived the kill"; return 1; }
	tail -n 1 logs/d/a.log | grep -q 'exit code 143' || { tail -n 3 logs/d/a.log; return 1; }
}

test_closing_the_tmux_window_stops_the_run() {
	command -v tmux >/dev/null 2>&1 || { echo "skipped: no tmux"; return 0; }
	run bash "$L" --log logs/d/b.log --purpose 'd / b' --tmux "$SESSION" --new-session --no-gpu --machine box --code none -- 'sleep 403; sleep 404 | cat'
	expect_rc 0 || return 1
	sleep 1
	tmux kill-window -t "$SESSION:d/b"
	sleep 3
	[ "$(count 'sleep 40[34]')" = 0 ] || { echo "processes survived"; return 1; }
	tail -n 1 logs/d/b.log | grep -q 'exit code' || { tail -n 3 logs/d/b.log; return 1; }
}

test_header_and_footer() {
	run bash "$L" --log logs/d/c.log --purpose 'd / c: a test' "${COM[@]}" --wait 5 -- 'echo "it'"'"'s $CUDA_VISIBLE_DEVICES|$CUDA_DEVICE_ORDER|$PYTHONUNBUFFERED"; printf no-newline'
	expect_rc 0 && expect_out 'ended with exit code 0' || return 1
	id="$(sed -n 's/^# run-id: *//p' logs/d/c.log)"
	[ ${#id} = 12 ] || { echo "run-id: $id"; return 1; }
	grep -qx "# ---------- end $id ----------" logs/d/c.log || { cat logs/d/c.log; return 1; }
	grep -q "^it's |PCI_BUS_ID|1$" logs/d/c.log || { cat logs/d/c.log; return 1; }
	grep -Eq '^# started:   [0-9-]{10} [0-9:]{8} [+-][0-9]{2}:[0-9]{2}$' logs/d/c.log || { cat logs/d/c.log; return 1; }
	[ "$(ls -l logs/d/c.log | cut -c1-10)" = "-rw-------" ] || { ls -l logs/d/c.log; return 1; }
}

test_plan_form() {
	cat >docs/plans/2026-10-08-demo.md <<'PLAN'
# Plan
```bash run=baseline
echo "baseline run"
```
```bash run=treat
echo treat
```
PLAN
	sha="$( (sha256sum docs/plans/2026-10-08-demo.md 2>/dev/null || shasum -a 256 docs/plans/2026-10-08-demo.md) | cut -d' ' -f1)"
	run bash "$L" --plan docs/plans/2026-10-08-demo.md --run baseline --plan-sha256 "$sha" --log logs/demo/baseline.log "${COM[@]}" --wait 5
	expect_rc 0 && grep -q '^# command:   echo "baseline run"$' logs/demo/baseline.log && grep -q '^# plan: ' logs/demo/baseline.log || return 1
	run bash "$L" --plan docs/plans/2026-10-08-demo.md --run treat --plan-sha256 deadbeef --log logs/demo/t.log "${COM[@]}"; expect_rc 3 && expect_out "changed since it was approved" || return 1
	run bash "$L" --plan docs/plans/2026-10-08-demo.md --run nope --plan-sha256 "$sha" --log logs/demo/t.log "${COM[@]}"; expect_rc 3 || return 1
	run bash "$L" --plan docs/plans/2026-10-08-demo.md --run treat --plan-sha256 "$sha" --log logs/demo/t.log "${COM[@]}" -- 'echo extra'; expect_rc 2 || return 1
	cp docs/plans/2026-10-08-demo.md "$TMP_ROOT/outside.md"
	run bash "$L" --plan "$TMP_ROOT/outside.md" --run treat --plan-sha256 "$sha" --log logs/demo/t.log "${COM[@]}"; expect_rc 3 && expect_out "under docs/plans/"
}

test_refusals() {
	run bash "$L" --purpose p --log logs/r/t.log "${COM[@]}" -- 'CUDA_VISIBLE_DEVICES=0 python x.py'; expect_rc 3 || return 1
	run bash "$L" --purpose p --log logs/r/t.log "${COM[@]}" -- 'python x.py --hf hf_abcdefghijklmnopqrstuvwxyz123'; expect_rc 3 || return 1
	printf '#!/bin/sh\n' >"$TMP_ROOT/bin/sbatch"; chmod +x "$TMP_ROOT/bin/sbatch"
	PATH="$TMP_ROOT/bin:$PATH" run bash "$L" --purpose p --log logs/r/t.log "${COM[@]}" -- 'echo hi'; expect_rc 3 && expect_out Slurm || return 1
	run bash "$L" --purpose p --log logs/r/t.log --nohup --machine box --code none -- 'echo hi'; expect_rc 2 || return 1
	run bash "$L" --purpose p --log logs/r/t.log --nohup --no-gpu --code none -- 'echo hi'; expect_rc 2 || return 1
	run bash "$L" --purpose $'two\nlines' --log logs/r/t.log "${COM[@]}" -- 'echo hi'; expect_rc 2 || return 1
	run bash "$L" --purpose p --log logs/r/t.log --tmux 'bad:name' --no-gpu --machine box --code none -- 'echo hi'; expect_rc 2
}

test_no_second_copy_and_restart() {
	run bash "$L" --purpose 'd / long' --log logs/x/long.log "${COM[@]}" -- 'sleep 405'; expect_rc 0 || return 1
	run bash "$L" --purpose 'd / long' --log logs/x/long.log "${COM[@]}" -- 'sleep 405'; expect_rc 3 && expect_out "still alive" || return 1
	kill -9 "$(session_pid logs/x/long.log)"; pkill -9 -f 'sleep 405'; sleep 1
	run bash "$L" --purpose 'd / long' --log logs/x/long.log "${COM[@]}" -- 'echo again'; expect_rc 3 && expect_out "--restart" || return 1
	run bash "$L" --purpose 'd / long' --log logs/x/long.log "${COM[@]}" --restart --wait 5 -- 'echo again'; expect_rc 0 || return 1
	grep -q 'exit code unknown: closed by a restart' logs/x/long.log || { cat logs/x/long.log; return 1; }
}

test_finished_run_is_not_overwritten() {
	mkdir -p runs/f/r && touch runs/f/r/ckpt.pt
	run bash "$L" --purpose 'f / r' --log logs/f/r.log --outputs runs/f/r "${COM[@]}" --wait 5 -- 'echo done'
	run bash "$L" --purpose 'f / r' --log logs/f/r.log --outputs runs/f/r "${COM[@]}" -- 'echo again'; expect_rc 3 && expect_out "new run name" || return 1
	run bash "$L" --purpose 'f / r' --log logs/f/r.log --outputs runs/f/r "${COM[@]}" --resume --wait 5 -- 'echo resumed'; expect_rc 0
}

test_dirty_checkout_diff_rebuilds_it() {
	git init -q repo && (
		cd repo && git config user.name t && git config user.email t@t && git config commit.gpgsign false &&
			printf 'a\n' >tracked.txt && printf '\0\1bin' >blob.bin && git add . && git commit -qm init &&
			git config color.ui always && git config diff.noprefix true &&
			printf 'a\nb\n' >tracked.txt && printf '\0\2bin2' >blob.bin && mkdir -p newpkg/sub && printf 'new\n' >newpkg/sub/mod.py && printf 'x\n' >'space name.txt'
	)
	run bash "$L" --purpose 'd / dirty' --log logs/x/dirty.log --nohup --no-gpu --machine box --code repo -- 'echo hi'
	expect_rc 3 && expect_out "give --outputs" || return 1
	run bash "$L" --purpose 'd / dirty' --log logs/x/dirty.log --outputs runs/x/dirty --nohup --no-gpu --machine box --code repo -- 'echo hi'
	expect_rc 0 && [ -f runs/x/dirty/git_diff.patch ] || return 1
	[ "$(ls -l runs/x/dirty/git_diff.patch | cut -c1-10)" = "-rw-------" ] || return 1
	git clone -q repo "$TMP_ROOT/clone" && (cd "$TMP_ROOT/clone" && git apply "$WS/runs/x/dirty/git_diff.patch") &&
		diff -r -x .git repo "$TMP_ROOT/clone" >/dev/null || { echo "the diff does not rebuild the checkout"; return 1; }
}

test_help_through_stdin() {
	OUT="$(bash -s -- --help <"$L" 2>&1)"
	expect_out "Usage, from the workspace root"
}

run_tests
