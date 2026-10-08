#!/usr/bin/env bash
# Reach the remote host of a remote-mode workspace through one SSH master, with the time limits, options,
# and exit marker that docs/AGENTS/remote.md asks for, so that no call hangs and no command needs quoting.
#
# Usage: vrl_ssh.sh <action> <alias> [options] [-- <command> | -- <script> [args...]]
#
#   resolve   Print the host name, user, port, and jump host that the alias resolves to, without connecting.
#   check     Make one round trip through the master and print how long it took. With --mount, also check
#             that `mount` lists that folder, without touching the folder itself.
#   connect   check; if it fails, close the dead master (ask it to exit, or else end its process and delete
#             its socket), start a new one, and check again. Never asks for a password: if the login needs
#             one, a passphrase, or a second factor, it prints the command for the user to run in their own
#             terminal, and exits 3.
#   run       Run a shell command in the remote workspace, with its .env loaded. The command is everything
#             after `--`, sent unchanged to a remote bash on its standard input, so it needs no quoting of
#             its own and may span several lines; the command itself gets no input.
#   script    Run a local script on the remote host, with the arguments after its path: a .py file with
#             python3, anything else with bash. With --workspace, it runs in the remote workspace with its
#             .env loaded; without, in the remote home directory, as the setup script needs.
#   mount     Mount the remote workspace at --mount with SSHFS through the master, after unmounting a stale
#             mount there.
#
# Options:
#   --workspace DIR  The remote workspace, as an absolute path. run needs it.
#   --mount DIR      The local mount folder, for check and mount.
#   --limit S        The local time limit of the call, in seconds (default: 15 for check and connect, 30 for
#                    mount, 60 otherwise; 0 for none). Keep it 5 seconds below the agent's own limit.
#   --step-limit S   The remote time limit of the command, in seconds (default: --limit minus 10; 0 for none).
#   --no-env         With --workspace: do not load its .env, as before setup has written it.
#
# Every action but resolve prints `__EXIT <code>` as its last line: 124 when a time limit cut the call, 255
# when ssh itself failed. Without that line, the call is still running or the agent's shell lost it.
# The control socket is /tmp/vrl-ssh-%C, as in docs/AGENTS/remote.md. Needs bash 3.2 or later; the remote
# login shell must be of the sh family, such as bash, zsh, or dash.
#
# Everything runs inside main(), so that bash reads the whole script before running it.

SOCK='/tmp/vrl-ssh-%C'

main() {
	set -uo pipefail

	local action="${1:-}"
	case "$action" in
		resolve | check | connect | run | script | mount) shift ;;
		"" | -h | --help) NO_MARKER=1; usage; return 0 ;;
		*) err "Unknown action: $action"; return 2 ;;
	esac
	ALIAS="${1:-}"
	case "$ALIAS" in
		"" | -*) err "Give the SSH alias after the action"; return 2 ;;
	esac
	case "$ALIAS" in
		*[!A-Za-z0-9._@-]*) err "Not an SSH alias: $ALIAS"; return 2 ;;
	esac
	shift

	WORKSPACE="" MOUNT="" LIMIT="" STEP_LIMIT="" NO_ENV=0
	while [ $# -gt 0 ]; do
		case "$1" in
			--workspace) WORKSPACE="${2:-}"; shift ;;
			--workspace=*) WORKSPACE="${1#--workspace=}" ;;
			--mount) MOUNT="${2:-}"; shift ;;
			--mount=*) MOUNT="${1#--mount=}" ;;
			--limit) LIMIT="${2:-}"; shift ;;
			--limit=*) LIMIT="${1#--limit=}" ;;
			--step-limit) STEP_LIMIT="${2:-}"; shift ;;
			--step-limit=*) STEP_LIMIT="${1#--step-limit=}" ;;
			--no-env) NO_ENV=1 ;;
			--) shift; break ;;
			*) err "Unknown argument: $1"; return 2 ;;
		esac
		shift
	done

	if [ -z "$LIMIT" ]; then
		case "$action" in
			check | connect) LIMIT=15 ;;
			mount) LIMIT=30 ;;
			*) LIMIT=60 ;;
		esac
	fi
	[ -n "$STEP_LIMIT" ] || STEP_LIMIT=$((LIMIT > 10 ? LIMIT - 10 : LIMIT))
	case "$LIMIT$STEP_LIMIT" in
		*[!0-9]*) err "--limit and --step-limit take whole seconds"; return 2 ;;
	esac
	case "$WORKSPACE" in
		"" | /*) ;;
		*) err "--workspace must be an absolute path on the remote host"; return 2 ;;
	esac

	TIMEOUT=""
	if command -v timeout >/dev/null 2>&1; then
		TIMEOUT=timeout
	elif command -v gtimeout >/dev/null 2>&1; then
		TIMEOUT=gtimeout
	fi
	# Arrays rather than functions: timeout runs a program, and a watchdog must end ssh itself.
	SSH=(ssh -o BatchMode=yes -o ConnectTimeout=10 -S "$SOCK")
	MASTER=(ssh -MNf -o ControlMaster=yes -o ControlPersist=4h -o "ControlPath=$SOCK" -o ServerAliveInterval=15 -o ServerAliveCountMax=3 -o ConnectTimeout=10)
	TMP_FILES=""
	trap 'cleanup' EXIT

	case "$action" in
		resolve) NO_MARKER=1; resolve ;;
		check) check_connection ;;
		connect) connect ;;
		run)
			[ -n "$WORKSPACE" ] || { err "run needs --workspace"; return 2; }
			[ $# -gt 0 ] || { err "Give the command after --"; return 2; }
			run_command "$@"
			;;
		script)
			[ $# -gt 0 ] || { err "Give the script after --"; return 2; }
			run_script "$@"
			;;
		mount) mount_workspace ;;
	esac
}

usage() { sed -n '2,/^# Everything runs inside/p' "$0" 2>/dev/null | sed '$d' | sed 's/^# \{0,1\}//'; }
err() { printf 'vrl_ssh: %s\n' "$*" >&2; }

# shellcheck disable=SC2329 # The EXIT trap calls it.
cleanup() {
	local f
	for f in $TMP_FILES; do rm -f "$f"; done
}

new_tmp() {
	local f
	f="$(mktemp "${TMPDIR:-/tmp}/vrl-ssh.XXXXXX")" || return 1
	TMP_FILES="$TMP_FILES $f"
	printf '%s' "$f"
}

# Quote a string for any shell of the sh family, the remote login shell included.
sq() {
	local s=${1//\'/\'\\\'\'}
	printf "'%s'" "$s"
}

# with_limit <seconds> <input file> <command...>: run the command with that input, end it at the limit
# (SIGTERM, then SIGKILL 5 seconds later), and return 124 if the limit cut it.
with_limit() {
	local limit="$1" input="$2" start rc pid watchdog
	shift 2
	start="$(date +%s)"
	if [ "$limit" = 0 ]; then
		"$@" <"$input"
		return
	elif [ -n "$TIMEOUT" ]; then
		"$TIMEOUT" -k 5 "$limit" "$@" <"$input"
		rc=$?
	else
		# Neither timeout nor gtimeout, as on macOS without Homebrew's coreutils: a watchdog does the same.
		# Its output goes to /dev/null, so that its leftover sleep cannot hold the agent's shell open.
		"$@" <"$input" &
		pid=$!
		(
			sleep "$limit"
			kill -TERM "$pid" 2>/dev/null
			sleep 5
			kill -KILL "$pid" 2>/dev/null
		) >/dev/null 2>&1 </dev/null &
		watchdog=$!
		# Quiet, so that bash reports no "Terminated" job when the watchdog fires.
		wait "$pid" 2>/dev/null
		rc=$?
		kill "$watchdog" 2>/dev/null
		wait "$watchdog" 2>/dev/null
	fi
	if [ "$rc" -ne 0 ] && [ $(($(date +%s) - start)) -ge "$limit" ]; then
		err "the local time limit of $limit s cut the call"
		rc=124
	fi
	return "$rc"
}

resolve() {
	local conf host
	conf="$(ssh -G "$ALIAS" 2>/dev/null)" || { err "ssh -G could not resolve $ALIAS"; return 1; }
	printf '%s\n' "$conf" | awk '$1 == "hostname" || $1 == "user" || $1 == "port" || $1 == "proxyjump" { print $1 ": " $2 }'
	host="$(printf '%s\n' "$conf" | awk '$1 == "hostname" { print $2; exit }')"
	if [ "$host" = "$ALIAS" ]; then
		printf 'note: the host name equals the alias, so ~/.ssh/config may have no Host %s entry\n' "$ALIAS"
	fi
}

# One round trip through the master: `ssh -O check` would only see that the local master process exists.
round_trip() {
	local limit="$1" start rc
	start="$(date +%s)"
	with_limit "$limit" /dev/null "${SSH[@]}" -n "$ALIAS" true
	rc=$?
	ROUND_TRIP_SECONDS=$(($(date +%s) - start))
	return "$rc"
}

# The absolute path of a local folder, resolved through its parent, so that a dead mount is never touched.
local_path() {
	local parent
	parent="$(cd "$(dirname "$1")" 2>/dev/null && pwd -P)" || return 1
	printf '%s/%s' "$parent" "$(basename "$1")"
}

mount_listed() { mount | grep -Fq " on $1 "; }

check_connection() {
	local path
	if ! round_trip "$LIMIT"; then
		printf 'connection: no answer from %s through the master\n' "$ALIAS"
		return 1
	fi
	printf 'connection: %s answers through the master (%s s)\n' "$ALIAS" "$ROUND_TRIP_SECONDS"
	if [ -n "$MOUNT" ]; then
		path="$(local_path "$MOUNT")" || { err "The mount's parent folder does not exist: $MOUNT"; return 2; }
		if mount_listed "$path"; then
			printf 'mount: %s is listed\n' "$path"
		else
			printf 'mount: %s is not listed\n' "$path"
			return 4
		fi
	fi
}

connect() {
	local pattern socket errors rc
	if round_trip "$LIMIT"; then
		printf 'connection: %s answers through the master (%s s)\n' "$ALIAS" "$ROUND_TRIP_SECONDS"
		return 0
	fi
	printf 'connection: no answer; closing the old master\n'
	with_limit "$LIMIT" /dev/null ssh -S "$SOCK" -O exit "$ALIAS" >/dev/null 2>&1
	# Anchored at both ends: pkill -f matches whole command lines, and an unanchored pattern would also
	# match the shell running pkill. Dots in the alias are escaped.
	pattern="^ssh -MNf .* ${ALIAS//./\\.}\$"
	if pgrep -f -- "$pattern" >/dev/null 2>&1; then
		pkill -f -- "$pattern"
		sleep 1
	fi
	# A socket left behind makes the new master skip multiplexing without failing.
	socket="$(ssh -G -o ControlPath="$SOCK" "$ALIAS" 2>/dev/null | awk '$1 == "controlpath" { print $2; exit }')"
	[ -n "$socket" ] && rm -f "$socket"

	printf 'connection: starting a new master\n'
	errors="$(new_tmp)" || return 1
	# Its output goes to a file, not to the agent's shell, since the master stays in the background. Its
	# command line starts with `ssh -MNf` and ends with the alias, for the pkill pattern above.
	with_limit "$LIMIT" /dev/null "${MASTER[@]}" -o BatchMode=yes "$ALIAS" >/dev/null 2>"$errors"
	rc=$?
	if [ "$rc" -ne 0 ]; then
		sed 's/^/ssh: /' "$errors" >&2
		if grep -qiE 'host key|IDENTIFICATION HAS CHANGED' "$errors"; then
			err "The host key could not be verified. Stop and report to the user; never turn off host-key checking."
			return 5
		fi
		err "The master did not start. If the login needs a password, a passphrase, or a second factor, ask the user to run this in their own terminal, then run connect again:"
		printf '  %s %s\n' "${MASTER[*]}" "$ALIAS" >&2
		return 3
	fi
	if round_trip "$LIMIT"; then
		printf 'connection: %s answers through the new master (%s s)\n' "$ALIAS" "$ROUND_TRIP_SECONDS"
		return 0
	fi
	err "The new master started, but $ALIAS does not answer through it"
	return 1
}

# The remote command line: enter the workspace and load its .env, then run the interpreter on the standard
# input under the remote step limit.
remote_line() {
	local interpreter="$1" line=""
	if [ -n "$WORKSPACE" ]; then
		line="cd $(sq "$WORKSPACE") && "
		if [ "$NO_ENV" = 0 ]; then
			line="$line{ [ -f $(sq "$WORKSPACE/.env") ] || { echo 'vrl_ssh: the workspace has no .env; pass --no-env if setup has not written it yet' >&2; exit 98; }; } && set -a && . $(sq "$WORKSPACE/.env") && set +a && "
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
	input="$(new_tmp)" || return 1
	# The braces give the command no input, so that nothing it runs waits on the standard input.
	{
		printf '{\n'
		printf '%s\n' "$*"
		printf '} </dev/null\n'
	} >"$input"
	with_limit "$LIMIT" "$input" "${SSH[@]}" "$ALIAS" "$(remote_line 'bash -s')"
}

run_script() {
	local file="$1" interpreter arg
	shift
	[ -f "$file" ] || { err "No such script: $file"; return 2; }
	case "$file" in
		*.py) interpreter="python3 -" ;;
		*) interpreter="bash -s --" ;;
	esac
	for arg in "$@"; do interpreter="$interpreter $(sq "$arg")"; done
	with_limit "$LIMIT" "$file" "${SSH[@]}" "$ALIAS" "$(remote_line "$interpreter")"
}

mount_workspace() {
	local path rc
	[ -n "$WORKSPACE" ] && [ -n "$MOUNT" ] || { err "mount needs --workspace and --mount"; return 2; }
	path="$(local_path "$MOUNT")" || { err "The mount's parent folder does not exist: $MOUNT"; return 2; }
	round_trip "$LIMIT" || { err "No answer through the master: run connect first"; return 1; }
	if mount_listed "$path"; then
		printf 'mount: unmounting the stale mount at %s\n' "$path"
		case "$(uname -s)" in
			Linux) with_limit "$LIMIT" /dev/null fusermount -u "$path" ;;
			*) with_limit "$LIMIT" /dev/null umount "$path" ;;
		esac || { err "Could not unmount $path; stop and report"; return 1; }
	fi
	[ -d "$path" ] || { err "The mount folder does not exist: $path"; return 2; }
	command -v sshfs >/dev/null 2>&1 || { err "sshfs is not installed on this machine"; return 2; }
	with_limit "$LIMIT" /dev/null sshfs \
		-o ssh_command="ssh -S $SOCK -o BatchMode=yes -o ControlMaster=no" \
		-o reconnect,ServerAliveInterval=15,ServerAliveCountMax=3,idmap=user \
		"$ALIAS:$WORKSPACE" "$path"
	rc=$?
	[ "$rc" -eq 0 ] || return "$rc"
	if mount_listed "$path"; then
		printf 'mount: %s:%s is mounted at %s\n' "$ALIAS" "$WORKSPACE" "$path"
	else
		err "sshfs returned, but mount does not list $path"
		return 1
	fi
}

NO_MARKER=0
main "$@"
rc=$?
[ "$NO_MARKER" = 1 ] || printf '__EXIT %s\n' "$rc"
exit "$rc"
