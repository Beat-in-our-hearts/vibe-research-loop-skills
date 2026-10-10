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
COM2=(--nohup --no-gpu --machine box)
SESSION="vrltest$$"
# Sleep lengths unique to this run, so that no other test run's processes match.
U=$((1000 + $$ % 8000))
CLEANUP_HOOK='tmux kill-session -t "$SESSION" 2>/dev/null; for n in 1 2 3 4 5 6 7 8; do pkill -f "^sleep $U$n\$" 2>/dev/null; done'
count() { pgrep -f "^sleep $U$1\$" | wc -l | tr -d ' '; }
session_pid() { sed -n 's/.*PID \([0-9][0-9]*\).*/\1/p' "$1" | tail -n 1; }

test_kill_stops_compound_commands_nohup() {
	run bash "$L" --log logs/d/a.log --purpose 'd / a' "${COM[@]}" -- "cd /tmp && sleep ${U}1; echo after | cat; sleep ${U}2 | cat"
	expect_rc 0 || return 1
	sleep 1
	expect [ "$(count 1)" -ge 1 ] || return 1
	kill "$(session_pid logs/d/a.log)"
	sleep 3
	expect [ "$(count 1)" = 0 ] && expect [ "$(count 2)" = 0 ]
	expect grep -q 'exit code 143' logs/d/a.log
}

test_closing_the_tmux_window_stops_the_run() {
	command -v tmux >/dev/null 2>&1 || { echo "skipped: no tmux"; return 0; }
	run bash "$L" --log logs/d/b.log --purpose 'd / b' --tmux "$SESSION" --new-session --no-gpu --machine box --code none -- "sleep ${U}3; sleep ${U}3 | cat"
	expect_rc 0 || return 1
	sleep 1
	tmux kill-window -t "$SESSION:d/b"
	sleep 3
	expect [ "$(count 3)" = 0 ] && expect grep -q 'exit code' logs/d/b.log
}

test_a_command_that_ignores_term_is_killed() {
	run bash "$L" --log logs/d/t.log --purpose 'd / t' "${COM[@]}" -- "trap '' TERM; sleep ${U}4; true"
	expect_rc 0 || return 1
	sleep 1
	kill "$(session_pid logs/d/t.log)"
	sleep 14
	expect [ "$(count 4)" = 0 ] && expect grep -q 'exit code' logs/d/t.log
}

test_header_and_footer() {
	run bash "$L" --log logs/d/c.log --purpose 'd / c: a test' "${COM[@]}" --wait 6 -- 'echo "it'"'"'s $CUDA_VISIBLE_DEVICES|$CUDA_DEVICE_ORDER|$PYTHONUNBUFFERED"; printf no-newline'
	expect_rc 0 && expect_out 'ended with exit code 0' || return 1
	id="$(sed -n 's/^# run-id: *//p' logs/d/c.log)"
	expect [ ${#id} = 12 ]
	expect grep -qx "# ---------- end $id ----------" logs/d/c.log
	expect grep -q "^it's |PCI_BUS_ID|1$" logs/d/c.log
	expect grep -Eq '^# started:   [0-9-]{10} [0-9:]{8} [+-][0-9]{2}:[0-9]{2}$' logs/d/c.log
	expect [ "$(ls -l logs/d/c.log | cut -c1-10)" = "-rw-------" ]
	set -- "${TMPDIR:-/tmp}"/vrl-run-"$id".*
	expect [ ! -e "$1" ]
}

sha() { (sha256sum "$1" 2>/dev/null || shasum -a 256 "$1") | cut -d' ' -f1; }

test_plan_form() {
	git init -q prepo && (cd prepo && git config user.name t && git config user.email t@t && git config commit.gpgsign false && echo v1 >train.py && git add . && git commit -qm init)
	pin="$(bash "$L" --pin prepo)"
	expect [ "${pin%% diff=*}" != "$pin" ] && expect_no_out "x"
	printf '# Plan\n```bash run=baseline gpus=0 %s env=lab\ncd prepo && echo "baseline run in $VRL_OUTPUTS"\n```\n~~~sh run=tilde gpus=0 code=none\necho tilde\n~~~\n````bash run=nested gpus=0 code=none\ncat <<'"'"'X'"'"'\n```\nX\necho still inside\n````\n```bash run=open gpus=0 code=none\necho never closed\n' "$pin" >docs/plans/2026-10-08-demo.md
	s="$(sha docs/plans/2026-10-08-demo.md)"
	run bash "$L" --plan docs/plans/2026-10-08-demo.md --run baseline --plan-sha256 "$s" "${COM2[@]}" --wait 6
	expect_rc 0 && expect_out "started   " && expect_out "log       logs/2026-10-08-demo/baseline.log"
	expect grep -q "^baseline run in $WS/runs/2026-10-08-demo/baseline$" logs/2026-10-08-demo/baseline.log
	expect grep -q '^# plan: ' logs/2026-10-08-demo/baseline.log && expect grep -q 'Python env lab' logs/2026-10-08-demo/baseline.log
	run bash "$L" --plan docs/plans/2026-10-08-demo.md --run tilde --plan-sha256 "$s" "${COM2[@]}" --wait 6; expect_rc 0
	run bash "$L" --plan docs/plans/2026-10-08-demo.md --run nested --plan-sha256 "$s" "${COM2[@]}" --wait 6
	expect_rc 0 && expect grep -q 'still inside' logs/2026-10-08-demo/nested.log
	run bash "$L" --plan docs/plans/2026-10-08-demo.md --run open --plan-sha256 "$s" "${COM2[@]}"; expect_rc 3 && expect_out "never closes"
	run bash "$L" --plan docs/plans/2026-10-08-demo.md --run baseline --plan-sha256 deadbeef "${COM2[@]}"
	expect_rc 3 && expect_out "does not have the SHA-256" && expect_no_out "$s"
	run bash "$L" --plan docs/plans/2026-10-08-demo.md --run baseline --plan-sha256 "$s" "${COM2[@]}" --log logs/elsewhere.log; expect_rc 2
	run bash "$L" --plan docs/plans/2026-10-08-demo.md --run tilde --plan-sha256 "$s" --nohup --gpus 0 --machine box; expect_rc 3 && expect_out "no GPU"
	run bash "$L" --plan '' --purpose p --log logs/demo/x.log "${COM[@]}" -- 'echo free form'; expect_rc 2
	# The code changes after approval: the pin no longer matches.
	echo v2 >prepo/train.py
	run bash "$L" --plan docs/plans/2026-10-08-demo.md --run baseline --plan-sha256 "$s" "${COM2[@]}" --resume; expect_rc 3 && expect_out "changed since the plan was approved"
	cp docs/plans/2026-10-08-demo.md docs/plans/notes.md
	run bash "$L" --plan docs/plans/notes.md --run tilde --plan-sha256 "$(sha docs/plans/notes.md)" "${COM2[@]}"; expect_rc 3 && expect_out "<date>-<ID>.md"
	chmod g+w docs/plans/2026-10-08-demo.md
	run bash "$L" --plan docs/plans/2026-10-08-demo.md --run tilde --plan-sha256 "$s" "${COM2[@]}"; expect_rc 3 && expect_out "Others may write"
	chmod g-w docs/plans/2026-10-08-demo.md
}

test_env_is_read_never_run() {
	cp .env .env.bak
	printf 'GOOD="quoted value"\nBAD=$(touch %s/pwned)\nLD_PRELOAD=/tmp/evil.so\n' "$TMP_ROOT" >>.env
	run bash "$L" --purpose p --log logs/e/env.log "${COM[@]}" --wait 6 -- 'echo "[$GOOD][$BAD][${LD_PRELOAD:-unset}]"'
	mv .env.bak .env
	expect_rc 0 && expect [ ! -e "$TMP_ROOT/pwned" ]
	expect grep -q '^\[quoted value\]\[$(touch' logs/e/env.log && expect grep -q '\]\[unset\]$' logs/e/env.log
}

test_env_cannot_change_the_launcher_or_what_runs() {
	cp .env .env.bak
	printf 'cmd=echo PWNED\nlog=/tmp/elsewhere.log\nHOME=/evil\nCDPATH=/evil\nline=kept\n_vrl_name=x\n' >>.env
	run bash "$L" --purpose p --log logs/e/scope.log "${COM[@]}" --wait 6 -- 'echo "[$HOME][${CDPATH:-unset}][$line]"'
	mv .env.bak .env
	expect_rc 0 && expect grep -q "^\[$HOME\]\[unset\]\[kept\]$" logs/e/scope.log && expect [ ! -e /tmp/elsewhere.log ]
	expect_no_out PWNED
}

test_a_long_command_is_still_checked() {
	run bash "$L" --purpose p --log logs/r/long.log "${COM[@]}" -- "CUDA_VISIBLE_DEVICES=7 true # $(head -c 70000 /dev/zero | tr '\0' x)"
	expect_rc 3 && expect_out "CUDA_VISIBLE_DEVICES"
}

test_the_pin_sees_what_git_would_hide() {
	git init -q hrepo && (cd hrepo && git config user.name t && git config user.email t@t && git config commit.gpgsign false &&
		echo v1 >train.py && printf 'ignored/\n' >.gitignore && git add . && git commit -qm init)
	run bash "$L" --pin hrepo; expect_rc 0 && expect_out "diff=clean"
	# An untracked file counts unless a committed .gitignore ignores it.
	echo 'import os' >hrepo/sitecustomize.py; echo sitecustomize.py >>hrepo/.git/info/exclude
	git -C hrepo config status.showUntrackedFiles no
	run bash "$L" --pin hrepo; expect_rc 0 && expect_no_out "diff=clean"
	rm hrepo/sitecustomize.py; mkdir -p hrepo/ignored && echo x >hrepo/ignored/cache
	run bash "$L" --pin hrepo; expect_rc 0 && expect_out "diff=clean"
	# A file marked skip-worktree hides its changes, so the pin refuses it.
	git -C hrepo update-index --skip-worktree train.py; echo v2 >hrepo/train.py
	run bash "$L" --pin hrepo; expect_rc 1 && expect_out "skip-worktree"
	git -C hrepo update-index --no-skip-worktree train.py; echo v1 >hrepo/train.py
}

test_plan_form_refuses_what_a_reader_would_not_see() {
	git init -q qrepo && (cd qrepo && git config user.name t && git config user.email t@t && git config commit.gpgsign false &&
		echo v1 >train.py && git add . && git commit -qm init)
	pin="$(bash "$L" --pin qrepo)"
	p=docs/plans/2026-10-09-hard.md
	printf '```bash run=a gpus=0 %s\necho a\n```\n```text\n```bash run=b gpus=0 code=none\n```\n```bash run=c gpus=0 code=qrepo@%s diff=clean\necho c\n```\n```bash run=d gpus=0 code=none\ncat <<'"'"'X'"'"'\n```~\nX\necho still d\n```\n' \
		"$pin" "$(git -C qrepo rev-parse --short=7 HEAD)" >"$p"
	s="$(sha "$p")"
	run bash "$L" --plan "$p" --run b --plan-sha256 "$s" "${COM2[@]}"; expect_rc 3 && expect_out "no block for run b"
	run bash "$L" --plan "$p" --run c --plan-sha256 "$s" "${COM2[@]}"; expect_rc 3 && expect_out "12 hex digits"
	run bash "$L" --plan "$p" --run .. --plan-sha256 "$s" "${COM2[@]}"; expect_rc 3 && expect_out "starts with a letter"
	mkdir -p "$TMP_ROOT/elsewhere" runs && ln -s "$TMP_ROOT/elsewhere" runs/2026-10-09-hard
	run bash "$L" --plan "$p" --run a --plan-sha256 "$s" "${COM2[@]}"; expect_rc 3 && expect_out "symlink"
	rm runs/2026-10-09-hard
	run bash "$L" --plan "$p" --run d --plan-sha256 "$s" "${COM2[@]}" --wait 6; expect_rc 0 && expect grep -q '^still d$' logs/2026-10-09-hard/d.log
	cp "$p" docs/plans/2026-10-09-hard-again.md
	run bash "$L" --plan "$p" --run a --plan-sha256 "$s" "${COM2[@]}"; expect_rc 3 && expect_out "same content"
	rm docs/plans/2026-10-09-hard-again.md
	run bash "$L" --plan "$p" --run a --plan-sha256 "$s" "${COM2[@]}" --wait 6; expect_rc 0
	printf 'A note.\n<!--\n```bash run=x gpus=0 code=none\necho hidden\n```\n-->\n' >docs/plans/2026-10-09-hidden.md
	run bash "$L" --plan docs/plans/2026-10-09-hidden.md --run x --plan-sha256 "$(sha docs/plans/2026-10-09-hidden.md)" "${COM2[@]}"
	expect_rc 3 && expect_out "HTML comment"
	printf 'Run y, run=y, is below.\n```bash run=y gpus=0 code=none\necho y\n```\n' >docs/plans/2026-10-09-twice.md
	run bash "$L" --plan docs/plans/2026-10-09-twice.md --run y --plan-sha256 "$(sha docs/plans/2026-10-09-twice.md)" "${COM2[@]}"
	expect_rc 3 && expect_out "more than once"
	ln -s "$TMP_ROOT/target.log" logs/r/link.log 2>/dev/null || { mkdir -p logs/r && ln -s "$TMP_ROOT/target.log" logs/r/link.log; }
	run bash "$L" --purpose p --log logs/r/link.log "${COM[@]}" -- 'echo hi'; expect_rc 3 && expect [ ! -e "$TMP_ROOT/target.log" ]
}

test_the_local_machine_of_a_remote_workspace_runs_nothing() {
	mkdir -p "$TMP_ROOT/lm/docs/AGENTS" && cd "$TMP_ROOT/lm" || return 1
	printf 'TZ=UTC\n' >.env && touch docs/AGENTS/remote.md
	run bash "$L" --purpose p --log logs/x.log "${COM[@]}" -- 'echo ran'; expect_rc 2 && expect_out "runs no code" && expect [ ! -e logs/x.log ]
	run bash "$L" --pin none; expect_rc 2
	run bash "$SCRIPTS/resources.sh"; expect_rc 2 && expect_out "remote-mode workspace"
	run python3 "$SCRIPTS/gpu_hours.py" .; expect_rc 2 && expect_out "remote-mode workspace"
	run bash "$SCRIPTS/setup_clis.sh" check --only uv; expect_rc 2 && expect_out "install uv and hf on the remote host"
	mkdir -p sub && (cd sub && bash "$L" --pin none) >/dev/null 2>&1; expect [ $? = 2 ]
	mkdir -p "$TMP_ROOT/linked" && ln -s "$TMP_ROOT/linked" code && (cd code && bash "$L" --pin none) >/dev/null 2>&1; expect [ $? = 2 ]
	(cd sub && python3 "$SCRIPTS/gpu_hours.py" .) >/dev/null 2>&1; expect [ $? = 2 ]
	VRL_REMOTE=1 run bash "$L" --pin none; expect_rc 0 && expect_out "code=none"
	VRL_REMOTE=1 run bash "$L" --plan docs/plans/x.md --sync-apply main_repo --commit abc; expect_rc 2 && expect_out "take no other form"
	run bash "$L" --sync-prepare main_repo; expect_rc 2
	run bash "$L" --help; expect_rc 0
	cd "$WS" || return 1
}

test_status_reads_each_run() {
	printf '```bash run=ended gpus=0 code=none\necho finished\n```\n```bash run=going gpus=0 code=none\nsleep %s6\n```\n```bash run=later gpus=0 code=none\necho later\n```\n' "$U" >docs/plans/2026-10-11-status.md
	s="$(sha docs/plans/2026-10-11-status.md)"
	run bash "$L" --plan docs/plans/2026-10-11-status.md --run ended --plan-sha256 "$s" "${COM2[@]}" --wait 6; expect_rc 0
	run bash "$L" --plan docs/plans/2026-10-11-status.md --run going --plan-sha256 "$s" "${COM2[@]}"; expect_rc 0
	run bash "$L" --plan docs/plans/2026-10-11-status.md --status
	expect_rc 0 && expect_out "finished, exit code 0" && expect_out "running, PID" && expect_out "not started" && expect_out "run       later"
	run bash "$L" --plan docs/plans/2026-10-11-status.md --run ended --status; expect_rc 0 && expect_no_out "run       going"
	pkill -f "^sleep ${U}6\$"; sleep 2
	run bash "$L" --plan docs/plans/2026-10-11-status.md --run going --status; expect_out "finished, exit code"
	run bash "$L" --plan docs/plans/nothing.md --status; expect_rc 2
	# A fence inside another block opens no run.
	printf '````text\n```bash run=<run> gpus=1\n````\n```bash run=real gpus=0 code=none\necho real\n```\n```run=bare gpus=0 code=none\necho bare\n```\n' >docs/plans/2026-10-12-nested.md
	run bash "$L" --plan docs/plans/2026-10-12-nested.md --status; expect_rc 0 && expect_out "run       real" && expect_out "run       bare" && expect_no_out "<run>"
}

test_no_launch_while_a_sync_holds_the_checkout() {
	git init -q srepo && (cd srepo && git config user.name t && git config user.email t@t && git config commit.gpgsign false && echo v1 >a.py && git add . && git commit -qm init)
	mkdir srepo/.git/vrl-sync.lock
	run bash "$L" --purpose p --log logs/s/sync.log "${COM2[@]}" --code srepo -- 'echo hi'; expect_rc 3 && expect_out "A sync of srepo is in progress"
	rmdir srepo/.git/vrl-sync.lock
	run bash "$L" --purpose p --log logs/s/sync.log "${COM2[@]}" --code srepo --wait 6 -- 'echo hi'; expect_rc 0
}

test_wait_takes_seconds() {
	run bash "$L" --purpose p --log logs/w/w.log "${COM[@]}" --wait -- 'echo hi'; expect_rc 2 && expect_out "--wait takes whole seconds"
}

test_refusals() {
	run bash "$L" --purpose p --log logs/r/t.log "${COM[@]}" -- 'CUDA_VISIBLE_DEVICES=0 python x.py'; expect_rc 3
	run bash "$L" --purpose p --log logs/r/t.log "${COM[@]}" -- 'python x.py --hf hf_abcdefghijklmnopqrstuvwxyz123'; expect_rc 3
	run bash "$L" --purpose p --log logs/r/t.log "${COM[@]}" -- 'python x.py --api_key=abc123'; expect_rc 3
	printf '#!/bin/sh\n' >"$TMP_ROOT/bin/sbatch"; chmod +x "$TMP_ROOT/bin/sbatch"
	PATH="$TMP_ROOT/bin:$PATH" run bash "$L" --purpose p --log logs/r/t.log "${COM[@]}" -- 'echo hi'; expect_rc 3 && expect_out "job scheduler"
	rm -f "$TMP_ROOT/bin/sbatch"
	run bash "$L" --purpose p --log logs/r/t.log --nohup --machine box --code none -- 'echo hi'; expect_rc 2
	run bash "$L" --purpose p --log logs/r/t.log --nohup --no-gpu --code none -- 'echo hi'; expect_rc 2
	run bash "$L" --purpose $'two\nlines' --log logs/r/t.log "${COM[@]}" -- 'echo hi'; expect_rc 2
	run bash "$L" --purpose p --log logs/r/t.log --tmux 'bad:name' --no-gpu --machine box --code none -- 'echo hi'; expect_rc 2
}

test_ordinary_flags_are_not_secrets() {
	run bash "$L" --purpose p --log logs/s/ok.log "${COM[@]}" --wait 6 -- 'echo --max_tokens=4096 --tokenizer=gpt2 --max_new_tokens=256 --password_file=pw.txt --api_key=$KEY'
	expect_rc 0 && expect_out 'ended with exit code 0'
}

test_no_second_copy_even_after_its_shell_is_killed() {
	run bash "$L" --purpose 'd / long' --log logs/x/long.log "${COM[@]}" -- "sleep ${U}5; true"; expect_rc 0 || return 1
	run bash "$L" --purpose 'd / long' --log logs/x/long.log "${COM[@]}" -- 'echo again'; expect_rc 3 && expect_out "still writes this log"
	# SIGKILL to the shell leaves the command running: it still writes the log, so no second copy.
	kill -9 "$(session_pid logs/x/long.log)"; sleep 1
	run bash "$L" --purpose 'd / long' --log logs/x/long.log "${COM[@]}" --restart -- 'echo again'; expect_rc 3 && expect_out "still writes this log"
	pkill -9 -f "^sleep ${U}5\$"; sleep 1
	run bash "$L" --purpose 'd / long' --log logs/x/long.log "${COM[@]}" -- 'echo again'; expect_rc 3 && expect_out "--restart"
	run bash "$L" --purpose 'd / long' --log logs/x/long.log "${COM[@]}" --restart --wait 6 -- 'echo again'; expect_rc 0
	expect grep -q 'exit code unknown: closed by a restart' logs/x/long.log
}

test_a_failed_run_needs_restart() {
	run bash "$L" --purpose 'f / x' --log logs/f/x.log "${COM[@]}" --wait 6 -- 'exit 1'; expect_rc 1
	run bash "$L" --purpose 'f / x' --log logs/f/x.log "${COM[@]}" -- 'echo again'; expect_rc 3 && expect_out "exit code 1"
	run bash "$L" --purpose 'f / x' --log logs/f/x.log "${COM[@]}" --restart --wait 6 -- 'echo again'; expect_rc 0
}

test_finished_run_is_not_overwritten() {
	run bash "$L" --purpose 'f / r' --log logs/f/r.log "${COM[@]}" --wait 6 -- 'echo done'; expect_rc 0
	run bash "$L" --purpose 'f / r' --log logs/f/r.log "${COM[@]}" -- 'echo again'; expect_rc 3 && expect_out "new run name"
	run bash "$L" --purpose 'f / r' --log logs/f/r.log "${COM[@]}" --resume --wait 6 -- 'echo resumed'; expect_rc 0
}

test_dirty_checkout_diff_rebuilds_it() {
	git init -q repo && (
		cd repo && git config user.name t && git config user.email t@t && git config commit.gpgsign false &&
			printf 'a\n' >tracked.txt && printf '\0\1bin' >blob.bin && printf 'keep\n' >keep.py && git add . && git commit -qm init &&
			git config color.ui always && git config diff.noprefix true &&
			printf 'a\nb\n' >tracked.txt && printf '\0\2bin2' >blob.bin && mkdir -p newpkg/sub && printf 'new\n' >newpkg/sub/mod.py &&
			printf 'x\n' >'space name.txt' && printf 'y\n' >'--output=keep.py'
	)
	run bash "$L" --purpose 'd / dirty' --log logs/x/dirty.log --nohup --no-gpu --machine box --code repo -- 'echo hi'
	expect_rc 3 && expect_out "give --outputs"
	run bash "$L" --purpose 'd / dirty' --log logs/x/dirty.log --outputs runs/x/dirty --nohup --no-gpu --machine box --code repo -- 'echo hi'
	expect_rc 0 && expect [ -f runs/x/dirty/git_diff.patch ] || return 1
	expect [ "$(cat repo/keep.py)" = keep ]
	expect [ "$(ls -l runs/x/dirty/git_diff.patch | cut -c1-10)" = "-rw-------" ]
	git clone -q repo "$TMP_ROOT/clone" && (cd "$TMP_ROOT/clone" && git apply "$WS/runs/x/dirty/git_diff.patch") &&
		diff -r -x .git repo "$TMP_ROOT/clone" >/dev/null || { echo "the diff does not rebuild the checkout"; FAILED=1; }
}

test_help_through_stdin() {
	OUT="$(bash -s -- --help <"$L" 2>&1)"
	expect_out "Usage, from the workspace root"
}

run_tests
