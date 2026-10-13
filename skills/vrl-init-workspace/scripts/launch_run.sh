#!/usr/bin/env bash
# Launch a long-running command the way docs/AGENTS/log_template.md asks: write the log header, run
# the command detached with its output in the log, and let the same shell append the footer and exit
# code when the command and every process it started have ended.
#
# Run it from the workspace root, or in remote mode on the remote host:
#   vrl_ssh.sh script <alias> --workspace <remote workspace> -- launch_run.sh <options>
#
# Everything runs inside main(), so that bash reads the whole script before running it when the
# script comes in on stdin.

usage() {
	cat <<'EOF'
Usage, from the workspace root:
  launch_run.sh --plan docs/plans/<date>-<ID>.md --run <run> --plan-sha256 <hash> <options>
  launch_run.sh --purpose '<what it does>' --log <log> --code <checkout|none> <options> -- '<command>'
  launch_run.sh --pin <checkout|none>
  launch_run.sh --plan docs/plans/<date>-<ID>.md [--run <run>] --status

The plan form runs the block of the plan file whose info string holds `run=<run>`, and refuses it
unless the plan file has the given SHA-256, the checkout has the block's commit and diff, and --gpus
names its gpus= count. Its log is logs/<date>-<ID>/<run>.log and its outputs runs/<date>-<ID>/<run>/,
neither a symlink. The free form runs any other command. --pin prints the `code=... diff=...` words
of a checkout as it is now; untracked files that no committed .gitignore ignores count in the diff.
--status prints, for each run of the plan or the one --run names, whether it has not started, is
running, stopped without a footer, or finished with its exit code, and the end of its log; it
changes nothing.

Options:
  --tmux SESSION   Run in a new window of this tmux session; or
  --nohup          in the background, outside any terminal.
  --new-session    With --tmux: create the session if it does not exist.
  --gpus IDS       The GPUs, such as 0,1, each with no process on it; or
  --no-gpu         none: CUDA_VISIBLE_DEVICES is set empty.
  --machine NAME   Required: the machine's short name in docs/AGENTS/machine.md.
  --purpose TEXT   The header's purpose line (plan form default: the plan and the run).
  --log FILE       Free form: the log, such as logs/<date>-<task>.log.
  --code DIR|none  Free form: the checkout the command uses, such as main_repo or worktrees/<branch>.
  --outputs DIR    Free form: the outputs folder, created if missing; required for a dirty checkout.
  --env NAME       The header's Python environment (default: the block's env=, or the active one).
  --restart        Start again a run whose last start ended with a nonzero or unknown exit code, or
                   crashed (no footer, no process left); a crashed one first gets a footer at the
                   log's last write.
  --resume         Start again a run whose last start finished with exit code 0, to continue it.
  --wait S         Seconds to wait before reporting the status (default 3).

The command runs with bash from the workspace root, with no input, and with these set: the .env
lines, read as literal NAME=value and never run, except names such as HOME, PATH, or LD_PRELOAD that
would change what runs; ~/.local/bin first on PATH; CUDA_VISIBLE_DEVICES and
CUDA_DEVICE_ORDER=PCI_BUS_ID, for only its GPUs; PYTHONUNBUFFERED=1; and VRL_OUTPUTS, the absolute
path of its outputs folder, when it has one. It refuses on a machine with a scheduler (Slurm, PBS,
LSF, or SGE), a command that sets CUDA_VISIBLE_DEVICES or seems to hold a secret, and a second copy
of a live run. It also refuses a log whose last run has ended, unless --restart or --resume is
given: give a rerun a new run name. It prints the log, run-id, session, start time, and code at the
start, then the status.
Exit codes: 0 running, or ended with exit code 0 within the wait; 1 ended with another exit code, or
did not start; 2 bad arguments, or the tmux session is missing; 3 refused.
On the local machine of a remote-mode workspace, every form exits 2: run it on the remote host
through vrl_ssh.sh script. Never run --sync-prepare or --sync-apply: vrl_ssh.sh sync does.
EOF
}

main() {
	set -uo pipefail
	umask 077
	unset CDPATH

	local log="" purpose="" session="" nohup=0 gpus="" no_gpu=0 machine="" code="" outputs="" envname=""
	local restart=0 resume=0 new_session=0 wait_s=3 plan="" plan_given=0 run="" plan_sha="" pin="" pin_given=0
	local log_given=0 outputs_given=0 code_given=0 status=0 sync_prepare="" sync_apply="" sync_commit="" sync_branch="" sync_owner=""
	while [ $# -gt 0 ]; do
		case "$1" in
			--log) log="${2:-}"; log_given=1; shift ;;
			--purpose) purpose="${2:-}"; shift ;;
			--tmux) session="${2:-}"; shift ;;
			--nohup) nohup=1 ;;
			--gpus) gpus="${2:-}"; shift ;;
			--no-gpu) no_gpu=1 ;;
			--machine) machine="${2:-}"; shift ;;
			--code) code="${2:-}"; code_given=1; shift ;;
			--outputs) outputs="${2:-}"; outputs_given=1; shift ;;
			--env) envname="${2:-}"; shift ;;
			--restart) restart=1 ;;
			--resume) resume=1 ;;
			--new-session) new_session=1 ;;
			--wait)
				wait_s="${2:-}"
				case "$wait_s" in "" | *[!0-9]*) err "--wait takes whole seconds"; return 2 ;; esac
				shift
				;;
			--plan) plan="${2:-}"; plan_given=$((plan_given + 1)); shift ;;
			--run) run="${2:-}"; shift ;;
			--plan-sha256) plan_sha="${2:-}"; shift ;;
			--pin) pin="${2:-}"; pin_given=1; shift ;;
			--status) status=1 ;;
			--sync-prepare) sync_prepare="${2:-}"; shift ;;
			--sync-apply) sync_apply="${2:-}"; shift ;;
			--commit) sync_commit="${2:-}"; shift ;;
			--branch) sync_branch="${2:-}"; shift ;;
			--owner) sync_owner="${2:-}"; shift ;;
			-h | --help) usage; return 0 ;;
			--) shift; break ;;
			*) err "Unknown argument: $1; see launch_run.sh --help"; return 2 ;;
		esac
		shift
	done

	# The local machine of a remote-mode workspace runs no code; the remote host sets VRL_REMOTE.
	if [ -z "${VRL_REMOTE:-}" ] && in_remote_workspace; then
		err "This is the local machine of a remote-mode workspace, which runs no code: run launch_run.sh on the remote host, through vrl_ssh.sh script."
		return 2
	fi
	if [ -n "$sync_prepare$sync_apply" ]; then
		[ -n "${VRL_REMOTE:-}" ] || { err "--sync-prepare and --sync-apply run only on the remote host, through vrl_ssh.sh sync: run that instead"; return 2; }
		if [ "$plan_given$pin_given$status$log_given$code_given$outputs_given" != 000000 ] || [ -n "$run$plan_sha$session$gpus" ] || [ $# -gt 0 ]; then
			err "--sync-prepare and --sync-apply are vrl_ssh.sh sync's own steps, and take no other form's options: never run them yourself"
			return 2
		fi
	fi
	if [ -n "$sync_prepare" ]; then
		sync_prepare "$sync_prepare"
		return
	fi
	if [ -n "$sync_apply" ]; then
		sync_apply "$sync_apply" "$sync_commit" "$sync_branch" "$sync_owner"
		return
	fi
	if [ "$status" = 1 ]; then
		[ "$plan_given" = 1 ] && [ -n "$plan" ] || { err "--status needs --plan, with the plan file"; return 2; }
		plan_status "$plan" "$run"
		return
	fi

	if [ "$pin_given" = 1 ]; then
		[ -n "$pin" ] || { err "--pin takes a checkout, or none"; return 2; }
		print_pin "$pin"
		return
	fi

	# Arguments.
	local cmd=""
	if [ "$plan_given" -gt 0 ]; then
		[ "$plan_given" = 1 ] && [ -n "$plan" ] || { err "Give --plan once, with the plan file"; return 2; }
		[ $# -eq 0 ] || { err "The plan form takes no command after --: the command comes from the plan"; return 2; }
		[ -n "$run" ] || { err "--plan needs --run"; return 2; }
		[ -n "$plan_sha" ] || { err "--plan needs --plan-sha256, the hash recorded when the plan was approved"; return 2; }
		[ "$log_given$outputs_given$code_given" = 000 ] ||
			{ err "The plan form takes its log, outputs, and checkout from the plan: drop --log, --outputs, and --code"; return 2; }
	else
		[ -z "$run$plan_sha" ] || { err "--run and --plan-sha256 go with --plan"; return 2; }
		[ $# -eq 1 ] || { err "Give the command as one quoted string after --"; return 2; }
		cmd="$1"
		[ -n "$cmd" ] || { err "The command is empty"; return 2; }
		[ -n "$purpose" ] || { err "--purpose is required"; return 2; }
		[ -n "$log" ] || { err "--log is required"; return 2; }
		[ -n "$code" ] || { err "--code is required: the checkout, or none"; return 2; }
	fi
	case "${session:+tmux}$nohup" in
		tmux0 | 1) ;;
		*) err "Choose one of --tmux <session> and --nohup"; return 2 ;;
	esac
	case "${gpus:+g}$no_gpu" in
		g0 | 1) ;;
		*) err "Choose one of --gpus <ids> and --no-gpu"; return 2 ;;
	esac
	case "$gpus" in
		*[!0-9,]* | ,* | *, | *,,*) err "--gpus takes ids such as 0 or 0,1"; return 2 ;;
	esac
	if [ -n "$gpus" ] && [ "$(printf '%s\n' "$gpus" | tr ',' '\n' | sort -u | wc -l | tr -d ' ')" != "$(printf '%s\n' "$gpus" | tr ',' '\n' | wc -l | tr -d ' ')" ]; then
		err "--gpus names a GPU twice"
		return 2
	fi
	[ -n "$machine" ] || { err "--machine is required: the short name in docs/AGENTS/machine.md"; return 2; }
	case "$session" in
		*[!A-Za-z0-9_-]*) err "A tmux session name holds only letters, digits, - and _"; return 2 ;;
	esac
	local v
	for v in "$purpose" "$machine" "$code" "$outputs" "$envname" "$log" "$run"; do
		case "$v" in *"$NL"* | *"$CR"*) err "Options other than the command hold one line each"; return 2 ;; esac
	done

	# Refusals.
	if scheduler_here; then
		err "This machine has a job scheduler: launch through it as docs/AGENTS/machine.md says, by hand, and write the log's header and footer yourself, in this form:"
		cat >&2 <<'EOF'
# command:   <the exact command>
# purpose:   <date>-<name> / <run>: <one line>
# code:      <checkout> (<branch>) @ <commit> (clean or dirty)
# resources: <machine>, GPU <ids> (<model>)      or: <machine>, no GPU
# session:   job <job ID>
# started:   <YYYY-MM-DD HH:MM:SS ±HH:MM>
# ---------- stdout + stderr ----------
<output>
# ---------- end ----------
# finished:  <YYYY-MM-DD HH:MM:SS ±HH:MM> (<H:MM:SS>), exit code <n>
EOF
		return 3
	fi
	[ -f .env ] || { err "Run this from the workspace root: there is no .env here"; return 2; }
	local ws
	ws="$(pwd -P)"
	if [ -n "${VRL_REMOTE:-}" ] && [ "$plan_given" = 0 ]; then
		case "$log" in
			logs/*) ;;
			*) err "On the remote host, a log goes under logs/, given relative to the workspace root, so that a sync can see the run"; return 2 ;;
		esac
	fi
	if [ "$plan_given" -gt 0 ]; then
		plan_load "$ws" "$plan" "$run" "$plan_sha" || return 3
		cmd="$PLAN_CMD"
		log="logs/$PLAN_BASE/$run.log"
		outputs="runs/$PLAN_BASE/$run/"
		code="$PLAN_CODE"
		[ -n "$purpose" ] || purpose="$PLAN_BASE / $run: run $run of the approved plan"
		[ -n "$envname" ] || envname="$PLAN_ENV"
		if [ "$PLAN_GPUS" = 0 ]; then
			[ "$no_gpu" = 1 ] || { err "The plan gives run $run no GPU: pass --no-gpu"; return 3; }
		elif [ "$no_gpu" = 1 ] || [ "$(printf '%s\n' "$gpus" | tr ',' '\n' | wc -l | tr -d ' ')" != "$PLAN_GPUS" ]; then
			err "The plan gives run $run $PLAN_GPUS GPUs: pass that many ids with --gpus"
			return 3
		fi
	fi
	if grep -Eq '(^|[^A-Za-z0-9_])CUDA_VISIBLE_DEVICES=' <<<"$cmd"; then
		err "The command sets CUDA_VISIBLE_DEVICES itself: pass the GPUs with --gpus instead."
		return 3
	fi
	if grep -Eiq -- "$SECRET_RE" <<<"$cmd"; then
		err "The command seems to hold a secret, which the log header would record: keep it out of the command, and let the tool use the user's own login, such as hf auth login."
		return 3
	fi
	if [ -n "$session" ] && ! command -v tmux >/dev/null 2>&1; then
		err "tmux is not installed: use --nohup, or ask the user to install tmux"
		return 2
	fi
	local log_path="$log"
	case "$log_path" in /*) ;; *) log_path="$ws/$log_path" ;; esac
	# A symlink would send the log or the outputs elsewhere, such as into a file of the user's.
	if [ -L "$log_path" ]; then
		err "The log is a symlink, which would send its lines elsewhere: $log; tell the user"
		return 3
	fi
	if [ "$plan_given" -gt 0 ] &&
		{ [ -L "$ws/logs/$PLAN_BASE" ] || [ -L "$ws/runs/$PLAN_BASE" ] || [ -L "$ws/runs/$PLAN_BASE/$run" ]; }; then
		err "logs/$PLAN_BASE, runs/$PLAN_BASE, or runs/$PLAN_BASE/$run is a symlink: the run's log and outputs must stay where the plan puts them: tell the user"
		return 3
	fi
	mkdir -p "$(dirname "$log_path")" || { err "Could not create the log's folder: fix the cause, such as a full disk, then launch again"; return 1; }
	if [ -n "${VRL_REMOTE:-}" ]; then
		# A sync looks for runs in logs/ itself, not in a symlinked folder below it or outside it.
		case "$(cd "$(dirname "$log_path")" && pwd -P)/" in
			"$(cd "$ws/logs" && pwd -P)"/*) ;;
			*) err "On the remote host, a log stays inside logs/, with no symlinked folder or .. on its path, so that a sync can see the run: $log"; return 3 ;;
		esac
	fi
	local window
	window="$(basename "$(dirname "$log_path")")/$(basename "$log_path" .log)"
	window="$(printf '%s' "$window" | tr -c 'A-Za-z0-9_/-' '-')"

	# One launch of a log at a time.
	LOCK="$log_path.lock"
	if ! mkdir "$LOCK" 2>/dev/null; then
		if [ -O "$LOCK" ] && [ -n "$(find "$LOCK" -maxdepth 0 -mmin +2 2>/dev/null)" ]; then
			rmdir "$LOCK" 2>/dev/null
		fi
		mkdir "$LOCK" 2>/dev/null || { err "Another launch of this log is in progress: try again in a minute."; return 3; }
	fi
	trap 'rmdir "$LOCK" 2>/dev/null' EXIT

	# The checkout and the pin are checked under the lock, so that no sync can change the code between
	# the check and the start; a sync, for its part, waits while a launch holds a lock.
	if [ "$code" != none ]; then
		git -C "$code" rev-parse --git-dir >/dev/null 2>&1 || { err "Not a git checkout: $code; name a checkout, or none, and in remote mode sync it first"; return 2; }
		local top sync_lock
		top="$(cd "$code" 2>/dev/null && cd "$(git_safe . rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null && pwd -P)" ||
			{ err "Not a git checkout: $code; name a checkout, or none, and in remote mode sync it first"; return 2; }
		case "$top" in
			"$ws") code=. ;;
			"$ws"/*) code="${top#"$ws"/}" ;;
			*) [ -z "${VRL_REMOTE:-}" ] || { err "The checkout must be in the remote workspace, where vrl_ssh.sh sync puts it: $code"; return 3; } ;;
		esac
		sync_lock="$(git_dir_of "$code")/vrl-sync.lock"
		if [ -d "$sync_lock" ] && [ -z "$(find "$sync_lock" -maxdepth 0 -mmin +10 2>/dev/null)" ]; then
			err "A sync of $code is in progress: launch again in a minute."
			return 3
		fi
	fi
	if [ "$plan_given" -gt 0 ] && [ "$code" != none ]; then
		local now_pin
		now_pin="$(print_pin "$code")" || return 1
		if [ "$now_pin" != "code=$code@$PLAN_COMMIT diff=$PLAN_DIFF" ] && ! pin_matches "$now_pin" "$code" "$PLAN_COMMIT" "$PLAN_DIFF"; then
			if [ -n "${VRL_REMOTE:-}" ]; then
				err "The mirror of $code is now $now_pin, not the plan's pin: a later sync moved it, or a run wrote files into it. Sync the plan's commit back with vrl_ssh.sh sync --commit; only a change to the code or a config needs a new approval."
			else
				err "The checkout $code changed since the plan was approved: it is now $now_pin; git -C $code status shows what changed, which may be a file a run wrote. Show the user: a change to the code or a config needs a new approval."
			fi
			return 3
		fi
	fi
	if [ -n "$gpus" ]; then
		gpus_busy "$gpus" || return 3
	fi

	# Never start a second copy; never overwrite a run that ended without being asked to.
	if [ -n "$session" ]; then
		if ! tmux list-sessions -F '#{session_name}' 2>/dev/null | grep -Fxq -- "$session"; then
			if [ "$new_session" = 1 ]; then
				tmux new-session -d -s "$session" -c "$ws" || { err "Could not create the tmux session $session: start it with the command in docs/AGENTS/machine.md, then launch again"; return 1; }
			else
				err "The tmux session $session does not exist: start it with the command in docs/AGENTS/machine.md, then launch again."
				return 2
			fi
		fi
		if tmux list-windows -t "$session:" -F '#{window_name}' 2>/dev/null | grep -Fxq -- "$window"; then
			err "$session:$window already exists, so the run is still going: monitor it, and never start a second copy."
			return 3
		fi
	fi
	if [ -f "$log_path" ]; then
		local state last_id last_pid
		state="$(log_state "$log_path")"
		last_id="$(printf '%s' "$state" | cut -f2)"
		last_pid="$(printf '%s' "$state" | cut -f3)"
		case "$state" in
			open*)
				if run_alive "$log_path" "$last_pid" "$last_id"; then
					err "Run $last_id still writes this log, so it is still going: monitor it, and never start a second copy."
					return 3
				fi
				[ "$restart" = 1 ] || {
					err "The log's last run has no footer and no process, so it crashed or was killed: read the end of its log, then pass --restart to start it again."
					return 3
				}
				close_dead_run "$log_path" "$last_id"
				;;
			finished0*)
				[ "$resume" = 1 ] || {
					err "The log's last run finished with exit code 0: give a rerun a new run name, or pass --resume to continue it."
					return 3
				}
				;;
			finished*)
				[ "$restart" = 1 ] || {
					err "The log's last run ended with exit code ${state#finished}: read its log, and pass --restart to start it again once the cause is fixed."
					return 3
				}
				;;
		esac
	fi

	# The header's code, outputs, and resources lines.
	local code_line="none" patch=""
	if [ "$code" != none ]; then
		local branch commit state_word="clean"
		commit="$(git_safe "$code" rev-parse --short=12 HEAD 2>/dev/null)" || { err "Not a git checkout: $code; name a checkout, or none, and in remote mode sync it first"; return 2; }
		branch="$(git_safe "$code" rev-parse --abbrev-ref HEAD 2>/dev/null)"
		local record
		record="$(git_dir_of "$code")/vrl-sync.branch"
		if [ "$branch" = HEAD ] && [ -f "$record" ]; then branch="$(head -n 1 "$record"), synced"; fi
		checkout_dirty "$code"
		case $? in
			1) ;;
			2) return 3 ;;
			*) state_word="dirty" ;;
		esac
		if [ "$state_word" = dirty ]; then
			[ -n "$outputs" ] || { err "The checkout $code is dirty: give --outputs so its diff is saved with the run."; return 3; }
			patch="$(save_diff "$code" "$outputs")" || return 1
		fi
		code_line="$code ($branch) @ $commit ($state_word)"
	fi
	[ -z "$outputs" ] || mkdir -p "$outputs" || { err "Could not create $outputs: fix the cause, such as a full disk, then launch again"; return 1; }
	if [ -z "$envname" ]; then
		if [ -n "${VIRTUAL_ENV:-}" ]; then envname="$(basename "$VIRTUAL_ENV")"
		elif [ -n "${CONDA_DEFAULT_ENV:-}" ]; then envname="$CONDA_DEFAULT_ENV"
		else envname="none"; fi
	fi
	local resources
	if [ -n "$gpus" ]; then
		resources="$machine, GPU $gpus ($(gpu_model "$gpus")), Python env $envname"
	else
		resources="$machine, no GPU, Python env $envname"
	fi
	local run_id
	run_id="$(od -An -N6 -tx1 /dev/urandom | tr -d ' \n')"
	local header
	header="$(printf '# command:   %s\n' "$cmd" | sed '2,$s/^/#            /')"
	[ "$plan_given" = 0 ] || header="$header$NL# plan:      $plan (sha256 $plan_sha), run $run"
	header="$header$NL$(printf '# purpose:   %s\n# code:      %s\n# outputs:   %s\n# resources: %s\n# run-id:    %s' \
		"$purpose" "$code_line" "${outputs:-none}" "$resources" "$run_id")"

	local where="" exports
	[ -z "$session" ] || where="$session:$window, "
	exports="export PATH=$(sq "$HOME/.local/bin:$PATH") CUDA_VISIBLE_DEVICES=$(sq "$gpus") CUDA_DEVICE_ORDER=PCI_BUS_ID PYTHONUNBUFFERED=1"
	if [ -n "$outputs" ]; then
		case "$outputs" in /*) exports="$exports VRL_OUTPUTS=$(sq "$outputs")" ;; *) exports="$exports VRL_OUTPUTS=$(sq "$ws/${outputs%/}")" ;; esac
	fi
	[ -z "${VIRTUAL_ENV:-}" ] || exports="$exports VIRTUAL_ENV=$(sq "$VIRTUAL_ENV")"

	# The shell that runs the command writes the header, with its own PID, and the footer. It runs from a
	# file, so that no shell of the user's quotes it. The command runs in a session of its own, with no
	# terminal, so that a signal to this shell, such as closing the tmux window or `kill <PID>`, reaches
	# every process of the run: TERM first, KILL 10 seconds later. The footer waits until all have ended.
	local runner start_child
	runner="$(mktemp "${TMPDIR:-/tmp}/vrl-run-$run_id.XXXXXX")" || { err "Could not write the run's script: fix the cause, such as a full disk, then launch again"; return 1; }
	if command -v perl >/dev/null 2>&1; then
		start_child="perl -MPOSIX -e 'POSIX::setsid(); \$SIG{INT} = \$SIG{HUP} = \"DEFAULT\"; exec @ARGV or exit 127' bash -c $(sq "$cmd") $(sq "vrl-run-$run_id") >>$(sq "$log_path") 2>&1 </dev/null &"
	else
		start_child="set -m; bash -c $(sq "$cmd") $(sq "vrl-run-$run_id") >>$(sq "$log_path") 2>&1 </dev/null & set +m"
	fi
	cat >"$runner" <<RUNNER
rm -f -- $(sq "$runner")
umask 077
unset CDPATH
cd $(sq "$ws") || exit 97
exec 2>>$(sq "$log_path")
$(declare -f load_env_file)
load_env_file ./.env
$exports
unset ANTHROPIC_API_KEY OPENAI_API_KEY GH_TOKEN GITHUB_TOKEN NOTION_TOKEN NOTION_API_KEY
ts() { local z; z=\$(date +%z); printf '%s %s:%s' "\$(date '+%Y-%m-%d %H:%M:%S')" "\${z%??}" "\${z#???}"; }
stop=0 child=
trap 'stop=1; [ -n "\$child" ] && kill -TERM -- -"\$child" 2>/dev/null' HUP INT TERM
start=\$(date +%s)
{ printf '%s\n' $(sq "$header"); printf '# session:   %sPID %s\n' $(sq "$where") "\$\$"; printf '# started:   %s\n' "\$(ts)"; printf '# ---------- stdout + stderr ----------\n'; } >>$(sq "$log_path")
$start_child
child=\$!
[ "\$stop" = 0 ] || kill -TERM -- -"\$child" 2>/dev/null
n=0
while :; do
  wait "\$child"; rc=\$?
  kill -0 "\$child" 2>/dev/null || break
  # A signal ended the wait while the command still runs: give it 10 seconds, then KILL its group.
  while kill -0 "\$child" 2>/dev/null; do
    sleep 1; n=\$((n + 1))
    [ \$n -lt 10 ] || kill -KILL -- -"\$child" 2>/dev/null
  done
done
n=0
while kill -0 -- -"\$child" 2>/dev/null; do
  [ \$n = 0 ] && kill -TERM -- -"\$child" 2>/dev/null
  [ \$n = 10 ] && kill -KILL -- -"\$child" 2>/dev/null
  [ \$n -ge 15 ] && break
  sleep 1; n=\$((n + 1))
done
[ -n "\$(tail -c 1 $(sq "$log_path"))" ] && printf '\n' >>$(sq "$log_path")
d=\$((\$(date +%s) - start))
{ printf '# ---------- end %s ----------\n' $(sq "$run_id"); printf '# finished:  %s (%d:%02d:%02d), exit code %d\n' "\$(ts)" \$((d / 3600)) \$((d % 3600 / 60)) \$((d % 60)) "\$rc"; } >>$(sq "$log_path")
RUNNER

	if [ -n "$session" ]; then
		tmux new-window -d -t "$session:" -n "$window" -c "$ws" "bash $(sq "$runner")" ||
			{ rm -f "$runner"; err "tmux could not open a window in $session: check the session, or use --nohup, then launch again"; return 1; }
	elif command -v perl >/dev/null 2>&1; then
		# A session of its own, with SIGINT and SIGHUP back to their defaults, which `&` would ignore.
		perl -MPOSIX -e 'POSIX::setsid(); $SIG{INT} = $SIG{HUP} = "DEFAULT"; exec @ARGV or exit 127' \
			bash "$runner" >/dev/null 2>&1 </dev/null &
	elif command -v setsid >/dev/null 2>&1; then
		setsid bash "$runner" >/dev/null 2>&1 </dev/null &
	else
		nohup bash "$runner" >/dev/null 2>&1 </dev/null &
	fi

	# Report the run as soon as its header is there, then wait up to --wait seconds for its end.
	local waited=0
	while [ "$waited" -lt 30 ] && ! grep -Fq "# run-id:    $run_id" "$log_path" 2>/dev/null; do
		sleep 1
		waited=$((waited + 1))
	done
	if ! grep -Fq "# run-id:    $run_id" "$log_path" 2>/dev/null; then
		err "The command did not start within 30 s: no header with run-id $run_id in $log. Check the log${session:+ and the tmux session} before launching it again."
		return 1
	fi
	rmdir "$LOCK" 2>/dev/null
	printf 'log       %s\n' "$log"
	printf 'run-id    %s\n' "$run_id"
	printf 'session   %s\n' "$(grep -A1 -F "# run-id:    $run_id" "$log_path" | sed -n 's/^# session: *//p')"
	printf 'started   %s\n' "$(grep -A2 -F "# run-id:    $run_id" "$log_path" | sed -n 's/^# started: *//p')"
	printf 'code      %s\n' "$code_line"
	[ -z "$patch" ] || printf 'diff      %s\n' "$patch"
	waited=0
	while [ "$waited" -lt "$wait_s" ] && ! grep -Fq -- "# ---------- end $run_id ----------" "$log_path"; do
		sleep 1
		waited=$((waited + 1))
	done
	if ! grep -Fq -- "# ---------- end $run_id ----------" "$log_path"; then
		printf 'status    running after %s s; read its footer later\n' "$wait_s"
		return 0
	fi
	local rc
	rc="$(grep -A1 -F -- "# ---------- end $run_id ----------" "$log_path" | sed -n 's/.*exit code \([0-9][0-9]*\).*/\1/p')"
	printf 'status    ended with exit code %s; the end of the log:\n' "${rc:-unknown}"
	tail -n 20 "$log_path"
	[ "${rc:-1}" = 0 ]
}

NL='
'
CR="$(printf '\r')"
SECRET_RE='(hf_[A-Za-z0-9]{20,}|sk-[A-Za-z0-9_-]{20,}|gh[pousr]_[A-Za-z0-9]{20,}|xox[bpas]-[A-Za-z0-9-]{10,}|AKIA[0-9A-Z]{16}|(^|[^A-Za-z0-9_])((hf|wandb|openai|anthropic|gh|github|api|auth|access|secret|private)_?(token|key|secret)|password|passwd)=[^$[:space:]])'

err() { printf 'launch_run: %s\n' "$*" >&2; }
mirror_fix() {
	err "Once the user decides: discard a change through vrl_ssh.sh run, by deleting the untracked file or with git -C $1 checkout -- <path>; to keep one, read it with git -C $1 diff, discard it, redo it on the local machine, commit, and sync again."
}

# Quote a string for any shell of the sh family.
sq() {
	local s=${1//\'/\'\\\'\'}
	printf "'%s'" "$s"
}

# Export the variables of an .env file without running it: one literal NAME=value per line, quotes
# around the value dropped. Names that could make a program run other code are skipped.
load_env_file() {
	local _vrl_line _vrl_name _vrl_value
	while IFS= read -r _vrl_line || [ -n "$_vrl_line" ]; do
		_vrl_line="${_vrl_line%$'\r'}"
		case "$_vrl_line" in "" | "#"*) continue ;; esac
		_vrl_name="${_vrl_line%%=*}"
		case "$_vrl_name" in
			"$_vrl_line" | "" | [0-9]* | *[!A-Za-z0-9_]*)
				printf 'launch_run: .env: skipped a line that is not NAME=value\n' >&2
				continue
				;;
			_vrl_* | LD_* | DYLD_* | BASH_* | ENV | HOME | PATH | CDPATH | IFS | PS4 | PROMPT_COMMAND | GLOBIGNORE | \
				SHELLOPTS | BASHOPTS | POSIXLY_CORRECT | PYTHONSTARTUP | PYTHONHOME | PYTHONINSPECT | \
				PERL5OPT | PERL5LIB | PERLLIB | RUBYOPT | NODE_OPTIONS | JAVA_TOOL_OPTIONS | _JAVA_OPTIONS)
				printf 'launch_run: .env: skipped %s, which could change what runs\n' "$_vrl_name" >&2
				continue
				;;
		esac
		_vrl_value="${_vrl_line#*=}"
		case "$_vrl_value" in
			\"*\") _vrl_value="${_vrl_value#\"}"; _vrl_value="${_vrl_value%\"}" ;;
			\'*\') _vrl_value="${_vrl_value#\'}"; _vrl_value="${_vrl_value%\'}" ;;
		esac
		export "$_vrl_name=$_vrl_value"
	done <"$1"
}

scheduler_here() {
	[ -n "${SLURM_JOB_ID:-}${PBS_JOBID:-}${LSB_JOBID:-}" ] || { [ -n "${JOB_ID:-}" ] && [ -n "${SGE_ROOT:-}" ]; } ||
		command -v sbatch >/dev/null 2>&1 || command -v qsub >/dev/null 2>&1 || command -v bsub >/dev/null 2>&1
}

# git without the repository's own hooks, fsmonitor, or external diff tools.
git_safe() {
	local dir="$1"
	shift
	git -C "$dir" -c core.fsmonitor= -c core.hooksPath=/dev/null -c core.quotepath=off -c color.ui=false "$@"
}

# The absolute git folder of a checkout.
git_dir_of() {
	(cd "$1" 2>/dev/null && cd "$(git_safe . rev-parse --git-dir 2>/dev/null)" 2>/dev/null && pwd -P)
}

# True when this folder or one above it holds docs/AGENTS/remote.md: the local machine of a remote-mode
# workspace.
in_remote_workspace() {
	local d s
	for s in "$PWD" "$(pwd -P)"; do
		d="$s"
		while :; do
			[ ! -f "$d/docs/AGENTS/remote.md" ] || return 0
			[ "$d" != / ] && [ -n "$d" ] || break
			d="$(dirname "$d")"
		done
	done
	return 1
}

sha256_of() {
	if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | cut -d' ' -f1
	elif command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | cut -d' ' -f1
	else openssl dgst -sha256 "$1" | sed 's/.*= //'; fi
}

# What makes the checkout differ from its commit, untracked files and binaries included, as a patch
# that `git apply` on the commit turns back into the checkout.
diff_content() {
	local code="$1" f
	git_safe "$code" diff --no-ext-diff --no-textconv --ignore-submodules=none --binary --src-prefix=a/ --dst-prefix=b/ HEAD
	git_safe "$code" ls-files -o --exclude-per-directory=.gitignore -z | while IFS= read -r -d '' f; do
		(cd "$code" && git -c core.fsmonitor= -c core.hooksPath=/dev/null -c color.ui=false \
			diff --no-index --no-ext-diff --no-textconv --binary --src-prefix=a/ --dst-prefix=b/ -- /dev/null "$f")
	done
	# `git diff --no-index` exits 1 whenever the files differ, which they always do here.
	return 0
}

# Whether the checkout differs from its commit: 0 dirty, 1 clean, 2 cannot tell. Only the committed
# .gitignore files hide an untracked file, not .git/info/exclude or a global excludes file, and a file
# marked skip-worktree or assume-unchanged, whose changes git would not show, is refused.
checkout_dirty() {
	local code="$1"
	if git_safe "$code" ls-files -v | awk '/^[a-zS] / { n++ } END { exit !n }'; then
		err "$code marks files skip-worktree or assume-unchanged, which hides their changes: clear the marks with git update-index --no-skip-worktree --no-assume-unchanged <file>"
		return 2
	fi
	git_safe "$code" diff --quiet --no-ext-diff --ignore-submodules=none HEAD -- || return 0
	[ -z "$(git_safe "$code" ls-files -o --exclude-per-directory=.gitignore)" ] || return 0
	return 1
}

# The words that pin a checkout: `code=<checkout>@<commit> diff=<clean or the diff's hash>`.
print_pin() {
	local code="$1" commit tmp hash
	if [ "$code" = none ]; then
		printf 'code=none\n'
		return 0
	fi
	commit="$(git_safe "$code" rev-parse --short=12 HEAD 2>/dev/null)" || { err "Not a git checkout: $code; name a checkout, or none, and in remote mode sync it first"; return 1; }
	checkout_dirty "$code"
	case $? in
		1) printf 'code=%s@%s diff=clean\n' "$code" "$commit"; return 0 ;;
		2) return 1 ;;
	esac
	tmp="$(mktemp "${TMPDIR:-/tmp}/vrl-pin.XXXXXX")" || return 1
	diff_content "$code" >"$tmp"
	hash="$(sha256_of "$tmp" | cut -c1-12)"
	rm -f "$tmp"
	printf 'code=%s@%s diff=%s\n' "$code" "$commit" "$hash"
}

# Whether a pin taken now matches the plan's, allowing a longer or shorter commit prefix.
pin_matches() {
	local now="$1" code="$2" want_commit="$3" want_diff="$4" got_commit got_diff
	got_commit="$(printf '%s' "$now" | sed -n 's/^code=[^@]*@\([0-9a-f]*\) .*/\1/p')"
	got_diff="$(printf '%s' "$now" | sed -n 's/.* diff=\(.*\)$/\1/p')"
	[ -n "$got_commit" ] && [ "$got_diff" = "$want_diff" ] || return 1
	case "$got_commit" in "$want_commit"*) return 0 ;; esac
	case "$want_commit" in "$got_commit"*) return 0 ;; esac
	return 1
}

# Load one run of an approved plan file into PLAN_CMD, PLAN_GPUS, PLAN_CODE, PLAN_COMMIT, PLAN_DIFF,
# PLAN_ENV, and PLAN_BASE, after checking where the file is, who may write it, and its hash. The file
# is read once, into a private copy, which is both hashed and parsed.
plan_load() {
	local ws="$1" plan="$2" run="$3" want="$4" real plans copy got parsed info word
	case "$run" in "" | [!A-Za-z0-9]* | *[!A-Za-z0-9_.-]*) err "A run name starts with a letter or digit and holds only letters, digits, ., - and _"; return 1 ;; esac
	[ -f "$plan" ] && [ ! -L "$plan" ] || { err "No such plan file, or it is a symlink: $plan; in remote mode, sync the workspace repository first"; return 1; }
	plans="$(cd "$ws/docs/plans" 2>/dev/null && pwd -P)" || { err "This workspace has no docs/plans/: run from the workspace root, and in remote mode sync the workspace repository first"; return 1; }
	real="$(cd "$(dirname "$plan")" && pwd -P)/$(basename "$plan")"
	[ "$(dirname "$real")" = "$plans" ] || { err "The plan file must sit directly in docs/plans/ of this workspace: $plan"; return 1; }
	case "$(basename "$real")" in
		[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-*.md) ;;
		*) err "A plan file is named <date>-<ID>.md: $plan"; return 1 ;;
	esac
	[ -O "$real" ] || { err "The plan file is not yours: $plan; stop and report"; return 1; }
	if [ -n "$(find "$real" \( -perm -020 -o -perm -002 \) -print 2>/dev/null)" ]; then
		err "Others may write the plan file: $plan. Make it writable by you only, with chmod go-w, which keeps its hash."
		return 1
	fi
	copy="$(mktemp "${TMPDIR:-/tmp}/vrl-plan.XXXXXX")" || return 1
	cp "$real" "$copy" || { rm -f "$copy"; return 1; }
	got="$(sha256_of "$copy")"
	if [ "$(printf '%s' "$got" | tr 'A-F' 'a-f')" != "$(printf '%s' "$want" | tr 'A-F' 'a-f')" ]; then
		rm -f "$copy"
		err "The plan file does not have the SHA-256 recorded at approval, so it changed or the hash is wrong: check the hash, and in remote mode sync the plan's commit back with vrl_ssh.sh sync --commit; a changed plan needs a new approval."
		return 1
	fi
	local other
	for other in "$plans"/*.md; do
		[ -f "$other" ] && [ "$other" != "$real" ] || continue
		if [ "$(sha256_of "$other")" = "$got" ]; then
			rm -f "$copy"
			err "Another plan file has the same content: $(basename "$other"). An approval holds for one plan file only: tell the user."
			return 1
		fi
	done
	# Only what a reader sees counts: no HTML comment, and run=<run> in one line only, its block's.
	if grep -q '<!--' "$copy"; then
		rm -f "$copy"
		err "The plan file holds an HTML comment, which hides text from a reader: remove it, then ask the user to approve the plan again."
		return 1
	fi
	if [ "$(tr -d '\r' <"$copy" | grep -Ec -- "(^|[^A-Za-z0-9_])run=$(printf '%s' "$run" | sed 's/\./\\./g')([^A-Za-z0-9_.-]|\$)")" -gt 1 ]; then
		rm -f "$copy"
		err "The plan file names run=$run more than once, but only its block's info string may: fix the plan, then ask the user to approve it again."
		return 1
	fi
	# A fence of three or more backticks or tildes, indented at most three spaces, opens a block, which
	# closes only at a line of the same character alone, at least as long. The run's block is the one
	# whose info string holds the word run=<run>; its first output line is the info string.
	parsed="$(tr -d '\r' <"$copy" | awk -v run="$run" '
		function fence(line,   m) {
			if (match(line, /^ ? ? ?(````*|~~~~*)/)) { m = substr(line, RSTART, RLENGTH); sub(/^ */, "", m); return m }
			return ""
		}
		{
			f = fence($0)
			if (inside) {
				t = $0; sub(/^ ? ? ?/, "", t); sub(/[ \t]*$/, "", t)
				closes = (f != "" && length(t) >= len && t == substr(f, 1, length(t)) && substr(f, 1, 1) == ch)
				if (closes) { inside = 0; next }
				if (mine) print
				next
			}
			if (f != "") {
				info = $0; sub(/^ ? ? ?[`~][`~]*/, "", info)
				n = split(info, words, /[ \t]+/)
				mine = 0
				for (i = 1; i <= n; i++) if (words[i] == "run=" run) mine = 1
				inside = 1; ch = substr(f, 1, 1); len = length(f)
				if (mine) { found++; print info }
			}
		}
		END { if (inside && mine) exit 5; if (found != 1) exit (found == 0 ? 3 : 4) }
	')"
	case $? in
		0) ;;
		3) rm -f "$copy"; err "The plan has no block for run $run, a fenced block indented at most three spaces whose info string holds run=$run: check the run name with --status"; return 1 ;;
		5) rm -f "$copy"; err "The plan's block for run $run never closes: fix the plan, then ask the user to approve it again"; return 1 ;;
		*) rm -f "$copy"; err "The plan has more than one block for run $run: fix the plan, then ask the user to approve it again"; return 1 ;;
	esac
	rm -f "$copy"
	info="$(printf '%s\n' "$parsed" | head -n 1)"
	PLAN_CMD="$(printf '%s\n' "$parsed" | sed '1d')"
	PLAN_GPUS="" PLAN_CODE="" PLAN_COMMIT="" PLAN_DIFF="" PLAN_ENV=""
	PLAN_BASE="$(basename "$real" .md)"
	local -a words=()
	read -r -a words <<<"$info"
	for word in ${words[@]+"${words[@]}"}; do
		case "$word" in
			gpus=*) PLAN_GPUS="${word#gpus=}" ;;
			code=none) PLAN_CODE=none ;;
			code=*@*) PLAN_CODE="${word#code=}"; PLAN_COMMIT="${PLAN_CODE##*@}"; PLAN_CODE="${PLAN_CODE%@*}" ;;
			diff=*) PLAN_DIFF="${word#diff=}" ;;
			env=*) PLAN_ENV="${word#env=}" ;;
		esac
	done
	[ -n "$(printf '%s' "$PLAN_CMD" | tr -d '[:space:]')" ] || { err "The plan's block for run $run is empty: fix the plan, then ask the user to approve it again"; return 1; }
	case "$PLAN_GPUS" in "" | *[!0-9]*) err "The block for run $run needs gpus=<count>: fix the plan, then ask the user to approve it again"; return 1 ;; esac
	[ -n "$PLAN_CODE" ] || { err "The block for run $run needs code=<checkout>@<commit> diff=<...>, from launch_run.sh --pin, or code=none: fix the plan, then ask the user to approve it again"; return 1; }
	if [ "$PLAN_CODE" != none ]; then
		case "$PLAN_COMMIT" in "" | *[!0-9a-f]*) PLAN_COMMIT="" ;; esac
		[ "${#PLAN_COMMIT}" -ge 12 ] || { err "The block for run $run needs code=<checkout>@<commit>, with the 12 hex digits launch_run.sh --pin prints: fix the plan, then ask the user to approve it again"; return 1; }
		case "$PLAN_DIFF" in clean | [0-9a-f]*) ;; *) err "The block for run $run needs diff=clean or diff=<hash>, from launch_run.sh --pin: fix the plan, then ask the user to approve it again"; return 1 ;; esac
		case "$PLAN_CODE" in /* | *..* | "") err "The block's checkout must be a folder of the workspace, not $PLAN_CODE: fix the plan, then ask the user to approve it again"; return 1 ;; esac
	fi
}

# The state of a log's last run: "open<TAB>id<TAB>pid<TAB>checkout", "finished<code><TAB>id", or "none".
# While a run with a run-id is open, only its own end marker counts.
log_state() {
	awk -v OFS='\t' '
		open && oid != "" { if ($0 == "# ---------- end " oid " ----------") { open = 0; closing = 1 }; next }
		/^# run-id:/ { id = $3 } /^# session:/ { s = $0 } /^# code:/ { c = $0 }
		/^# ---------- stdout/ { open = 1; oid = id; os = s; oc = c; id = ""; c = ""; fin = ""; next }
		/^# ---------- end/ && open { open = 0; closing = 1; next }
		closing && /^# finished:/ { fin = $0; closing = 0 }
		END {
			if (open) {
				pid = ""; if (match(os, /PID [0-9]+/)) pid = substr(os, RSTART + 4, RLENGTH - 4)
				sub(/^# code: */, "", oc); sub(/ .*/, "", oc)
				print "open", oid, pid, oc
			}
			else if (fin != "") { code = fin; sub(/.*exit code /, "", code); sub(/[^0-9a-z].*/, "", code); print "finished" code, oid }
			else print "none"
		}' "$1"
}

# Whether one of this user's processes has the file open for writing: 0 yes, 1 no, 2 cannot tell.
# Every process of a run holds its log so, the command's children included, even after its shell is gone.
writers_of() {
	local f="$1" real
	real="$(cd "$(dirname "$f")" 2>/dev/null && pwd -P)/$(basename "$f")"
	if [ "$(uname -s)" = Linux ] && [ -d /proc/self/fd ]; then
		{ ls -l /proc/[0-9]*/fd 2>/dev/null || true; } | awk -v f="$real" '$1 ~ /^l.w/ { i = index($0, " -> "); if (i && substr($0, i + 4) == f) n++ } END { exit !n }'
		return
	fi
	command -v lsof >/dev/null 2>&1 || return 2
	lsof -w -Fan -- "$real" 2>/dev/null | awk '/^a/ && /[wu]/ { n++ } END { exit !n }'
}

# True when the run still writes its log, or, where that cannot be told, when the PID of its shell is
# alive and its command line still holds the run-id.
run_alive() {
	local log="$1" pid="$2" id="$3" rc
	writers_of "$log"
	rc=$?
	[ "$rc" = 2 ] || return "$rc"
	[ -n "$pid" ] && kill -0 "$pid" 2>/dev/null || return 1
	[ -n "$id" ] || return 0
	ps -o command= -p "$pid" 2>/dev/null | grep -Fq -- "$id"
}

epoch_of() { stat -c %Y "$1" 2>/dev/null || stat -f %m "$1"; }
format_epoch() {
	local z out
	out="$(date -r "$1" '+%Y-%m-%d %H:%M:%S %z' 2>/dev/null || date -d "@$1" '+%Y-%m-%d %H:%M:%S %z')"
	z="${out##* }"
	printf '%s %s:%s' "${out% *}" "${z%??}" "${z#???}"
}

# Close a crashed run with a footer at the log's last write, before its restart.
close_dead_run() {
	local log="$1" id="$2" when
	when="$(format_epoch "$(epoch_of "$log")")"
	[ -z "$(tail -c 1 "$log")" ] || printf '\n' >>"$log"
	{
		printf '# ---------- end %s ----------\n' "$id"
		printf '# finished:  %s (unknown), exit code unknown: closed by a restart at the log'"'"'s last write\n' "$when"
	} >>"$log"
}

# limited <seconds> <command...>: run it, ending its process group at the limit; 124 when cut.
limited() {
	local limit="$1"
	shift
	if command -v timeout >/dev/null 2>&1; then timeout -k 5 "$limit" "$@"
	elif command -v gtimeout >/dev/null 2>&1; then gtimeout -k 5 "$limit" "$@"
	elif command -v perl >/dev/null 2>&1; then
		perl -e '$SIG{ALRM} = sub { kill "TERM", -$pid; sleep 2; kill "KILL", -$pid; exit 124 };
			$pid = fork; if (!$pid) { setpgrp(0, 0); exec @ARGV[1..$#ARGV] or exit 127 }
			alarm $ARGV[0]; waitpid $pid, 0; exit($? & 127 ? 128 + ($? & 127) : $? >> 8)' "$limit" "$@"
	else "$@"; fi
}

# Whether any of the given GPUs has a process on it; also refuses when that cannot be told.
gpus_busy() {
	local ids="$1" map apps id uuid
	command -v nvidia-smi >/dev/null 2>&1 || return 0
	map="$(limited 15 nvidia-smi --query-gpu=index,uuid --format=csv,noheader 2>/dev/null)" ||
		{ err "nvidia-smi failed, so whether the GPUs are free cannot be told: try again in a minute; if it fails again, stop and report"; return 1; }
	apps="$(limited 15 nvidia-smi --query-compute-apps=gpu_uuid --format=csv,noheader 2>/dev/null)" ||
		{ err "nvidia-smi could not list the processes, so whether the GPUs are free cannot be told: try again in a minute; if it fails again, stop and report"; return 1; }
	for id in $(printf '%s' "$ids" | tr ',' ' '); do
		uuid="$(printf '%s\n' "$map" | awk -F', *' -v i="$id" '$1 == i { print $2 }')"
		[ -n "$uuid" ] || { err "GPU $id is not on this machine: run resources.sh to see its GPUs"; return 1; }
		if printf '%s\n' "$apps" | tr -d ' ' | grep -Fxq -- "$uuid"; then
			err "GPU $id has a process on it, so it is not free: pick a free one with resources.sh, or wait"
			return 1
		fi
	done
}

# The models of the given GPUs, such as `NVIDIA A100-SXM4-80GB`, or `unknown` without nvidia-smi.
gpu_model() {
	local models
	models="$(limited 15 nvidia-smi --query-gpu=index,name --format=csv,noheader 2>/dev/null |
		awk -F', *' -v ids=",$1," 'index(ids, "," $1 ",") { print $2 }' | sort -u |
		awk '{ printf "%s%s", (NR > 1 ? " + " : ""), $0 }')"
	printf '%s' "${models:-unknown}"
}

# Save what makes the checkout dirty in the output folder, readable by you only, under a new name if
# an earlier diff differs.
save_diff() {
	local code="$1" outputs="$2" file tmp
	mkdir -p "$outputs" || { err "Could not create $outputs: fix the cause, such as a full disk, then launch again"; return 1; }
	tmp="$(mktemp "$outputs/.git_diff.XXXXXX")" || { err "Could not write in $outputs: fix the cause, such as a full disk, then launch again"; return 1; }
	diff_content "$code" >"$tmp" || { err "Could not save the diff of $code: fix the cause, such as a full disk, then launch again"; return 1; }
	if grep -Eiq "$SECRET_RE" "$tmp"; then
		err "Warning: the saved diff seems to hold a secret; it is readable by you only. Check $outputs, and tell the user."
	fi
	file="$outputs/git_diff.patch"
	if [ -f "$file" ] && ! cmp -s "$tmp" "$file"; then
		file="$outputs/git_diff-$(date +%Y%m%d-%H%M%S).patch"
	fi
	mv "$tmp" "$file" && chmod 600 "$file"
	printf '%s' "$file"
}

# The run names of a plan: the run=<run> words of the fences that open a block, as plan_load reads them.
plan_runs() {
	tr -d '\r' <"$1" | awk '
		function fence(line,   m) {
			if (match(line, /^ ? ? ?(````*|~~~~*)/)) { m = substr(line, RSTART, RLENGTH); sub(/^ */, "", m); return m }
			return ""
		}
		{
			f = fence($0)
			if (inside) {
				t = $0; sub(/^ ? ? ?/, "", t); sub(/[ \t]*$/, "", t)
				if (f != "" && length(t) >= len && t == substr(f, 1, length(t)) && substr(f, 1, 1) == ch) inside = 0
				next
			}
			if (f != "") {
				inside = 1; ch = substr(f, 1, 1); len = length(f)
				info = $0; sub(/^ ? ? ?[`~][`~]*/, "", info)
				n = split(info, words, /[ \t]+/)
				for (i = 1; i <= n; i++) if (words[i] ~ /^run=/ && !seen[words[i]]++) print substr(words[i], 5)
			}
		}'
}

# The state of each run of a plan, or of one, and the end of its log; it changes nothing.
plan_status() {
	local plan="$1" one="$2" base runs r log state id pid
	[ -f "$plan" ] || { err "No such plan file: $plan; in remote mode, sync the workspace repository first"; return 2; }
	case "$(basename "$plan")" in
		[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-*.md) ;;
		*) err "A plan file is named <date>-<ID>.md: $plan"; return 2 ;;
	esac
	base="$(basename "$plan" .md)"
	if [ -n "$one" ]; then runs="$one"; else runs="$(plan_runs "$plan")"; fi
	[ -n "$runs" ] || { err "The plan has no block with run=<run>: $plan"; return 2; }
	for r in $runs; do
		case "$r" in [!A-Za-z0-9]* | *[!A-Za-z0-9_.-]*) printf 'note: skipped run=%s, which is not a run name

' "$r"; continue ;; esac
		log="logs/$base/$r.log"
		printf 'run       %s\nlog       %s\n' "$r" "$log"
		if [ ! -f "$log" ] || [ -L "$log" ]; then
			printf 'state     not started\n\n'
			continue
		fi
		state="$(log_state "$log")"
		case "$state" in
			open*)
				id="$(printf '%s' "$state" | cut -f2)"
				pid="$(printf '%s' "$state" | cut -f3)"
				if run_alive "$log" "$pid" "$id"; then
					printf 'state     running, PID %s\n' "$pid"
				else
					printf 'state     stopped without a footer: it crashed or was killed\n'
				fi
				;;
			finished*)
				state="${state%%$'\t'*}"
				printf 'state     finished, exit code %s\n' "${state#finished}"
				;;
			*) printf 'state     no run in the log yet\n' ;;
		esac
		printf -- '--- the end of the log ---\n'
		tail -n 20 "$log" | tail -c 4096
		printf '\n'
	done
}

# The checkouts a sync may name: `.`, the workspace repository; a folder at the workspace root; and
# worktrees/<name> or ref_repos/<name>.
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

# Whether the folder is the top of a git checkout of its own.
is_checkout_top() {
	local top
	[ -d "$1" ] && [ ! -L "$1" ] || return 1
	top="$(git_safe "$1" rev-parse --show-toplevel 2>/dev/null)" || return 1
	[ "$(cd "$top" && pwd -P)" = "$(cd "$1" && pwd -P)" ]
}

# vrl_ssh.sh sync, on the remote host: make the folder a git repository that the sync can push to.
sync_prepare() {
	local dir="$1"
	umask 022
	checkout_form "$dir" || { err "Not a checkout a sync may name: $dir"; return 2; }
	is_checkout_top "$dir" && return 0
	if [ -L "$dir" ]; then
		err "$dir is a symlink on the remote host, so it cannot be a mirror: tell the user"
		return 3
	fi
	if [ -e "$dir" ]; then
		[ -d "$dir" ] || { err "$dir on the remote host is not a folder, so it cannot be a mirror: tell the user"; return 3; }
		if [ "$dir" != . ] && [ -n "$(ls -A "$dir" 2>/dev/null)" ]; then
			err "$dir on the remote host holds files but is no git repository: show the user, who decides where they go; never touch them unless they ask."
			return 3
		fi
	fi
	mkdir -p "$dir" && git init -q --template= "$dir" || { err "Could not create the mirror $dir: fix the cause, such as a full disk, then sync again"; return 4; }
}

# The logs of runs that use the checkout, by the code line of their open run's own header, and are
# still going or cannot be told dead.
live_runs_of() {
	local want="$1" f id state pid
	[ -d logs ] || return 0
	find -H logs -name '*.log' -type f 2>/dev/null | while IFS= read -r f; do
		state="$(log_state "$f")"
		case "$state" in open*) ;; *) continue ;; esac
		[ "$(printf '%s' "$state" | cut -f4)" = "$want" ] || continue
		id="$(printf '%s' "$state" | cut -f2)"
		pid="$(printf '%s' "$state" | cut -f3)"
		if run_alive "$f" "$pid" "$id"; then printf '%s\n' "$f"; fi
	done
}

# vrl_ssh.sh sync, on the remote host: check out the commit the sync has just pushed in the mirror of
# a checkout, or add the mirror of a worktree. It refuses, with exit code 3 and nothing changed, while
# a run or a launch uses the checkout, or while the mirror holds changes that no sync made. A checkout
# that failed half way is marked pending, so that the next sync finishes it.
sync_apply() {
	local dir="$1" commit="$2" branch="$3" owner="$4" repo gd old="" busy there plans f pending prev
	umask 022
	checkout_form "$dir" || { err "Not a checkout a sync may name: $dir"; return 2; }
	[ -z "$owner" ] || checkout_form "$owner" || { err "Not a checkout a sync may name: $owner"; return 2; }
	case "$commit" in "" | *[!0-9a-f]*) err "--sync-apply needs --commit with the full hash"; return 2 ;; esac
	case "$branch" in "" | *[!A-Za-z0-9._/-]*) branch="HEAD" ;; esac
	repo="${owner:-$dir}"
	is_checkout_top "$repo" || { err "$repo is no mirror yet: sync again once; if that fails, stop and report"; return 4; }
	git_safe "$repo" cat-file -e "$commit^{commit}" 2>/dev/null || { err "Commit $commit did not reach $repo: sync again once; if that fails, stop and report"; return 4; }

	if [ -n "$owner" ] && ! is_checkout_top "$dir"; then
		# A new worktree of the owner's mirror, made here, so that its git files hold this host's paths.
		if [ -L "$dir" ] || { [ -e "$dir" ] && [ -n "$(ls -A "$dir" 2>/dev/null)" ]; }; then
			err "$dir on the remote host holds files but is no worktree of $owner: show the user, who decides where they go; never touch them unless they ask."
			return 3
		fi
		[ ! -d "$dir" ] || rmdir "$dir"
		mkdir -p "$(dirname "$dir")" || return 4
		# The registration of a worktree folder that was deleted would block the add.
		git_safe "$owner" worktree prune 2>/dev/null
		git_safe "$owner" -c core.autocrlf=false -c advice.detachedHead=false worktree add -q --detach \
			"$(cd "$(dirname "$dir")" && pwd -P)/$(basename "$dir")" "$commit" || { err "Could not add the worktree $dir: fix the cause, such as a full disk, then sync again"; return 4; }
	else
		is_checkout_top "$dir" || { err "$dir is no mirror yet: sync again once; if that fails, stop and report"; return 4; }
		if [ -n "$owner" ] && [ "$(git_dir_of "$dir")" != "$(git_dir_of "$owner")/worktrees/$(basename "$(git_dir_of "$dir")")" ]; then
			err "$dir on the remote host is no worktree of $owner: show the user, who decides where it goes; never touch it unless they ask."
			return 3
		fi
		gd="$(git_dir_of "$dir")" && [ -d "$gd" ] || { err "Could not find the git folder of $dir: stop and report"; return 4; }
		old="$(git_safe "$dir" rev-parse -q --verify 'HEAD^{commit}' 2>/dev/null)"
		pending="$gd/vrl-sync.pending"
		prev=""
		[ ! -f "$pending" ] || prev="$(sed -n 2p "$pending")"
		if [ "$old" = "$commit" ] && [ ! -f "$pending" ] && { checkout_dirty "$dir"; [ $? = 1 ]; }; then
			# Already there: nothing changes, so a run that uses the checkout is no reason to refuse.
			:
		else
			SYNC_LOCK="$gd/vrl-sync.lock"
			if ! mkdir "$SYNC_LOCK" 2>/dev/null; then
				if [ -n "$(find "$SYNC_LOCK" -maxdepth 0 -mmin +10 2>/dev/null)" ]; then rmdir "$SYNC_LOCK" 2>/dev/null; fi
				mkdir "$SYNC_LOCK" 2>/dev/null || { err "Another sync of $dir is in progress: sync again in a minute."; return 3; }
			fi
			trap 'rmdir "$SYNC_LOCK" 2>/dev/null' EXIT
			# Launch locks first, then runs: a launch that took its lock after this check sees the sync lock,
			# and one that released it before has written its header, which the scan below finds.
			if [ -d logs ] && [ -n "$(find -H logs -name '*.log.lock' -type d -mmin -2 2>/dev/null | head -n 1)" ]; then
				err "A launch is in progress: sync again in a minute."
				return 3
			fi
			busy="$(live_runs_of "$dir")"
			if [ -n "$busy" ]; then
				err "Runs still going use $dir, and its code must not change under them: sync it once they end, or, with the user's consent, put the change in a worktree of its own. Their logs:"
				printf '%s\n' "$busy" | head -n 20 >&2
				return 3
			fi
			if [ -f "$pending" ]; then
				# An earlier checkout failed half way: finish it, but only over what it could have changed.
				there="$(git_safe "$dir" status --porcelain -z --untracked-files=all --no-renames 2>/dev/null | while IFS= read -r -d '' f; do
					if git_safe "$dir" diff --quiet --no-ext-diff "${prev:-$(git_safe "$dir" hash-object -t tree /dev/null)}" "$(sed -n 1p "$pending")" -- ":(literal)${f:3}"; then
						printf '%s\n' "$f"
					fi
				done | head -n 40)"
				if [ -n "$there" ]; then
					err "The mirror $dir holds changes that no sync made, such as files a run wrote there or an edit on the remote host: show the user this list, who decides what to keep; never touch the mirror's files unless they ask."
					printf '%s\n' "$there" >&2
					mirror_fix "$dir"
					return 3
				fi
				old="$prev"
			elif [ -n "$old" ]; then
				checkout_dirty "$dir"
				case $? in
					1) ;;
					2) return 3 ;;
					*)
						err "The mirror $dir holds changes that no sync made, such as files a run wrote there or an edit on the remote host: show the user this list, who decides what to keep; never touch the mirror's files unless they ask."
						git_safe "$dir" status --short --untracked-files=all 2>/dev/null | head -n 40 >&2
						mirror_fix "$dir"
						return 3
						;;
				esac
			else
				there="$(git_safe "$dir" ls-tree -r -z --name-only "$commit" | (cd "$dir" && while IFS= read -r -d '' f; do
					if [ -e "$f" ] || [ -L "$f" ]; then printf '%s\n' "$f"; fi
				done) | head -n 20)"
				if [ -n "$there" ]; then
					err "The folder $dir already holds files of the commit, which a first sync would overwrite: show the user this list, who decides; never touch them unless they ask."
					printf '%s\n' "$there" >&2
					return 3
				fi
			fi
			printf '%s\n%s\n' "$commit" "$old" >"$pending" || return 4
			git_safe "$dir" -c core.autocrlf=false -c advice.detachedHead=false checkout -q -f --detach "$commit" ||
				{ err "Could not check out $commit in $dir: fix the cause, such as a full disk, then sync again"; return 4; }
			# The checkout is done: what differs from here on is no half-done checkout's doing.
			[ "$(git_safe "$dir" rev-parse HEAD 2>/dev/null)" != "$commit" ] || rm -f "$pending"
		fi
	fi

	[ "$(git_safe "$dir" rev-parse HEAD 2>/dev/null)" = "$commit" ] || { err "The mirror $dir is not at $commit after the checkout: sync again once; if that fails, stop and report"; return 4; }
	checkout_dirty "$dir"
	if [ $? != 1 ]; then
		err "The mirror $dir differs from its commit after the checkout, such as by files the new commit no longer ignores: show the user this list, who decides; never touch the mirror's files unless they ask"
		git_safe "$dir" status --short --untracked-files=all 2>/dev/null | head -n 40 >&2
		mirror_fix "$dir"
		return 4
	fi
	gd="$(git_dir_of "$dir")" && [ -d "$gd" ] || return 4
	printf '%s\n' "$branch" >"$gd/vrl-sync.branch"
	printf 'synced %s code=%s@%s diff=clean\n' "$dir" "$dir" "$(git_safe "$dir" rev-parse --short=12 HEAD)"
	if [ "$dir" = . ]; then
		plans="$(git_safe . ls-tree -r --name-only "$commit" -- docs/plans)"
		printf '%s\n' "$plans" | while IFS= read -r f; do
			case "$f" in docs/plans/*.md) [ ! -f "$f" ] || printf 'sha256 %s %s\n' "$f" "$(sha256_of "$f")" ;; esac
		done
	fi
	return 0
}

main "$@"
