#!/usr/bin/env bash
# Reach the remote host of a remote-mode workspace through one SSH master, with the time limits,
# options, and exit marker that docs/AGENTS/remote.md asks for, so that no call hangs, no command
# needs quoting, and no call logs in by itself.
#
# Everything runs inside main(), so that bash reads the whole script before running it.

usage() {
	cat <<'EOF'
Usage: vrl_ssh.sh <action> <alias> [options] [-- <command> | -- <script> [args...]]

Actions:
  resolve   Print the host name, user, port, and jump host the alias resolves to, without connecting.
  check     Check that the master is up and the remote host answers through it; print the time the
            round trip took. With --mount, also check that `mount` lists that folder, without
            touching the folder.
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
  mount     Mount the remote workspace at --mount with SSHFS through the master, after unmounting a
            stale SSHFS mount of the same alias there.

Options:
  --workspace DIR  The remote workspace, as an absolute path. run needs it.
  --mount DIR      The mount folder: a plain folder right in the launch directory, the one that holds
                   docs/AGENTS/.
  --limit S        The time limit of the whole call, in seconds (default: 15 for check and connect,
                   30 for mount, 60 otherwise; 0 for none, as the setup script's login needs). Keep
                   it 5 seconds below the agent's own limit for a shell call.
  --step-limit S   The remote time limit of the command (default: --limit minus 10; 0 for none).
  --no-env         With --workspace: do not load its .env, as before setup has written it.

The alias must be a Host entry of ~/.ssh/config; when docs/AGENTS/remote.md exists here, it must be the
alias of the line that names both `ssh <alias>` and `Host <alias>`. No client logs in by itself: every
one goes through the master's socket, with ProxyCommand=false, so it fails when the master is gone.
Every call prints `__EXIT <code>` as its last line, on a line of its own. For run and script, the code
is the remote command's own, unless the line above it starts with `vrl_ssh:`. Exit codes:
  0    done; for run and script, the command's own exit code otherwise
  1    the remote host, or the master, does not answer: run connect, or stop and report
  2    bad arguments, or a folder or alias that the rules do not allow
  3    the login needs the user: they run the printed command in their own terminal
  4    check --mount: the mount is not listed
  5    the host key could not be verified: stop and report; never turn off host-key checking
  6    no master is up: run connect first
  7    the master hangs: run connect
  98   the remote workspace has no .env: pass --no-env if setup has not written it yet
  124  a time limit cut the call
  129, 130, 143  the call was ended by SIGHUP, SIGINT, or SIGTERM
  255  ssh itself failed
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
		resolve | check | connect | run | script | mount) shift ;;
		"" | -h | --help) NO_MARKER=1; usage; return 0 ;;
		*) err "Unknown action: $ACTION"; return 2 ;;
	esac
	ALIAS="${1:-}"
	case "$ALIAS" in
		"" | -* | *[!A-Za-z0-9._-]*) err "Give the SSH alias, a Host entry of ~/.ssh/config, after the action: letters, digits, ., -, and _ only"; return 2 ;;
	esac
	shift

	WORKSPACE="" MOUNT="" STEP_LIMIT="" NO_ENV=0
	while [ $# -gt 0 ]; do
		case "$1" in
			--workspace) WORKSPACE="${2:-}"; shift ;;
			--mount) MOUNT="${2:-}"; shift ;;
			--limit) LIMIT="${2:-}"; LIMIT_GIVEN=1; shift ;;
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
	if [ -z "${LIMIT_GIVEN:-}" ]; then
		case "$ACTION" in
			check | connect) LIMIT=15 ;;
			mount) LIMIT=30 ;;
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
		mount) mount_workspace ;;
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
	local rc path
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
	if [ -n "$MOUNT" ]; then
		path="$(mount_path)" || return 2
		if mount_entry "$path" >/dev/null; then
			printf 'mount: %s is listed\n' "$path"
		else
			printf 'mount: %s is not listed\n' "$path"
			return 4
		fi
	fi
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
	local interpreter="$1" line='PATH="$HOME/.local/bin:$PATH"; export PATH; '
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

# The absolute path of the mount folder: a plain, visible folder right in the launch directory, the
# one with docs/AGENTS/. Its parent is resolved, never the folder itself, so a dead mount is never touched.
mount_path() {
	local here name
	here="$(pwd -P)"
	[ -d docs/AGENTS ] || { err "Run this from the launch directory, the one that holds docs/AGENTS/"; return 1; }
	case "$MOUNT" in
		"$here"/*) name="${MOUNT#"$here"/}" ;;
		/*) err "The mount folder must sit right in the launch directory: $MOUNT"; return 1 ;;
		*) name="${MOUNT#./}" ;;
	esac
	case "$name" in
		"" | */* | .* | docs | *"
"*) err "The mount folder must be a plain folder name in the launch directory, not hidden: $MOUNT"; return 1 ;;
	esac
	printf '%s/%s' "$here" "$name"
}

# The `mount` line for a path, as macOS prints it, or Linux with its octal escapes. awk reads the
# whole table, so that no SIGPIPE cuts the listing short.
mount_entry() {
	local path="$1" table
	table="$(mount 2>/dev/null)"
	VRL_A=" on $path " VRL_B=" on $(printf '%s' "$path" | sed 's/\\/\\134/g; s/ /\\040/g; s/	/\\011/g') " \
		awk 'index($0, ENVIRON["VRL_A"]) || index($0, ENVIRON["VRL_B"]) { if (!found) print; found = 1 } END { exit !found }' <<EOF
$table
EOF
}

unmount() {
	case "$(uname -s)" in
		Linux) with_limit /dev/null fusermount -u "$1" ;;
		*) with_limit /dev/null umount "$1" ;;
	esac
}

mount_workspace() {
	local path entry rc
	[ -n "$WORKSPACE" ] && [ -n "$MOUNT" ] || { err "mount needs --workspace and --mount"; return 2; }
	path="$(mount_path)" || return 2
	need_master || return
	round_trip
	rc=$?
	[ "$rc" = 0 ] || { err "$ALIAS does not answer through the master: run connect first"; [ "$rc" = 124 ] && return 124; return 1; }
	if entry="$(mount_entry "$path")"; then
		case "$entry" in
			"$ALIAS:"*) ;;
			*) err "Something other than an SSHFS mount of $ALIAS is mounted at $path: stop and report"; return 1 ;;
		esac
		printf 'mount: unmounting the stale mount at %s\n' "$path"
		unmount "$path" || { err "Could not unmount $path; stop and report"; return 1; }
	fi
	if [ -L "$path" ] || [ ! -d "$path" ]; then
		err "The mount folder does not exist, or is a symlink: $path"
		return 2
	fi
	if [ -n "$(ls -A "$path" 2>/dev/null)" ]; then
		err "The mount folder is not empty: $path. Stop and report; never mount over files."
		return 2
	fi
	command -v sshfs >/dev/null 2>&1 || { err "sshfs is not installed on this machine"; return 2; }
	with_limit /dev/null sshfs \
		-o ssh_command="ssh -S $SOCK_PATH -o BatchMode=yes -o ControlMaster=no -o ProxyCommand=false" \
		-o reconnect,ServerAliveInterval=15,ServerAliveCountMax=3,idmap=user \
		"$ALIAS:$WORKSPACE" "$path"
	rc=$?
	[ "$rc" -eq 0 ] || return "$rc"
	if mount_entry "$path" >/dev/null; then
		printf 'mount: %s:%s is mounted at %s\n' "$ALIAS" "$WORKSPACE" "$path"
	else
		err "sshfs returned, but mount does not list $path; unmounting it"
		unmount "$path" >/dev/null 2>&1
		return 1
	fi
}

NO_MARKER=0
main "$@"
rc=$?
[ "$rc" != 124 ] || err "the time limit of $LIMIT s cut the call"
[ "$NO_MARKER" = 1 ] || printf '\n__EXIT %s\n' "$rc" >&3
exit "$rc"
