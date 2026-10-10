#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2016,SC2034 # Sourced helpers, literal test strings, and variables used across files.
# Tests for vrl_ssh.sh, with the fake ssh, mount, and sshfs.
. "$(dirname "$0")/lib.sh"
export PATH="$FAKES:$PATH" FAKE_SSH_STATE="$TMP_ROOT/state" FAKE_HOME="$TMP_ROOT/home" TMPDIR="$TMP_ROOT/tmp"
export HOME="$TMP_ROOT/user"
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

test_mount_rules() {
	up
	cd "$TMP_ROOT/here" || return 1
	run bash "$V" mount myhpc --workspace "$WS" --mount "$HOME/.ssh"; expect_rc 2 && expect_out "right in the launch directory"
	(cd "$TMP_ROOT/state" && bash "$V" mount myhpc --workspace "$WS" --mount m) >"$TMP_ROOT/m.out" 2>&1
	expect grep -q "the one that holds docs/AGENTS" "$TMP_ROOT/m.out"
	run bash "$V" mount myhpc --workspace "$WS" --mount .claude; expect_rc 2 && expect_out "not hidden"
	mkdir -p "mnt full" && touch "mnt full/file"
	run bash "$V" mount myhpc --workspace "$WS" --mount "mnt full"; expect_rc 2 && expect_out "not empty"
	mkdir -p "mnt one"
	FAKE_MOUNT_STYLE=linux run bash "$V" mount myhpc --workspace "$WS" --mount "mnt one"; expect_rc 0 && expect_out "is mounted at"
	FAKE_MOUNT_STYLE=linux run bash "$V" check myhpc --mount "mnt one"; expect_rc 0 && expect_out "is listed"
	printf 'otherhost:/data on %s (macfuse, nodev)\n' "$TMP_ROOT/here/mnt two" >>"$FAKE_SSH_STATE/mounts"
	mkdir -p "mnt two"
	run bash "$V" mount myhpc --workspace "$WS" --mount "mnt two"; expect_rc 1 && expect_out "Something other than an SSHFS mount"
}

test_resolve() {
	run bash "$V" resolve myhpc; expect_rc 0 && expect_out "hostname: example.org" && expect_out "__EXIT 0"
}

run_tests
