#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2016,SC2034 # Sourced helpers, literal test strings, and variables used across files.
# Tests for vrl_ssh.sh, with the fake ssh, which runs remote commands here.
. "$(dirname "$0")/lib.sh"
export PATH="$FAKES:$PATH" FAKE_SSH_STATE="$TMP_ROOT/state" FAKE_HOME="$TMP_ROOT/home" TMPDIR="$TMP_ROOT/tmp"
export HOME="$TMP_ROOT/user"
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t GIT_CONFIG_NOSYSTEM=1
mkdir -p "$FAKE_SSH_STATE" "$FAKE_HOME" "$TMPDIR" "$TMP_ROOT/here/docs/AGENTS" "$HOME/.ssh"
printf 'Include config.d/*\nHost myhpc\n    HostName example.org\nHost my.hpc other.host\n    HostName example.net\n' >"$HOME/.ssh/config"
mkdir -p "$HOME/.ssh/config.d" && printf 'Host *.cluster !bad.cluster\n    User bob\n' >"$HOME/.ssh/config.d/hpc"
WS="$TMP_ROOT/remote ws/it's"
mkdir -p "$WS"
printf 'TZ=Asia/Dubai\nGREETING=hello\nQUOTED="a b"\nSINGLE='"'"'c d'"'"'\nBAD=$(touch %s/pwned)\nLD_PRELOAD=/tmp/evil.so\nHOME=/evil\n_vrl_n=x\nCRLF=yes\r\n' "$TMP_ROOT" >"$WS/.env"
V="$SCRIPTS/vrl_ssh.sh"
up() { bash "$V" connect myhpc >/dev/null 2>&1; }
down() { [ -f "$FAKE_SSH_STATE/master" ] && kill "$(cat "$FAKE_SSH_STATE/master")" 2>/dev/null; rm -f "$FAKE_SSH_STATE/master"; }

test_marker_on_argument_errors() {
	run bash "$V" run myhpc --workspace rel -- true; expect_rc 2 && expect_out "__EXIT 2"
	run bash "$V" run 'a;b' --workspace /x -- true; expect_rc 2 && expect_out "__EXIT 2"
	run bash "$V" run user@host --workspace /x -- true; expect_rc 2
}

test_limit_is_never_evaluated() {
	run bash "$V" check myhpc --limit 'PWD[$(touch '"$TMP_ROOT"'/pwned)]'
	expect_rc 2 && [ ! -e "$TMP_ROOT/pwned" ] || { echo "the limit ran a command"; return 1; }
	run bash "$V" check myhpc --limit 08; [ "$RC" != 2 ] || { echo "08 should read as 8"; return 1; }
}

test_no_master_means_no_login() {
	down
	run bash "$V" run myhpc --workspace "$WS" -- 'echo hi'
	expect_rc 6 && expect_out "run connect first" && [ ! -e "$FAKE_SSH_STATE/direct" ]
	run bash "$V" check myhpc; expect_rc 6 && [ ! -e "$FAKE_SSH_STATE/direct" ]
}

test_connect_auth_down_hostkey() {
	down
	FAKE_SSH_MASTER=auth run bash "$V" connect myhpc; expect_rc 3 && expect_out "own terminal" && expect_out "ControlPath=/tmp/vrl-ssh-"
	FAKE_SSH_MASTER=down run bash "$V" connect myhpc; expect_rc 255 && expect_out "unreachable" && expect_no_out "own terminal"
	FAKE_SSH_MASTER=hostkey run bash "$V" connect myhpc; expect_rc 5
	run bash "$V" connect myhpc; expect_rc 0 && expect_out "answers through the new master"
	run bash "$V" connect myhpc; expect_rc 0 && expect_out "answers through the master"
}

test_socket_folder_is_private() {
	up
	found=0
	for d in "$HOME/.cache/vrl-ssh" "/tmp/vrl-ssh-$(id -u)"; do
		[ -e "$d" ] || continue
		found=1
		expect [ ! -L "$d" ] && expect [ "$(ls -ld "$d" | cut -c1-10)" = "drwx------" ]
	done
	expect [ "$found" = 1 ]
}

test_alias_must_be_a_host_entry() {
	run bash "$V" check evil.example.org; expect_rc 2 && expect_out "matches no Host line"
	run bash "$V" check node1.cluster; [ "$RC" != 2 ] || { echo "a Host pattern from an included file should pass: $OUT"; FAILED=1; }
	run bash "$V" check other.host; [ "$RC" != 2 ] || { echo "a second name on a Host line should pass: $OUT"; FAILED=1; }
}

test_signal_during_master_check_prints_marker() {
	up
	FAKE_SSH_HANG=1 bash "$V" check myhpc --limit 30 >"$TMP_ROOT/sig2.out" 2>&1 &
	pid=$!
	sleep 1
	kill -TERM "$pid"; wait "$pid"
	expect grep -qx '__EXIT 143' "$TMP_ROOT/sig2.out"
}

test_run_quoting_input_and_env() {
	up
	run bash "$V" run myhpc --workspace "$WS" -- 'pwd
echo "it'"'"'s $GREETING, TZ=$TZ"
printf "[%s]\n" "a  b" '"'"'$HOME'"'"'
cat; echo "cat got EOF"'
	expect_rc 0 && expect_out "/remote ws/it's" && expect_out "it's hello, TZ=Asia/Dubai" && expect_out '[a  b]' &&
		expect_out '[$HOME]' && expect_out "cat got EOF"
	FAKE_SSH_SHELL=zsh run bash "$V" run myhpc --workspace "$WS" -- 'echo $GREETING; exit 7'
	expect_rc 7 && expect_out "__EXIT 7"
	run bash "$V" run myhpc --workspace "$WS" -- printf x y; expect_rc 2
}

test_marker_on_its_own_line() {
	up
	run bash "$V" run myhpc --workspace "$WS" -- 'printf abc'
	printf '%s\n' "$OUT" | grep -qx '__EXIT 0' || { echo "$OUT"; return 1; }
}

test_env_is_read_never_run() {
	up
	run bash "$V" run myhpc --workspace "$WS" -- 'echo "[$QUOTED][$SINGLE][${LD_PRELOAD:-unset}][$BAD]"; case ":$PATH:" in *":$HOME/.local/bin:"*) echo path-ok;; esac; echo "[$HOME][$CRLF]"'
	expect_rc 0 && expect_out "[a b][c d][unset][\$(touch" && expect_out "path-ok" && expect [ ! -e "$TMP_ROOT/pwned" ]
	expect_out "[$HOME][yes]"
}

test_hung_master_check_is_7() {
	up
	FAKE_SSH_CHECK_HANG=1 run bash "$V" run myhpc --workspace "$WS" --limit 3 -- 'echo hi'
	expect_rc 7 && expect_out "master does not answer"
}

test_env_missing() {
	up
	mkdir -p "$TMP_ROOT/noenv"
	run bash "$V" run myhpc --workspace "$TMP_ROOT/noenv" -- 'echo no'; expect_rc 98 && expect_no_out "no
"
	run bash "$V" run myhpc --workspace "$TMP_ROOT/noenv" --no-env -- 'echo yes'; expect_rc 0 && expect_out yes
}

test_time_limit_and_temp_files() {
	up
	start=$(date +%s)
	# Into a file, not a pipe: the fake runs the remote command locally, where its sleep outlives ssh.
	bash "$V" run myhpc --workspace "$WS" --limit 2 -- 'sleep 20' >"$TMP_ROOT/limit.out" 2>&1 &
	wait $!
	RC=$?
	expect_rc 124 && [ $(($(date +%s) - start)) -lt 10 ] || { echo "took $(($(date +%s) - start)) s"; return 1; }
	grep -qx '__EXIT 124' "$TMP_ROOT/limit.out" || { cat "$TMP_ROOT/limit.out"; return 1; }
	pkill -f 'sleep 20' 2>/dev/null
	[ -z "$(ls -A "$TMPDIR")" ] || { echo "temp files left: $(ls "$TMPDIR")"; return 1; }
}

test_signal_prints_marker() {
	up
	bash "$V" run myhpc --workspace "$WS" --limit 30 -- 'sleep 20' >"$TMP_ROOT/sig.out" 2>&1 &
	pid=$!
	sleep 1
	kill -TERM "$pid"
	wait "$pid"
	grep -qx '__EXIT 143' "$TMP_ROOT/sig.out" || { cat "$TMP_ROOT/sig.out"; return 1; }
}

test_script_only_from_the_scripts_folder() {
	up
	printf 'secret-line\n' >"$TMP_ROOT/creds"
	run bash "$V" script myhpc -- "$TMP_ROOT/creds"; expect_rc 2 && expect_no_out "secret-line"
	mkdir -p "$TMP_ROOT/fake-scripts"; printf 'echo shipped\n' >"$TMP_ROOT/fake-scripts/resources.sh"; ln -s "$V" "$TMP_ROOT/fake-scripts/vrl_ssh.sh"
	run bash "$TMP_ROOT/fake-scripts/vrl_ssh.sh" script myhpc --workspace "$WS" -- resources.sh --help; expect_no_out "shipped"
	run bash "$V" script myhpc --workspace "$WS" -- gpu_hours.py --help; expect_rc 0 && expect_out "single-GPU hours"
	run bash "$V" script myhpc --workspace "$WS" -- resources.sh --help; expect_rc 0 && expect_out "Usage: resources.sh"
}

test_alias_must_match_rules() {
	mkdir -p "$TMP_ROOT/rules/docs/AGENTS"
	cd "$TMP_ROOT/rules" || return 1
	printf 'Use `ssh other.host` for nothing.\n| Remote host | `ssh myhpc`: the `Host myhpc` entry |\n' >docs/AGENTS/remote.md
	run bash "$V" check other.host; expect_rc 2 && expect_out "names the alias myhpc"
	printf '| Remote host | the host |\n' >docs/AGENTS/remote.md
	run bash "$V" check myhpc; expect_rc 2 && expect_out "must name the remote host"
}

sha() { (sha256sum "$1" 2>/dev/null || shasum -a 256 "$1") | cut -d' ' -f1; }
# A local workspace in remote mode, with its code, and an empty remote workspace.
LW="$TMP_ROOT/local"
RW="$TMP_ROOT/rw/it's ws"
make_workspace() {
	[ -d "$LW/.git" ] && return 0
	mkdir -p "$LW/docs/AGENTS" "$LW/docs/plans" "$RW"
	(
		cd "$LW" || exit 1
		printf '/*\n!/.gitignore\n!/AGENTS.md\n!/docs/\n!/tests/\n/docs/AGENTS/machine.md\n/docs/AGENTS/remote.md\n' >.gitignore
		printf '| Remote host | `ssh myhpc`: the `Host myhpc` entry |\n' >docs/AGENTS/remote.md
		echo '# Rules' >AGENTS.md
		printf '# Plan\n```bash run=a gpus=0 code=none\necho a\n```\n' >docs/plans/2026-10-10-demo.md
		git init -q -b main . && git add -A && git commit -qm init
		git init -q -b main main_repo && cd main_repo && echo 'print(1)' >train.py && printf '__pycache__/\n' >.gitignore &&
			git add -A && git commit -qm code
	)
}

test_sync_copies_commits_and_prints_pins() {
	up
	make_workspace
	cd "$LW" || return 1
	OUT="$( (umask 002; bash "$V" sync myhpc --workspace "$RW" -- . main_repo) 2>&1)"; RC=$?
	expect_rc 0 && expect_out "synced . code=.@" || return 1
	expect_out "synced main_repo code=main_repo@$(git -C main_repo rev-parse --short=12 HEAD) diff=clean"
	expect_out "sha256 docs/plans/2026-10-10-demo.md $(sha docs/plans/2026-10-10-demo.md)"
	expect [ "$(cat "$RW/main_repo/train.py")" = 'print(1)' ] && expect [ ! -e "$RW/docs/AGENTS/remote.md" ]
	expect [ "$(ls -l "$RW/docs/plans/2026-10-10-demo.md" | cut -c1-10)" = "-rw-r--r--" ]
	# A later commit replaces the earlier one, and a deleted file goes; ignored remote files stay.
	mkdir -p "$RW/main_repo/__pycache__" && touch "$RW/main_repo/__pycache__/x.pyc"
	(cd main_repo && echo 'print(2)' >train.py && echo x >extra.py && git add -A && git commit -qm two && git rm -q extra.py && git commit -qm three)
	run bash "$V" sync myhpc --workspace "$RW" -- main_repo
	expect_rc 0 && expect [ "$(cat "$RW/main_repo/train.py")" = 'print(2)' ] && expect [ ! -e "$RW/main_repo/extra.py" ]
	expect [ -e "$RW/main_repo/__pycache__/x.pyc" ]
	# The remote host's own pin matches the one sync printed, and names the branch it came from.
	run bash "$V" script myhpc --workspace "$RW" --no-env -- launch_run.sh --pin main_repo
	expect_out "code=main_repo@$(git -C main_repo rev-parse --short=12 HEAD) diff=clean"
	expect [ "$(cat "$RW/main_repo/.git/vrl-sync.branch")" = main ]
	# The plan file passes the plan form's checks there, with the hash sync printed.
	printf 'TZ=UTC\n' >"$RW/.env"
	run bash "$V" script myhpc --workspace "$RW" -- launch_run.sh --plan docs/plans/2026-10-10-demo.md --run a \
		--plan-sha256 "$(sha docs/plans/2026-10-10-demo.md)" --nohup --no-gpu --machine box --wait 6
	expect_rc 0 && expect_out "ended with exit code 0"
}

test_sync_refuses_what_it_must_not_copy_or_overwrite() {
	up
	make_workspace
	cd "$LW" || return 1
	run bash "$V" sync myhpc --workspace "$RW" -- main_repo; expect_rc 0 || return 1
	run bash "$V" sync myhpc --workspace "$RW" -- docs; expect_rc 2
	run bash "$V" sync myhpc --workspace "$RW" -- ../x; expect_rc 2
	run bash "$V" sync myhpc --workspace "$RW" -- main_repo/sub; expect_rc 2
	# Only commits travel.
	echo dirty >>main_repo/train.py
	run bash "$V" sync myhpc --workspace "$RW" -- main_repo; expect_rc 3 && expect_out "not committed"
	git -C main_repo checkout -q train.py
	echo new >main_repo/new.py
	run bash "$V" sync myhpc --workspace "$RW" -- main_repo; expect_rc 3 && expect_out "new.py"
	rm main_repo/new.py
	# A change made on the remote host is never overwritten.
	echo hotfix >>"$RW/main_repo/train.py"
	(cd main_repo && echo 'print(3)' >train.py && git commit -qam four)
	run bash "$V" sync myhpc --workspace "$RW" -- main_repo; expect_rc 3 && expect_out "no sync made"
	expect grep -q hotfix "$RW/main_repo/train.py"
	git -C "$RW/main_repo" checkout -q train.py
	# Nor is the code of a run that is still going, or of a launch in progress.
	mkdir -p "$RW/logs/x"
	printf '# command:   python train.py\n# code:      main_repo (main) @ abc (clean)\n# run-id:    0123456789ab\n# session:   PID 99999\n# ---------- stdout + stderr ----------\n' >"$RW/logs/x/a.log"
	sleep 30 >>"$RW/logs/x/a.log" &
	writer=$!
	run bash "$V" sync myhpc --workspace "$RW" -- main_repo; expect_rc 3 && expect_out "Runs still going use main_repo"
	kill "$writer"; wait "$writer" 2>/dev/null
	mkdir "$RW/logs/x/b.log.lock"
	run bash "$V" sync myhpc --workspace "$RW" -- main_repo; expect_rc 3 && expect_out "A launch is in progress"
	rmdir "$RW/logs/x/b.log.lock"
	run bash "$V" sync myhpc --workspace "$RW" -- main_repo; expect_rc 0 && expect grep -q 'print(3)' "$RW/main_repo/train.py"
	# Submodules and Git LFS files never travel.
	(cd main_repo && mkdir sub && git update-index --add --cacheinfo "160000,$(git rev-parse HEAD),sub" && git commit -qm sub)
	run bash "$V" sync myhpc --workspace "$RW" -- main_repo; expect_rc 3 && expect_out "submodules"
	(cd main_repo && git rm -q --cached sub && rmdir sub && printf '*.bin filter=lfs\n' >.gitattributes && echo x >a.bin && git add -A && git commit -qm lfs)
	run bash "$V" sync myhpc --workspace "$RW" -- main_repo; expect_rc 3 && expect_out "LFS"
	(cd main_repo && git rm -q .gitattributes a.bin && git commit -qm nolfs)
	# A run's traces here are reported.
	mkdir -p main_repo/__pycache__
	run bash "$V" sync myhpc --workspace "$RW" -- main_repo; expect_rc 0 && expect_out "as if code ran on this machine"
	rmdir main_repo/__pycache__
}

test_sync_worktree_shares_its_owner_mirror() {
	up
	make_workspace
	cd "$LW" || return 1
	git -C main_repo worktree add -q -b feat ../worktrees/feat
	(cd worktrees/feat && echo feat >feat.py && git add feat.py && git commit -qm feat)
	run bash "$V" sync myhpc --workspace "$RW" -- main_repo worktrees/feat
	expect_rc 0 && expect_out "synced worktrees/feat code=worktrees/feat@$(git -C worktrees/feat rev-parse --short=12 HEAD) diff=clean" || return 1
	expect [ -f "$RW/worktrees/feat/feat.py" ] && expect [ ! -e "$RW/main_repo/feat.py" ]
	expect [ "$(cd "$RW/worktrees/feat" && cd "$(git rev-parse --git-common-dir)" && pwd -P)" = "$(cd "$RW/main_repo/.git" && pwd -P)" ]
	(cd worktrees/feat && echo two >feat.py && git commit -qam two)
	run bash "$V" sync myhpc --workspace "$RW" -- worktrees/feat
	expect_rc 0 && expect grep -q two "$RW/worktrees/feat/feat.py"
}

test_read_prints_text_under_results_only() {
	up
	mkdir -p "$RW/logs/r" "$RW/tmp"
	printf 'one\ntwo\nthree\n' >"$RW/logs/r/x.log"
	run bash "$V" read myhpc --workspace "$RW" --lines 2 -- logs/r/x.log
	expect_rc 0 && expect_out "two
three" && expect_no_out "one"
	run bash "$V" read myhpc --workspace "$RW" -- logs/r; expect_rc 0 && expect_out "x.log"
	run bash "$V" read myhpc --workspace "$RW" -- .env; expect_rc 2
	run bash "$V" read myhpc --workspace "$RW" -- logs/../.env; expect_rc 2
	run bash "$V" read myhpc --workspace "$RW" --lines 0 -- logs/r/x.log; expect_rc 2
	printf 'A=1\n' >"$RW/tmp/.env.old"
	run bash "$V" read myhpc --workspace "$RW" -- tmp/.env.old; expect_rc 3 && expect_out "never prints a .env"
	printf 'a\000b\n' >"$RW/logs/r/bin.log"
	run bash "$V" read myhpc --workspace "$RW" -- logs/r/bin.log; expect_rc 3 && expect_out "not a text file"
	ln -s /etc "$RW/logs/out"
	run bash "$V" read myhpc --workspace "$RW" -- logs/out/hosts; expect_rc 3 && expect_out "leads outside"
	run bash "$V" read myhpc --workspace "$RW" -- logs/r/none.log; expect_rc 3 && expect_out "no such file"
}

test_fetch_copies_figures_only() {
	up
	make_workspace
	cd "$LW" || return 1
	mkdir -p "$RW/runs/x/figures"
	printf '\211PNG\r\n\032\nrest of the image\000\001' >"$RW/runs/x/figures/a.png"
	FAKE_SSH_BANNER="Welcome to the cluster" run bash "$V" fetch myhpc --workspace "$RW" -- runs/x/figures/a.png
	expect_rc 0 && expect cmp -s "$RW/runs/x/figures/a.png" tmp/fetched/runs/x/figures/a.png || return 1
	expect [ "$(ls -l tmp/fetched/runs/x/figures/a.png | cut -c1-10)" = "-rw-------" ]
	printf 'not an image' >"$RW/runs/x/figures/b.png"
	run bash "$V" fetch myhpc --workspace "$RW" -- runs/x/figures/b.png; expect_rc 3 && expect_out "not the png file"
	run bash "$V" fetch myhpc --workspace "$RW" -- runs/x/metrics.csv; expect_rc 2
	run bash "$V" fetch myhpc --workspace "$RW" -- tmp/fetched/a.png; expect_rc 2
	run bash "$V" fetch myhpc --workspace "$RW" -- data/a.png; expect_rc 2
	ln -s a.png "$RW/runs/x/figures/c.png"
	run bash "$V" fetch myhpc --workspace "$RW" -- runs/x/figures/c.png; expect_rc 3 && expect_out "not a regular file"
	{ printf '\211PNG\r\n\032\n'; head -c 1100000 /dev/zero; } >"$RW/runs/x/figures/big.png"
	run bash "$V" fetch myhpc --workspace "$RW" --max-mb 1 -- runs/x/figures/big.png; expect_rc 3 && expect_out "larger than"
	mkdir -p "$RW/tmp/lock" && printf 'version = 1\n' >"$RW/tmp/lock/uv.lock"
	run bash "$V" fetch myhpc --workspace "$RW" -- tmp/lock/uv.lock; expect_rc 0 && expect grep -q 'version = 1' tmp/fetched/tmp/lock/uv.lock
	mv tmp/fetched "$TMP_ROOT/fetched-away" && ln -s "$TMP_ROOT/fetched-away" tmp/fetched
	run bash "$V" fetch myhpc --workspace "$RW" -- runs/x/figures/a.png; expect_rc 3 && expect_out "symlink"
	rm tmp/fetched
}

test_resolve() {
	run bash "$V" resolve myhpc; expect_rc 0 && expect_out "hostname: example.org" && expect_out "__EXIT 0"
}

run_tests
