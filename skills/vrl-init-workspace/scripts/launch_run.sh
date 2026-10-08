#!/usr/bin/env bash
# Launch a long-running command the way docs/AGENTS/log_template.md asks: write the log header, run the
# command detached with its output in the log, and let the same shell append the footer and exit code
# when the command ends.
#
# Usage, from the workspace root:
#   launch_run.sh --log <log> --purpose '<what it does>' (--tmux <session> | --nohup) [options] -- '<command>'
#
#   --log FILE       The log, such as logs/<date>-<name>/<run>.log; its folder is created if missing.
#   --purpose TEXT   The header's purpose line, such as '<date>-<name> / <run>: <one line on what it does>'.
#   --tmux SESSION   Run in a new window of this tmux session, named after the log: `<date>-<name>/<run>`.
#   --nohup          Run in the background as a process of its own, outside any terminal.
#   --code DIR       The checkout the command runs from, such as main_repo or worktrees/<branch>: the header
#                    names its branch and commit, and whether it is clean. When it is dirty and --outputs is
#                    given, `git diff HEAD` and the untracked files are saved in <outputs>/git_diff.patch.
#   --outputs DIR    The run's output folder, created if missing.
#   --gpus IDS       The GPU ids, such as 0,1: exported as CUDA_VISIBLE_DEVICES, and named with their model.
#   --machine NAME   The machine's short name in docs/AGENTS/machine.md (default: the host name).
#   --env NAME       The Python environment (default: the active virtual environment's folder, or none).
#   --restart        Go on when the log's last run has no footer, as after a crash or a kill, once you have
#                    made sure that run is gone; a new header goes below it. Without it, such a log is refused.
#   --new-session    With --tmux: create the session if it does not exist. Without it, a missing session is
#                    refused, since the session should start from a shell with the machine's settings, such
#                    as a proxy that docs/AGENTS/machine.md names.
#
# The command is one string, exactly as the plan writes it. It runs with bash from the workspace root, with
# .env loaded and no input. A second copy is refused: a tmux window of the same name, or a process that the
# log's last session line names and that is still alive. After 3 seconds, the script checks that the command
# still runs: it prints the log, the session, and the code, or else the end of the log, and exits 1.
#
# In remote mode, run it on the remote host through the master:
#   vrl_ssh.sh script <alias> --workspace <remote workspace> -- launch_run.sh <options> -- '<command>'
#
# Everything runs inside main(), so that bash reads the whole script before running it when the
# script comes in on stdin.

main() {
	set -uo pipefail

	local log="" purpose="" session="" nohup=0 code="" outputs="" gpus="" machine="" envname="" restart=0 new_session=0
	while [ $# -gt 0 ]; do
		case "$1" in
			--log) log="${2:-}"; shift ;;
			--log=*) log="${1#--log=}" ;;
			--purpose) purpose="${2:-}"; shift ;;
			--purpose=*) purpose="${1#--purpose=}" ;;
			--tmux) session="${2:-}"; shift ;;
			--tmux=*) session="${1#--tmux=}" ;;
			--nohup) nohup=1 ;;
			--code) code="${2:-}"; shift ;;
			--code=*) code="${1#--code=}" ;;
			--outputs) outputs="${2:-}"; shift ;;
			--outputs=*) outputs="${1#--outputs=}" ;;
			--gpus) gpus="${2:-}"; shift ;;
			--gpus=*) gpus="${1#--gpus=}" ;;
			--machine) machine="${2:-}"; shift ;;
			--machine=*) machine="${1#--machine=}" ;;
			--env) envname="${2:-}"; shift ;;
			--env=*) envname="${1#--env=}" ;;
			--restart) restart=1 ;;
			--new-session) new_session=1 ;;
			-h | --help) usage; return 0 ;;
			--) shift; break ;;
			*) err "Unknown argument: $1"; return 2 ;;
		esac
		shift
	done
	local cmd="$*"

	[ -n "$cmd" ] || { err "Give the command after --"; return 2; }
	[ -n "$log" ] || { err "--log is required"; return 2; }
	[ -n "$purpose" ] || { err "--purpose is required"; return 2; }
	case "${session:+tmux}$nohup" in
		tmux0 | 1) ;;
		*) err "Choose one of --tmux <session> and --nohup"; return 2 ;;
	esac
	case "$gpus" in
		*[!0-9,]* | ,* | *, | *,,*) err "--gpus takes ids such as 0 or 0,1"; return 2 ;;
	esac
	[ -f .env ] || { err "Run this from the workspace root: there is no .env here"; return 2; }
	if [ -n "$session" ]; then
		command -v tmux >/dev/null 2>&1 || { err "tmux is not installed"; return 2; }
	fi

	local ws
	ws="$(pwd -P)"
	set -a
	# shellcheck disable=SC1091
	. ./.env
	set +a

	local log_path="$log"
	case "$log_path" in /*) ;; *) log_path="$ws/$log_path" ;; esac
	local run window
	run="$(basename "$log_path" .log)"
	# tmux reads `:` and `.` in a target as separators.
	window="$(basename "$(dirname "$log_path")")/$run"
	window="${window//[:.]/-}"

	# Never start a second copy.
	if [ -n "$session" ]; then
		if ! tmux list-sessions -F '#{session_name}' 2>/dev/null | grep -Fxq -- "$session"; then
			if [ "$new_session" = 1 ]; then
				tmux new-session -d -s "$session" -c "$ws" || { err "Could not create the tmux session $session"; return 1; }
			else
				err "The tmux session $session does not exist. Start it as docs/AGENTS/machine.md says, or pass --new-session."
				return 2
			fi
		fi
		if tmux list-windows -t "$session:" -F '#{window_name}' 2>/dev/null | grep -Fxq -- "$window"; then
			err "$session:$window already exists: the run is still there. Check it before starting it again."
			return 3
		fi
	fi
	if [ -f "$log_path" ] && log_is_open "$log_path"; then
		local pid
		pid="$(last_session_line "$log_path" | sed -n 's/.*PID \([0-9][0-9]*\).*/\1/p')"
		if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
			err "PID $pid from the log's last session line is still alive: the run may still be going. Check it before starting it again."
			return 3
		fi
		if [ "$restart" = 0 ]; then
			err "The log's last run has no footer: it is still running somewhere, or it was killed. Make sure it is gone, then pass --restart."
			return 3
		fi
	fi

	# The header's code, outputs, and resources lines.
	local code_line="none" patch=""
	if [ -n "$code" ]; then
		local branch commit state="clean"
		commit="$(git -C "$code" rev-parse --short=12 HEAD 2>/dev/null)" || { err "Not a git checkout: $code"; return 2; }
		branch="$(git -C "$code" rev-parse --abbrev-ref HEAD 2>/dev/null)"
		if [ -n "$(git -C "$code" status --porcelain 2>/dev/null)" ]; then
			state="dirty"
			if [ -n "$outputs" ]; then
				patch="$(save_diff "$code" "$outputs")" || return 1
			fi
		fi
		code_line="$code ($branch) @ $commit ($state)"
	fi
	[ -z "$outputs" ] || mkdir -p "$outputs" || { err "Could not create $outputs"; return 1; }
	[ -n "$machine" ] || machine="$(hostname -s 2>/dev/null || hostname)"
	if [ -z "$envname" ]; then
		if [ -n "${VIRTUAL_ENV:-}" ]; then envname="$(basename "$VIRTUAL_ENV")"; else envname="none"; fi
	fi
	local resources
	if [ -n "$gpus" ]; then
		resources="$machine, GPU $gpus ($(gpu_model "$gpus")), Python env $envname"
	else
		resources="$machine, no GPU, Python env $envname"
	fi
	local header
	header="$(printf '# command:   %s\n# purpose:   %s\n# code:      %s\n# outputs:   %s\n# resources: %s' \
		"$cmd" "$purpose" "$code_line" "${outputs:-none}" "$resources")"

	mkdir -p "$(dirname "$log_path")" || { err "Could not create the log's folder"; return 1; }

	# The shell that runs the command writes the header first, with its own PID, and the footer when the
	# command ends. It passes a signal on to the command as SIGTERM, so that closing the tmux window or
	# `kill <PID>` ends the run and still leaves a footer; only SIGKILL leaves none.
	local where=""
	[ -z "$session" ] || where="$session:$window, "
	local inner
	inner="cd $(sq "$ws") || exit 97
set -a; . ./.env; set +a
${gpus:+export CUDA_VISIBLE_DEVICES=$gpus
}ts() { local z; z=\$(date +%z); printf '%s %s:%s' \"\$(date '+%Y-%m-%d %H:%M:%S')\" \"\${z%??}\" \"\${z#???}\"; }
child=
trap 'kill -TERM \$child 2>/dev/null' HUP INT TERM
start=\$(date +%s)
{ printf '%s\\n' $(sq "$header"); printf '# session:   %sPID %s\\n' $(sq "$where") \"\$\$\"; printf '# started:   %s\\n' \"\$(ts)\"; printf '# ---------- stdout + stderr ----------\\n'; } >>$(sq "$log_path")
bash -c $(sq "$cmd") >>$(sq "$log_path") 2>&1 </dev/null &
child=\$!
wait \$child; rc=\$?
while kill -0 \$child 2>/dev/null; do wait \$child; rc=\$?; done
d=\$((\$(date +%s) - start))
{ printf '# ---------- end ----------\\n'; printf '# finished:  %s (%d:%02d:%02d), exit code %d\\n' \"\$(ts)\" \$((d / 3600)) \$((d % 3600 / 60)) \$((d % 60)) \"\$rc\"; } >>$(sq "$log_path")"

	local before
	before="$(header_count "$log_path")"
	if [ -n "$session" ]; then
		tmux new-window -d -t "$session:" -n "$window" -c "$ws" "exec bash -c $(sq "$inner")" ||
			{ err "tmux could not open the window"; return 1; }
	elif command -v setsid >/dev/null 2>&1; then
		setsid nohup bash -c "$inner" >/dev/null 2>&1 </dev/null &
	else
		nohup bash -c "$inner" >/dev/null 2>&1 </dev/null &
	fi

	sleep 3
	if [ "$(header_count "$log_path")" -le "$before" ]; then
		err "The command did not start: no new header in $log"
		return 1
	fi
	printf 'log       %s\n' "$log"
	printf 'session   %s\n' "$(last_session_line "$log_path" | sed 's/^# session: *//')"
	printf 'code      %s\n' "$code_line"
	if [ -n "$patch" ]; then
		printf 'diff      %s\n' "$patch"
	elif [ "${code_line%(dirty)}" != "$code_line" ]; then
		printf 'diff      not saved: give --outputs to save it in the run folder\n'
	fi
	if log_is_open "$log_path"; then
		printf 'status    running after 3 s\n'
		return 0
	fi
	printf 'status    ended within 3 s; the end of the log:\n'
	tail -n 20 "$log_path"
	return 1
}

usage() { sed -n '2,/^# Everything runs inside/p' "$0" 2>/dev/null | sed '$d' | sed 's/^# \{0,1\}//'; }
err() { printf 'launch_run: %s\n' "$*" >&2; }

# Quote a string for any shell of the sh family, the one tmux runs a window's command with included.
sq() {
	local s=${1//\'/\'\\\'\'}
	printf "'%s'" "$s"
}

header_count() { if [ -f "$1" ]; then grep -c '^# started: ' "$1"; else echo 0; fi; }

# A log is open when its last header has no footer below it.
log_is_open() {
	awk '/^# started: / { open = 1 } /^# finished: / { open = 0 } END { exit open ? 0 : 1 }' "$1"
}

last_session_line() { grep '^# session: ' "$1" | tail -n 1; }

# The models of the given GPUs, such as `NVIDIA A100-SXM4-80GB`, or `unknown` without nvidia-smi.
gpu_model() {
	local models
	models="$(nvidia-smi --query-gpu=index,name --format=csv,noheader 2>/dev/null |
		awk -F', *' -v ids=",$1," 'index(ids, "," $1 ",") { print $2 }' | sort -u |
		awk '{ printf "%s%s", (NR > 1 ? " + " : ""), $0 }')"
	printf '%s' "${models:-unknown}"
}

# Save what makes the checkout dirty in the output folder, under a new name if an earlier diff differs.
save_diff() {
	local code="$1" outputs="$2" file tmp
	mkdir -p "$outputs" || { err "Could not create $outputs"; return 1; }
	tmp="$outputs/.git_diff.patch.tmp"
	{
		git -C "$code" status --porcelain | sed -n 's/^?? /# untracked: /p'
		git -C "$code" diff HEAD
	} >"$tmp" || { err "Could not save the diff of $code"; return 1; }
	file="$outputs/git_diff.patch"
	if [ -f "$file" ] && ! cmp -s "$tmp" "$file"; then
		file="$outputs/git_diff-$(date +%Y%m%d-%H%M%S).patch"
	fi
	mv "$tmp" "$file"
	printf '%s' "$file"
}

main "$@"
