#!/usr/bin/env bash
# Reach the remote host of a remote-mode workspace through one SSH master, with the time limits,
# options, and exit marker that docs/AGENTS/remote.md asks for, so that no call hangs, no command
# needs quoting, and no call logs in by itself; and copy commits there, and figures back.
#
# Everything runs inside main(), so that bash reads the whole script before running it.

usage() {
	cat <<'EOF'
Usage: vrl_ssh.sh <action> <alias> [options] [-- <command> | -- <script> [args...] | -- <path>...]

Actions:
  resolve   Print the host name, user, port, and jump host the alias resolves to, without connecting.
  check     Check that the master is up and the remote host answers through it; print the time the
            round trip took.
  connect   check; if it fails, close the old master, the one this script starts, and start a new one,
            then check again. It never asks for a password: if the login needs one, a passphrase, or a
            second factor, it prints the command for the user to run in their own terminal.
  run       Run one shell command in the remote workspace, with its .env loaded. The command is the one
            string after `--`, sent as it is on the standard input of a remote bash, so it needs no
            quoting of its own and may span several lines; it gets no input itself. It runs any
            command: never allow it without a prompt.
  script    Run one of the scripts next to this one on the remote host (launch_run.sh, resources.sh,
            gpu_hours.py, setup_clis.sh), with the arguments after its name. With --workspace, it runs
            in the remote workspace with its .env loaded; without, in the remote home directory. It
            runs whatever those scripts run: launch_run.sh runs any command in its free form, so allow
            it without a prompt only in its --plan form.
  sync      Copy the commits of checkouts here to their mirrors in the remote workspace, at the same
            paths. Each path after `--` is `.`, the workspace repository, or a checkout in it: a
            folder at its root such as main_repo, worktrees/<branch>, or ref_repos/<repo>; give a
            worktree's own checkout in the same call or earlier. Only commits travel, so a checkout
            must have no change, staged or not, and no untracked file that is not ignored. Each
            mirror then holds that commit with no branch, and the sync prints its pin,
            `synced <path> code=<path>@<commit> diff=clean`, and for `.` the line
            `sha256 <plan> <hash>` for each plan file that changed. It refuses, changing nothing,
            while a run that is still going or a launch uses the checkout, while the mirror holds
            changes no sync made, and for submodules or Git LFS files. Run it from the workspace root.
  read      Print the last lines of a text file in the remote workspace, under logs/, runs/, or tmp/,
            or list a folder there. It changes nothing.
  fetch     Copy up to 10 files from the remote workspace to tmp/fetched/<path> here, readable by you
            only: figures (.png, .jpg, .jpeg, .svg, .pdf) under runs/ or tmp/, or a uv.lock under tmp/.
            Run it from the workspace root.

Options:
  --workspace DIR  The remote workspace, as an absolute path. run, sync, read, and fetch need it.
  --limit S        The time limit of the whole call, in seconds (default: 15 for check and connect,
                   60 otherwise; 0 for none, as the setup script's login or a first large sync needs).
                   Keep it 5 seconds below the agent's own limit for a shell call.
  --step-limit S   The remote time limit of the command (default: --limit minus 10; 0 for none).
  --no-env         With --workspace: do not load its .env, as before setup has written it.
  --lines N        read: how many lines from the end of the file (default 100, at most 2000).
  --max-mb N       fetch: the largest file to copy, in MB (default 20).

The alias must be a Host entry of ~/.ssh/config; when docs/AGENTS/remote.md exists here, it must be the
alias of the line that names both `ssh <alias>` and `Host <alias>`. No client logs in by itself: every
one goes through the master's socket, with ProxyCommand=false, so it fails when the master is gone.
Every call prints `__EXIT <code>` as its last line, on a line of its own. For run and script, the code
is the remote command's own, unless the line above it starts with `vrl_ssh:`. Exit codes:
  0    done; for run and script, the command's own exit code otherwise
  1    the remote host, or the master, does not answer: run connect, or stop and report
  2    bad arguments, or a folder or alias that the rules do not allow
  3    connect: the login needs the user, who runs the printed command in their own terminal;
       sync, read, fetch: refused, with the reason, and nothing changed
  4    sync, fetch: the copy or a remote step failed; sync again once the cause is fixed
  5    the host key could not be verified: stop and report; never turn off host-key checking
  6    no master is up: run connect first
  7    the master hangs: run connect
  98   the remote workspace has no .env: pass --no-env if setup has not written it yet
  124  a time limit cut the call
  129, 130, 143  the call was ended by SIGHUP, SIGINT, or SIGTERM
  255  ssh itself failed
Every remote command gets VRL_REMOTE=1, which launch_run.sh, resources.sh, and gpu_hours.py need on the
local machine of a remote-mode workspace, since that machine runs no code.
The control socket lives in a folder only you can open: $XDG_RUNTIME_DIR/vrl-ssh, ~/.cache/vrl-ssh,
or /tmp/vrl-ssh-<uid>, the first short enough for a socket path. Needs bash 3.2 or later; the remote
login shell must be of the sh family, such as bash, zsh, or dash.
EOF
}

main() {
	set -uo pipefail
	TMP_FILES=() CUR_PID="" CUR_WD="" ACTION="" LIMIT=0 DEADLINE=0
	# The exit marker goes to fd 3, the call's own output, even while a step's output is redirected.
	exec 3>&1
	trap 'cleanup' EXIT
	trap 'on_signal 129' HUP
	trap 'on_signal 130' INT
	trap 'on_signal 143' TERM

	ACTION="${1:-}"
	case "$ACTION" in
		resolve | check | connect | run | script | sync | read | fetch) shift ;;
		"" | -h | --help) NO_MARKER=1; usage; return 0 ;;
		*) err "Unknown action: $ACTION"; return 2 ;;
	esac
	ALIAS="${1:-}"
	case "$ALIAS" in
		"" | -* | *[!A-Za-z0-9._-]*) err "Give the SSH alias, a Host entry of ~/.ssh/config, after the action: letters, digits, ., -, and _ only"; return 2 ;;
	esac
	shift

	WORKSPACE="" STEP_LIMIT="" NO_ENV=0 LINES_WANTED=100 MAX_MB=20
	while [ $# -gt 0 ]; do
		case "$1" in
			--workspace) WORKSPACE="${2:-}"; shift ;;
			--limit) LIMIT="${2:-}"; LIMIT_GIVEN=1; shift ;;
			--lines) LINES_WANTED="${2:-}"; shift ;;
			--max-mb) MAX_MB="${2:-}"; shift ;;
			--step-limit) STEP_LIMIT="${2:-}"; shift ;;
			--no-env) NO_ENV=1 ;;
			--) shift; break ;;
			*) err "Unknown argument: $1"; return 2 ;;
		esac
		shift
	done

	# Check the limits as text before any arithmetic, which would evaluate them.
	case "$LIMIT" in "" | *[!0-9]*) err "--limit takes whole seconds"; return 2 ;; esac
	case "$STEP_LIMIT" in *[!0-9]*) err "--step-limit takes whole seconds"; return 2 ;; esac
	case "$LINES_WANTED" in "" | *[!0-9]*) err "--lines takes a whole number"; return 2 ;; esac
	case "$MAX_MB" in "" | *[!0-9]*) err "--max-mb takes whole MB"; return 2 ;; esac
	LINES_WANTED=$((10#$LINES_WANTED)) MAX_MB=$((10#$MAX_MB))
	[ "$LINES_WANTED" -ge 1 ] && [ "$LINES_WANTED" -le 2000 ] || { err "--lines takes 1 to 2000"; return 2; }
	[ "$MAX_MB" -ge 1 ] && [ "$MAX_MB" -le 200 ] || { err "--max-mb takes 1 to 200"; return 2; }
	if [ -z "${LIMIT_GIVEN:-}" ]; then
		case "$ACTION" in
			check | connect) LIMIT=15 ;;
			*) LIMIT=60 ;;
		esac
	fi
	LIMIT=$((10#$LIMIT))
	if [ -z "$STEP_LIMIT" ]; then
		if [ "$LIMIT" -gt 10 ]; then STEP_LIMIT=$((LIMIT - 10)); elif [ "$LIMIT" -gt 1 ]; then STEP_LIMIT=$((LIMIT - 1)); else STEP_LIMIT=$LIMIT; fi
	fi
	STEP_LIMIT=$((10#$STEP_LIMIT))
	if [ "$LIMIT" -gt 0 ]; then DEADLINE=$(($(date +%s) + LIMIT)); fi
	case "$WORKSPACE" in
		"" | /*) ;;
		*) err "--workspace must be an absolute path on the remote host"; return 2 ;;
	esac
	case "$WORKSPACE" in *"
"*) err "--workspace holds one line"; return 2 ;; esac

	check_alias || return 2
	TIMEOUT=""
	if command -v timeout >/dev/null 2>&1; then TIMEOUT=timeout
	elif command -v gtimeout >/dev/null 2>&1; then TIMEOUT=gtimeout; fi
	SCRIPT_DIR="$(script_dir)" || return 2

	sock_dir || return 2
	SOCK="$SOCK_DIR/%C"
	MASTER=(ssh -MNf -o ControlMaster=yes -o ControlPersist=4h -o "ControlPath=$SOCK" -o ServerAliveInterval=15
		-o ServerAliveCountMax=3 -o ConnectTimeout=10 -o ForwardAgent=no -o ForwardX11=no -o ClearAllForwardings=yes
		-o PermitLocalCommand=no)
	# The socket's own path, as the master expands it; clients name it literally, since their
	# ProxyCommand=false would change what %C expands to.
	SOCK_PATH="$(ssh -G -o "ControlPath=$SOCK" "$ALIAS" 2>/dev/null | awk '$1 == "controlpath" { print $2; exit }')"
	[ -n "$SOCK_PATH" ] || { err "ssh -G could not resolve $ALIAS"; return 2; }
	SSH=(ssh -o BatchMode=yes -o ConnectTimeout=10 -o ControlMaster=no -o ProxyCommand=false -S "$SOCK_PATH")

	case "$ACTION" in
		resolve) resolve ;;
		check) check_connection ;;
		connect) connect ;;
		run)
			[ -n "$WORKSPACE" ] || { err "run needs --workspace"; return 2; }
			[ $# -eq 1 ] || { err "Give the command as one quoted string after --"; return 2; }
			need_master || return
			run_command "$1"
			;;
		script)
			[ $# -ge 1 ] || { err "Give the script after --"; return 2; }
			need_master || return
			run_script "$@"
			;;
		sync) sync_paths "$@" ;;
		read) read_remote "$@" ;;
		fetch) fetch_files "$@" ;;
	esac
}

err() { printf 'vrl_ssh: %s\n' "$*" >&2; }

# shellcheck disable=SC2329 # The EXIT trap calls it.
cleanup() {
	local f
	for f in "${TMP_FILES[@]+"${TMP_FILES[@]}"}"; do rm -f "$f"; done
}

# shellcheck disable=SC2329 # The signal traps call it.
on_signal() {
	[ -z "$CUR_PID" ] || kill -TERM "$CUR_PID" 2>/dev/null
	[ -z "$CUR_WD" ] || kill "$CUR_WD" 2>/dev/null
	printf '\n__EXIT %s\n' "$1" >&3
	NO_MARKER=1
	exit "$1"
}

# Sets NEW_TMP to a new temp file that cleanup deletes.
new_tmp() {
	NEW_TMP="$(mktemp "${TMPDIR:-/tmp}/vrl-ssh.XXXXXX")" || { err "Could not create a temp file"; return 1; }
	TMP_FILES+=("$NEW_TMP")
}

# Quote a string for any shell of the sh family, the remote login shell included.
sq() {
	local s=${1//\'/\'\\\'\'}
	printf "'%s'" "$s"
}

# The folder of this script, with symlinks resolved, so that `script` ships only the scripts beside it.
script_dir() {
	local f="${BASH_SOURCE[0]}" d
	while [ -L "$f" ]; do
		d="$(cd "$(dirname "$f")" && pwd -P)"
		f="$(readlink "$f")"
		case "$f" in /*) ;; *) f="$d/$f" ;; esac
	done
	cd "$(dirname "$f")" 2>/dev/null && pwd -P
}

# The alias must match a Host line of ~/.ssh/config or a file it includes, and, where the rules name
# one, be the rules' alias.
check_alias() {
	local files f inc rules count token found=0
	files="$(ls -d ~/.ssh/config 2>/dev/null)"
	for inc in $(awk 'tolower($1) == "include" { for (i = 2; i <= NF; i++) print $i }' ~/.ssh/config 2>/dev/null); do
		case "$inc" in /* | "~"*) ;; *) inc="$HOME/.ssh/$inc" ;; esac
		inc="${inc/#\~/$HOME}"
		# The include may be a glob, such as config.d/*.
		for f in $inc; do [ -f "$f" ] && files="$files
$f"; done
	done
	while IFS= read -r f; do
		[ -n "$f" ] || continue
		for token in $(awk 'tolower($1) == "host" { for (i = 2; i <= NF; i++) print $i }' "$f" 2>/dev/null); do
			case "$token" in "!"*) continue ;; esac
			# shellcheck disable=SC2254 # A Host token is a glob pattern.
			case "$ALIAS" in $token) found=1 ;; esac
		done
	done <<EOF
$files
EOF
	if [ "$found" = 0 ]; then
		err "$ALIAS matches no Host line of ~/.ssh/config: ask the user, as remote_prompts.md says"
		return 1
	fi
	[ -e docs/AGENTS/remote.md ] || return 0
	[ -f docs/AGENTS/remote.md ] || { err "docs/AGENTS/remote.md is not a file"; return 1; }
	# The line that names the remote host holds both code spans, `ssh <alias>` and `Host <alias>`.
	rules="$(sed -n 's/.*`ssh \([A-Za-z0-9._-]*\)`.*`Host \1`.*/\1/p' docs/AGENTS/remote.md | sort -u)"
	count="$(printf '%s\n' "$rules" | grep -c .)"
	if [ "$count" != 1 ]; then
		err "docs/AGENTS/remote.md must name the remote host on one line, as \`ssh <alias>\` and \`Host <alias>\`"
		return 1
	fi
	[ "$rules" = "$ALIAS" ] || { err "docs/AGENTS/remote.md names the alias $rules, not $ALIAS"; return 1; }
}

# The seconds left of the call's limit, at least 1; 0 when the call has no limit.
remaining() {
	if [ "$DEADLINE" = 0 ]; then echo 0; return; fi
	local left=$((DEADLINE - $(date +%s)))
	[ "$left" -ge 1 ] || left=1
	echo "$left"
}

# with_limit <input file> <command...>: run the command with that input until the call's deadline
# (SIGTERM, then SIGKILL 5 seconds later), and return 124 if the deadline cut it. It runs in the
# background, so that a signal to this script is handled at once, and without fd 3.
with_limit() {
	local input="$1" limit rc flag=""
	shift
	limit="$(remaining)"
	if [ "$limit" = 0 ]; then
		"$@" <"$input" 3>&- &
		CUR_PID=$!
	elif [ -n "$TIMEOUT" ]; then
		"$TIMEOUT" -k 5 "$limit" "$@" <"$input" 3>&- &
		CUR_PID=$!
	else
		# Neither timeout nor gtimeout, as on macOS without Homebrew's coreutils: a watchdog does the same.
		# Its output goes to /dev/null, so that its leftover sleep cannot hold the agent's shell open.
		new_tmp || return 1
		flag="$NEW_TMP"
		rm -f "$flag"
		"$@" <"$input" 3>&- &
		CUR_PID=$!
		(
			sleep "$limit"
			: >"$flag"
			kill -TERM "$CUR_PID" 2>/dev/null
			sleep 5
			kill -KILL "$CUR_PID" 2>/dev/null
		) >/dev/null 2>&1 </dev/null 3>&- &
		CUR_WD=$!
	fi
	wait "$CUR_PID" 2>/dev/null
	rc=$?
	if [ -n "$CUR_WD" ]; then
		kill "$CUR_WD" 2>/dev/null
		wait "$CUR_WD" 2>/dev/null
	fi
	if [ -n "$flag" ] && [ -e "$flag" ]; then rc=124
	elif [ -n "$TIMEOUT" ] && [ "$rc" = 137 ] && [ "$DEADLINE" != 0 ] && [ "$(date +%s)" -ge "$DEADLINE" ]; then rc=124; fi
	CUR_PID="" CUR_WD=""
	return "$rc"
}

# The folder of the control socket: this user's, mode 700, not a symlink, short enough for a socket
# path of 104 bytes with the hash and ssh's temporary suffix.
sock_dir() {
	local d
	for d in "${XDG_RUNTIME_DIR:+$XDG_RUNTIME_DIR/vrl-ssh}" "${HOME:+$HOME/.cache/vrl-ssh}" "/tmp/vrl-ssh-$(id -u)"; do
		[ -n "$d" ] && [ $((${#d} + 60)) -le 100 ] || continue
		[ -e "$d" ] || { mkdir -p "$(dirname "$d")" && mkdir -m 700 "$d"; } 2>/dev/null || continue
		if [ -d "$d" ] && [ ! -L "$d" ] && [ -O "$d" ]; then
			chmod 700 "$d" 2>/dev/null
			SOCK_DIR="$d"
			return 0
		fi
	done
	err "No folder of yours for the control socket: ~/.cache/vrl-ssh and /tmp/vrl-ssh-$(id -u) are missing, not yours, or symlinks"
	return 1
}

resolve() {
	local conf host
	conf="$(ssh -G "$ALIAS" 2>/dev/null)" || { err "ssh -G could not resolve $ALIAS"; return 1; }
	printf '%s\n' "$conf" | awk '$1 == "hostname" || $1 == "user" || $1 == "port" || $1 == "proxyjump" { print $1 ": " $2 }'
	host="$(printf '%s\n' "$conf" | awk '$1 == "hostname" { print $2; exit }')"
	[ "$host" != "$ALIAS" ] || printf 'note: the host name equals the alias\n'
}

# Sets MASTER_PID to the PID of the master behind the socket, from `ssh -O check`. Returns 0 when one
# answers, 6 when none is up, and 124 when the check itself hung.
master_check() {
	local out rc
	MASTER_PID=""
	new_tmp || return 1
	out="$NEW_TMP"
	with_limit /dev/null ssh -S "$SOCK_PATH" -O check "$ALIAS" >"$out" 2>&1
	rc=$?
	[ "$rc" = 124 ] && return 124
	[ "$rc" = 0 ] || return 6
	MASTER_PID="$(sed -n 's/.*pid=\([0-9][0-9]*\).*/\1/p' "$out")"
}

need_master() {
	local rc
	master_check
	rc=$?
	case "$rc" in
		0) return 0 ;;
		124) err "The master does not answer its socket: run connect"; return 7 ;;
		*) err "No master is up for $ALIAS: run connect first"; return 6 ;;
	esac
}

# One round trip through the master; `ssh -O check` only sees that the local master process exists.
round_trip() {
	local start rc
	start="$(date +%s)"
	with_limit /dev/null "${SSH[@]}" -n "$ALIAS" true
	rc=$?
	ROUND_TRIP_SECONDS=$(($(date +%s) - start))
	return "$rc"
}

check_connection() {
	local rc
	master_check
	rc=$?
	case "$rc" in
		0) ;;
		124) printf 'connection: the master does not answer its socket\n'; return 7 ;;
		*) printf 'connection: no master is up for %s\n' "$ALIAS"; return 6 ;;
	esac
	round_trip
	rc=$?
	if [ "$rc" -ne 0 ]; then
		printf 'connection: %s does not answer through the master\n' "$ALIAS"
		[ "$rc" = 124 ] && return 124
		return 1
	fi
	printf 'connection: %s answers through the master (%s s)\n' "$ALIAS" "$ROUND_TRIP_SECONDS"
}

# The PIDs of masters this script started for the alias: their command line is MASTER's, exactly.
own_masters() {
	local pattern
	# The command line as a literal, with the characters that extended regexes treat as special escaped;
	# a master the user started in their own terminal, without BatchMode, matches too.
	pattern="$(printf '%s' "${MASTER[*]}" | sed 's/[][\\.*^$+?(){}|]/\\&/g')( -o BatchMode=yes)? $(printf '%s' "$ALIAS" | sed 's/[.]/\\./g')"
	pgrep -U "$(id -u)" -f -- "^$pattern\$" 2>/dev/null
}

connect() {
	local errors rc p saved="$DEADLINE"
	# The first look gets at most a third of the limit, and 5 seconds, so that a hung master leaves time
	# to start a new one.
	if [ "$DEADLINE" != 0 ]; then
		local first=$((LIMIT / 3))
		[ "$first" -le 5 ] || first=5
		[ "$first" -ge 1 ] || first=1
		DEADLINE=$(($(date +%s) + first))
	fi
	if master_check && round_trip; then
		DEADLINE="$saved"
		printf 'connection: %s answers through the master (%s s)\n' "$ALIAS" "$ROUND_TRIP_SECONDS"
		return 0
	fi
	DEADLINE="$saved"
	printf 'connection: no answer; closing the old master\n'
	with_limit /dev/null ssh -S "$SOCK_PATH" -O exit "$ALIAS" >/dev/null 2>&1
	sleep 1
	for p in $MASTER_PID $(own_masters); do
		kill "$p" 2>/dev/null
	done
	# A socket left behind makes the new master skip multiplexing without failing.
	if [ -S "$SOCK_PATH" ] && [ -O "$SOCK_PATH" ]; then rm -f "$SOCK_PATH"; fi

	printf 'connection: starting a new master\n'
	new_tmp || return 1
	errors="$NEW_TMP"
	# Its output goes to a file, not to the agent's shell, since the master stays in the background.
	with_limit /dev/null "${MASTER[@]}" -o BatchMode=yes "$ALIAS" >/dev/null 2>"$errors"
	rc=$?
	if [ "$rc" -ne 0 ]; then
		sed 's/^/ssh: /' "$errors" >&2
		if grep -qiE 'host key|IDENTIFICATION HAS CHANGED' "$errors"; then
			err "The host key could not be verified. Stop and report to the user; never turn off host-key checking."
			return 5
		fi
		if grep -qiE 'Permission denied|passphrase|password|keyboard-interactive|verification code' "$errors"; then
			err "The login needs the user. Ask them to run this in their own terminal, then run connect again:"
			printf '  %s %s\n' "${MASTER[*]}" "$ALIAS" >&2
			return 3
		fi
		err "The master did not start: $ALIAS is unreachable"
		[ "$rc" = 124 ] && return 124
		[ "$rc" = 255 ] && return 255
		return 1
	fi
	round_trip
	rc=$?
	if [ "$rc" = 0 ]; then
		printf 'connection: %s answers through the new master (%s s)\n' "$ALIAS" "$ROUND_TRIP_SECONDS"
		return 0
	fi
	err "The new master started, but $ALIAS does not answer through it"
	[ "$rc" = 124 ] && return 124
	return 1
}

# The remote command line: enter the workspace and load its .env, then run the interpreter on the
# standard input under the remote step limit.
remote_line() {
	local interpreter="$1" line='PATH="$HOME/.local/bin:$PATH"; VRL_REMOTE=1; export PATH VRL_REMOTE; '
	if [ -n "$WORKSPACE" ]; then
		line="${line}cd $(sq "$WORKSPACE") && "
		if [ "$NO_ENV" = 0 ]; then
			# .env is read as literal NAME=value lines, never run, as launch_run.sh reads it.
			line="$line{ [ -f .env ] || { echo 'vrl_ssh: the workspace has no .env; pass --no-env if setup has not written it yet' >&2; exit 98; }; } && "
			line="$line"'while IFS= read -r _vrl_l || [ -n "$_vrl_l" ]; do _vrl_l=${_vrl_l%"$(printf "\r")"}; case "$_vrl_l" in ""|"#"*) continue;; esac; _vrl_n=${_vrl_l%%=*}; case "$_vrl_n" in "$_vrl_l"|""|[0-9]*|*[!A-Za-z0-9_]*|_vrl_*|LD_*|DYLD_*|BASH_*|ENV|HOME|PATH|CDPATH|IFS|PS4|PROMPT_COMMAND|GLOBIGNORE|SHELLOPTS|BASHOPTS|POSIXLY_CORRECT|PYTHONSTARTUP|PYTHONHOME|PYTHONINSPECT|PERL5OPT|PERL5LIB|PERLLIB|RUBYOPT|NODE_OPTIONS|JAVA_TOOL_OPTIONS|_JAVA_OPTIONS) continue;; esac; _vrl_v=${_vrl_l#*=}; case "$_vrl_v" in \"*\") _vrl_v=${_vrl_v#\"}; _vrl_v=${_vrl_v%\"};; \'"'"'*\'"'"') _vrl_v=${_vrl_v#\'"'"'}; _vrl_v=${_vrl_v%\'"'"'};; esac; export "$_vrl_n=$_vrl_v"; done < .env && unset _vrl_l _vrl_n _vrl_v CDPATH && '
		fi
	fi
	if [ "$STEP_LIMIT" = 0 ]; then
		line="${line}exec $interpreter"
	else
		line="${line}if command -v timeout >/dev/null 2>&1; then exec timeout -k 5 $STEP_LIMIT $interpreter; else exec $interpreter; fi"
	fi
	printf '%s' "$line"
}

run_command() {
	local input
	new_tmp || return 1
	input="$NEW_TMP"
	# The braces give the command no input, so that nothing it runs reads the rest of the stream.
	{
		printf '{\n'
		printf '%s\n' "$1"
		printf '} </dev/null\n'
	} >"$input"
	with_limit "$input" "${SSH[@]}" "$ALIAS" "$(remote_line 'bash -s')"
}

run_script() {
	local name="$1" file interpreter arg input
	shift
	case "$name" in
		launch_run.sh | resources.sh | gpu_hours.py | setup_clis.sh | */launch_run.sh | */resources.sh | */gpu_hours.py | */setup_clis.sh) ;;
		*) err "script runs only launch_run.sh, resources.sh, gpu_hours.py, or setup_clis.sh"; return 2 ;;
	esac
	file="$SCRIPT_DIR/$(basename "$name")"
	if [ ! -f "$file" ] || [ -L "$file" ] || [ ! -O "$file" ]; then
		err "$(basename "$name") next to vrl_ssh.sh is missing, a symlink, or not yours"
		return 2
	fi
	new_tmp || return 1
	input="$NEW_TMP"
	case "$file" in
		*.py)
			interpreter="python3 -"
			cat "$file" >"$input"
			;;
		*)
			interpreter="bash -s --"
			# The braces keep a command in the script from reading the rest of it as its input.
			{ printf '{\n'; cat "$file"; printf '\n} </dev/null\n'; } >"$input"
			;;
	esac
	for arg in "$@"; do interpreter="$interpreter $(sq "$arg")"; done
	with_limit "$input" "${SSH[@]}" "$ALIAS" "$(remote_line "$interpreter")"
}

# The checkouts sync may name: `.`, the workspace repository; a folder at the workspace root; and
# worktrees/<name> or ref_repos/<name>. launch_run.sh checks the same on the remote host.
checkout_form() {
	case "$1" in
		.) return 0 ;;
		worktrees/* | ref_repos/*)
			case "${1#*/}" in "" | [!A-Za-z0-9_]* | *[!A-Za-z0-9._-]*) return 1 ;; esac
			return 0
			;;
		docs | logs | runs | data | tmp | tests | worktrees | ref_repos) return 1 ;;
		"" | [!A-Za-z0-9_]* | *[!A-Za-z0-9._-]*) return 1 ;;
	esac
	return 0
}

# git here, without the repository's hooks or fsmonitor.
lgit() {
	local dir="$1"
	shift
	git -C "$dir" -c core.fsmonitor= -c core.hooksPath=/dev/null -c core.quotepath=off -c color.ui=false "$@"
}

sync_paths() {
	local p rc
	[ -n "$WORKSPACE" ] || { err "sync needs --workspace"; return 2; }
	case "$WORKSPACE" in *:*) err "sync needs a remote workspace path without a colon"; return 2 ;; esac
	[ $# -ge 1 ] || { err "Give the checkouts to sync after --, such as . or main_repo"; return 2; }
	[ -d docs/AGENTS ] || { err "Run sync from the workspace root, the folder that holds docs/AGENTS/"; return 2; }
	for p in "$@"; do
		checkout_form "$p" || { err "Not a checkout sync may name: $p (., a folder at the workspace root, worktrees/<name>, or ref_repos/<name>)"; return 2; }
	done
	need_master || return
	# Sync never reads the remote .env: it needs none, and runs before setup writes it.
	NO_ENV=1
	for p in "$@"; do
		sync_one "$p"
		rc=$?
		[ "$rc" = 0 ] || return "$rc"
	done
}

# Sync one checkout: check it here, make sure its mirror exists, push its commit there through the
# master, then check it out on the remote host.
sync_one() {
	local p="$1" here top commit branch dirty git_dir common owner="" slug repo target trace rc
	here="$(pwd -P)"
	top="$(lgit "$p" rev-parse --show-toplevel 2>/dev/null)" && [ "$(cd "$top" && pwd -P)" = "$(cd "$p" && pwd -P)" ] ||
		{ err "$p is not the top of a git checkout"; return 3; }
	commit="$(lgit "$p" rev-parse -q --verify 'HEAD^{commit}' 2>/dev/null)" || { err "$p has no commit yet"; return 3; }
	dirty="$(lgit "$p" status --porcelain --untracked-files=normal 2>/dev/null)" || { err "git status failed in $p"; return 3; }
	if [ -n "$dirty" ]; then
		err "$p has changes that are not committed, and only commits are copied: commit them first, as the git rules allow, then sync again."
		printf '%s\n' "$dirty" | head -n 40 >&2
		return 3
	fi
	if lgit "$p" ls-files -s | awk '$1 == "160000" { n++ } END { exit !n }'; then
		err "$p has submodules, which sync does not copy"
		return 3
	fi
	if lgit "$p" ls-files -z | lgit "$p" check-attr --stdin -z filter | tr '\0' '\n' | awk 'NR % 3 == 0 && $0 == "lfs" { n++ } END { exit !n }'; then
		err "$p has Git LFS files, which sync does not copy: keep large files under data/ on the remote host"
		return 3
	fi
	# Traces of code run here: the local machine runs none.
	trace="$(find "$p" -name .git -prune -o -type d \( -name .venv -o -name venv -o -name __pycache__ -o -name .pytest_cache -o -name .ipynb_checkpoints \) -print 2>/dev/null | head -n 1)"
	[ -z "$trace" ] || printf 'note: %s exists, as if code ran on this machine, which runs no code in remote mode: tell the user\n' "$trace"

	# A worktree's commits live in the repository of the checkout that owns it.
	git_dir="$(cd "$p" && cd "$(lgit . rev-parse --git-dir)" && pwd -P)" || return 3
	common="$(cd "$p" && cd "$(lgit . rev-parse --git-common-dir)" && pwd -P)" || return 3
	if [ "$git_dir" != "$common" ]; then
		case "$common" in */.git) owner="${common%/.git}" ;; *) err "$p is a worktree of a bare repository"; return 3 ;; esac
		case "$owner" in
			"$here") owner="." ;;
			"$here"/*) owner="${owner#"$here"/}" ;;
			*) err "$p is a worktree of a repository outside the workspace"; return 3 ;;
		esac
		checkout_form "$owner" || { err "$p is a worktree of $owner, which sync cannot name"; return 3; }
	fi
	repo="${owner:-$p}"
	branch="$(lgit "$p" rev-parse --abbrev-ref HEAD 2>/dev/null)"
	if [ "$p" = . ]; then slug=workspace; else slug="$(printf '%s' "$p" | sed 's|/|--|g')"; fi

	run_script launch_run.sh --sync-prepare "$repo" || { rc=$?; sync_rc "$rc" "preparing the mirror of $repo"; return; }
	if [ "$repo" = . ]; then target="$WORKSPACE"; else target="$WORKSPACE/$repo"; fi
	with_limit /dev/null env GIT_SSH_VARIANT=ssh \
		GIT_SSH_COMMAND="ssh -o BatchMode=yes -o ConnectTimeout=10 -o ControlMaster=no -o ProxyCommand=false -S $(sq "$SOCK_PATH")" \
		git -C "$p" -c core.fsmonitor= -c core.hooksPath=/dev/null push -q --no-verify --force \
		--receive-pack='PATH="$HOME/.local/bin:$PATH" git receive-pack' "$ALIAS:$target" "${commit}:refs/vrl/$slug"
	rc=$?
	[ "$rc" = 0 ] || { sync_rc "$rc" "copying the commits of $p"; return; }
	run_script launch_run.sh --sync-apply "$p" --commit "$commit" --branch "$branch" ${owner:+--owner "$owner"} ||
		{ rc=$?; sync_rc "$rc" "checking out $p on the remote host"; return; }
}

# The exit code of a failed sync step: a refusal stays 3, a cut call 124, and a lost connection 255;
# anything else is 4.
sync_rc() {
	case "$1" in
		3) return 3 ;;
		124 | 129 | 130 | 143 | 255) err "The sync stopped while $2"; return "$1" ;;
		*) err "The sync failed while $2, with exit code $1"; return 4 ;;
	esac
}

# A path under logs/, runs/, or tmp/ of the remote workspace, with no `..` and nothing to quote.
result_path() {
	case "$1" in
		logs | runs | tmp | logs/* | runs/* | tmp/*) ;;
		*) return 1 ;;
	esac
	case "/$1/" in */../* | */./* | *//*) return 1 ;; esac
	case "$1" in *[!A-Za-z0-9._/@+=-]*) return 1 ;; esac
}

# The remote lines that refuse a path whose folder leads outside its top folder through a symlink.
# A top folder that is itself a symlink, such as runs/ on a scratch disk, is fine.
inside_check() {
	cat <<'EOF'
top=${p%%/*}
[ -e "$p" ] || { echo "vrl_ssh: no such file or folder in the remote workspace: $p" >&2; exit 3; }
root=$(cd "$top" && pwd -P) || exit 3
if [ -d "$p" ]; then dir=$(cd "$p" && pwd -P); else dir=$(cd "$(dirname "$p")" && pwd -P); fi || exit 3
case "$dir/" in "$root"/*) ;; *) echo "vrl_ssh: $p leads outside $top/ through a symlink" >&2; exit 3 ;; esac
EOF
}

# The rest of read's remote lines, after inside_check.
read_lines() {
	cat <<'EOF'
if [ -d "$p" ]; then ls -lA -- "$p" | head -n 500; exit 0; fi
case "${p##*/}" in .env*) echo "vrl_ssh: read never prints a .env file" >&2; exit 3 ;; esac
{ [ -f "$p" ] && [ ! -L "$p" ]; } || { echo "vrl_ssh: not a regular file: $p" >&2; exit 3; }
[ "$(head -c 8192 "$p" | wc -c)" = "$(head -c 8192 "$p" | tr -d '\000' | wc -c)" ] || { echo "vrl_ssh: $p is not a text file" >&2; exit 3; }
tail -n "$n" -- "$p" | head -c 65536
EOF
}

read_remote() {
	[ -n "$WORKSPACE" ] || { err "read needs --workspace"; return 2; }
	[ $# -eq 1 ] || { err "Give one path after --"; return 2; }
	result_path "$1" || { err "read takes a path under logs/, runs/, or tmp/, with no .. and only letters, digits, and ._/@+=-"; return 2; }
	need_master || return
	NO_ENV=1
	run_command "p=$(sq "$1"); n=$LINES_WANTED
$(inside_check)
$(read_lines)"
}

# The rest of fetch's remote lines, after inside_check: the marker, then the file's bytes.
fetch_lines() {
	cat <<'EOF'
{ [ -f "$p" ] && [ ! -L "$p" ]; } || { echo "vrl_ssh: not a regular file: $p" >&2; exit 3; }
printf '%s\n' "$m"
exec head -c $((c + 1)) -- "$p"
EOF
}

# The kind of file fetch accepts for a path, by its name: png, jpg, svg, pdf, or lock.
fetch_kind() {
	case "$1" in
		tmp/fetched | tmp/fetched/*) return 1 ;;
		tmp/*/uv.lock | tmp/uv.lock) echo lock ;;
		runs/*.png | tmp/*.png) echo png ;;
		runs/*.jpg | runs/*.jpeg | tmp/*.jpg | tmp/*.jpeg) echo jpg ;;
		runs/*.svg | tmp/*.svg) echo svg ;;
		runs/*.pdf | tmp/*.pdf) echo pdf ;;
		*) return 1 ;;
	esac
}

fetch_files() {
	local p kind out raw cap marker size d rc head
	[ -n "$WORKSPACE" ] || { err "fetch needs --workspace"; return 2; }
	[ $# -ge 1 ] && [ $# -le 10 ] || { err "Give 1 to 10 paths after --"; return 2; }
	[ -d docs/AGENTS ] || { err "Run fetch from the workspace root, the folder that holds docs/AGENTS/"; return 2; }
	for p in "$@"; do
		result_path "$p" && fetch_kind "$p" >/dev/null ||
			{ err "fetch takes figures (.png, .jpg, .jpeg, .svg, .pdf) under runs/ or tmp/, or a uv.lock under tmp/: $p"; return 2; }
	done
	for d in tmp tmp/fetched; do
		if [ -L "$d" ] || { [ -e "$d" ] && [ ! -d "$d" ]; }; then err "$d here is a symlink or not a folder"; return 3; fi
	done
	mkdir -p tmp/fetched && chmod 700 tmp/fetched || { err "Could not create tmp/fetched here"; return 4; }
	need_master || return
	NO_ENV=1
	cap=$((MAX_MB * 1048576))
	for p in "$@"; do
		kind="$(fetch_kind "$p")"
		# A marker line before the bytes, so that anything the remote login prints first is cut off.
		marker="VRL-FETCH-$(od -An -N8 -tx1 /dev/urandom | tr -d ' \n')"
		new_tmp || return 1
		raw="$NEW_TMP"
		new_tmp || return 1
		out="$NEW_TMP"
		run_command "p=$(sq "$p"); c=$cap; m=$(sq "$marker")
$(inside_check)
$(fetch_lines)" >"$raw"
		rc=$?
		case "$rc" in
			0) ;;
			3) return 3 ;;
			124 | 129 | 130 | 143 | 255) err "The fetch of $p stopped"; return "$rc" ;;
			*) err "The fetch of $p failed, with exit code $rc"; return 4 ;;
		esac
		VRL_MARKER="$marker" perl -e 'local $/; my $d = <STDIN>; my $m = "$ENV{VRL_MARKER}\n"; my $i = index($d, $m); exit 3 if $i < 0; print substr($d, $i + length($m));' <"$raw" >"$out" ||
			{ err "The fetch of $p returned no file"; return 4; }
		size="$(wc -c <"$out" | tr -d ' ')"
		[ "$size" -le "$cap" ] || { err "$p is larger than --max-mb $MAX_MB"; return 3; }
		head="$(head -c 8 "$out" | od -An -tx1 | tr -d ' \n')"
		case "$kind" in
			png) [ "$head" = 89504e470d0a1a0a ] ;;
			jpg) case "$head" in ffd8ff*) true ;; *) false ;; esac ;;
			pdf) case "$head" in 255044462d*) true ;; *) false ;; esac ;;
			svg | lock) [ "$(head -c 65536 "$out" | wc -c)" = "$(head -c 65536 "$out" | tr -d '\000' | wc -c)" ] &&
				{ [ "$kind" = lock ] || head -c 65536 "$out" | grep -q '<svg'; } ;;
		esac || { err "$p is not the $kind file its name says"; return 3; }
		d="tmp/fetched/$p"
		mkdir -p "$(dirname "$d")" || return 4
		if [ -L "$d" ] || { [ -e "$d" ] && [ ! -f "$d" ]; }; then err "$d here is a symlink or not a file"; return 3; fi
		chmod 600 "$out" && mv -f "$out" "$d" || { err "Could not write $d"; return 4; }
		printf 'fetched %s to %s (%s bytes)\n' "$p" "$d" "$size"
	done
	# Fetched copies are scratch: delete them once uploaded; any left after 7 days go here.
	find tmp/fetched -type f -mtime +7 -exec rm -f {} + 2>/dev/null
	return 0
}

NO_MARKER=0
main "$@"
rc=$?
[ "$rc" != 124 ] || err "the time limit of $LIMIT s cut the call"
[ "$NO_MARKER" = 1 ] || printf '\n__EXIT %s\n' "$rc" >&3
exit "$rc"
