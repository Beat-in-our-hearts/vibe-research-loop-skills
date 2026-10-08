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
  launch_run.sh --plan docs/plans/<date>-<name>.md --run <run> --plan-sha256 <hash> <options>
  launch_run.sh --purpose '<what it does>' <options> -- '<command>'

The first form launches a run of an approved plan: its command is the fenced block of the plan file
whose info string holds `run=<run>`, such as ```bash run=baseline, and the plan file must still have
the SHA-256 recorded when the plan was approved. Use it whenever a plan exists; it is the only form
to allow without a prompt, since it cannot run a command the plan does not hold. The second form
runs any command, such as a smoke run or a data job, and asks for the user's review like any command.

Options, required:
  --log FILE          The log, such as logs/<date>-<name>/<run>.log; its folder is created if missing.
  --tmux SESSION      Run in a new window of this tmux session, named after the log; or
  --nohup             run in the background as a session of its own, outside any terminal.
  --gpus IDS          The GPUs to use, such as 0,1, exported as CUDA_VISIBLE_DEVICES in the PCI order
                      that nvidia-smi uses; or
  --no-gpu            for a command that uses no GPU: CUDA_VISIBLE_DEVICES is set empty.
  --machine NAME      The machine's short name in docs/AGENTS/machine.md.
  --code DIR|none     The checkout the command runs from, such as main_repo or worktrees/<branch>.

Options, optional:
  --purpose TEXT      The header's purpose line; in the plan form it defaults to the plan and the run.
  --outputs DIR       The run's output folder, created if missing; required when the checkout is
                      dirty, since its diff is saved there as git_diff.patch, readable by you only.
  --env NAME          The Python environment (default: the active virtual or conda environment).
  --restart           Go on when the log's last run has no footer and its process is gone, as after
                      a crash: a footer that closes it at the log's last write goes in first.
  --resume            Go on when the log's last run finished with exit code 0, to continue it in
                      the same outputs. Without it, a finished run is refused: give a rerun a new run
                      name instead, since a finished run is never overwritten.
  --new-session       With --tmux: create the session if it does not exist.
  --wait S            Wait up to S seconds (default 3) before reporting; for a smoke run, wait for
                      it to end and report its exit code.

It refuses to run on a machine with a Slurm scheduler, a command that sets CUDA_VISIBLE_DEVICES
itself, a command that seems to hold a secret, and a second copy of a run that is still alive.
The header holds a run-id that only the footer repeats, so a program's output cannot fake either.

Prints the log, run-id, session, code, and status. Exit codes: 0 running, or ended with exit code 0
within the wait; 1 ended with another exit code, or did not start; 2 bad arguments; 3 refused.
EOF
}

main() {
	set -uo pipefail
	umask 077

	local log="" purpose="" session="" nohup=0 gpus="" no_gpu=0 machine="" code="" outputs="" envname=""
	local restart=0 resume=0 new_session=0 wait_s=3 plan="" plan_given=0 run="" plan_sha=""
	while [ $# -gt 0 ]; do
		case "$1" in
			--log) log="${2:-}"; shift ;;
			--purpose) purpose="${2:-}"; shift ;;
			--tmux) session="${2:-}"; shift ;;
			--nohup) nohup=1 ;;
			--gpus) gpus="${2:-}"; shift ;;
			--no-gpu) no_gpu=1 ;;
			--machine) machine="${2:-}"; shift ;;
			--code) code="${2:-}"; shift ;;
			--outputs) outputs="${2:-}"; shift ;;
			--env) envname="${2:-}"; shift ;;
			--restart) restart=1 ;;
			--resume) resume=1 ;;
			--new-session) new_session=1 ;;
			--wait) wait_s="${2:-}"; shift ;;
			--plan) plan="${2:-}"; plan_given=$((plan_given + 1)); shift ;;
			--run) run="${2:-}"; shift ;;
			--plan-sha256) plan_sha="${2:-}"; shift ;;
			-h | --help) usage; return 0 ;;
			--) shift; break ;;
			*) err "Unknown argument: $1"; return 2 ;;
		esac
		shift
	done

	# Arguments.
	local cmd=""
	if [ "$plan_given" -gt 0 ]; then
		[ "$plan_given" = 1 ] && [ -n "$plan" ] || { err "Give --plan once, with the plan file"; return 2; }
		[ $# -eq 0 ] || { err "The plan form takes no command after --: the command comes from the plan"; return 2; }
		[ -n "$run" ] || { err "--plan needs --run"; return 2; }
		[ -n "$plan_sha" ] || { err "--plan needs --plan-sha256, the hash recorded when the plan was approved"; return 2; }
	else
		[ -z "$run$plan_sha" ] || { err "--run and --plan-sha256 go with --plan"; return 2; }
		[ $# -eq 1 ] || { err "Give the command as one quoted string after --"; return 2; }
		cmd="$1"
		[ -n "$cmd" ] || { err "The command is empty"; return 2; }
		[ -n "$purpose" ] || { err "--purpose is required"; return 2; }
	fi
	[ -n "$log" ] || { err "--log is required"; return 2; }
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
	[ -n "$machine" ] || { err "--machine is required: the short name in docs/AGENTS/machine.md"; return 2; }
	[ -n "$code" ] || { err "--code is required: the checkout, or none"; return 2; }
	case "$session" in
		*[!A-Za-z0-9_-]*) err "A tmux session name holds only letters, digits, - and _"; return 2 ;;
	esac
	case "$wait_s" in "" | *[!0-9]*) err "--wait takes whole seconds"; return 2 ;; esac
	local v
	for v in "$purpose" "$machine" "$code" "$outputs" "$envname" "$log" "$run"; do
		case "$v" in *"$NL"* | *"$CR"*) err "Options other than the command hold one line each"; return 2 ;; esac
	done

	# Refusals.
	if [ -n "${SLURM_JOB_ID:-}" ] || command -v sbatch >/dev/null 2>&1; then
		err "This machine has a Slurm scheduler: launch through it as docs/AGENTS/machine.md says, by hand."
		return 3
	fi
	[ -f .env ] || { err "Run this from the workspace root: there is no .env here"; return 2; }
	local ws
	ws="$(pwd -P)"
	if [ -n "$plan" ]; then
		cmd="$(plan_command "$ws" "$plan" "$run" "$plan_sha")" || return 3
		[ -n "$purpose" ] || purpose="$(basename "$plan" .md) / $run: run $run of the approved plan"
	fi
	if printf '%s' "$cmd" | grep -Eq '(^|[^A-Za-z0-9_])CUDA_VISIBLE_DEVICES='; then
		err "The command sets CUDA_VISIBLE_DEVICES itself: pass the GPUs with --gpus instead."
		return 3
	fi
	if printf '%s' "$cmd" | grep -Eiq "$SECRET_RE"; then
		err "The command seems to hold a secret, which the log header would record: keep it out of the command."
		return 3
	fi
	if [ -n "$session" ] && ! command -v tmux >/dev/null 2>&1; then
		err "tmux is not installed"
		return 2
	fi
	if [ "$code" != none ]; then
		git -C "$code" rev-parse --git-dir >/dev/null 2>&1 || { err "Not a git checkout: $code"; return 2; }
	fi

	set -a
	set +u
	# shellcheck disable=SC1091
	. ./.env
	set -u
	set +a

	local log_path="$log"
	case "$log_path" in /*) ;; *) log_path="$ws/$log_path" ;; esac
	mkdir -p "$(dirname "$log_path")" || { err "Could not create the log's folder"; return 1; }
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

	# Never start a second copy; never overwrite a finished run.
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
	if [ -f "$log_path" ]; then
		local state last_id last_pid
		state="$(log_state "$log_path")"
		last_id="$(printf '%s' "$state" | cut -f2)"
		last_pid="$(printf '%s' "$state" | cut -f3)"
		case "$state" in
			open*)
				if run_alive "$log_path" "$last_pid" "$last_id"; then
					err "Run $last_id still writes this log: it is still going. Check it before starting it again."
					return 3
				fi
				[ "$restart" = 1 ] || {
					err "The log's last run has no footer and its process is gone: it crashed or was killed. Pass --restart to start it again."
					return 3
				}
				close_dead_run "$log_path" "$last_id"
				;;
			finished0*)
				if [ "$resume" = 0 ]; then
					err "The log's last run finished with exit code 0: give a rerun a new run name, or pass --resume to continue it."
					return 3
				fi
				;;
		esac
	fi

	# The header's code, outputs, and resources lines.
	local code_line="none" patch=""
	if [ "$code" != none ]; then
		local branch commit state_word="clean"
		commit="$(git_safe "$code" rev-parse --short=12 HEAD 2>/dev/null)" || { err "Not a git checkout: $code"; return 2; }
		branch="$(git_safe "$code" rev-parse --abbrev-ref HEAD 2>/dev/null)"
		if [ -n "$(git_safe "$code" status --porcelain 2>/dev/null)" ]; then
			state_word="dirty"
			[ -n "$outputs" ] || { err "The checkout $code is dirty: give --outputs so its diff is saved with the run."; return 3; }
			patch="$(save_diff "$code" "$outputs")" || return 1
		fi
		code_line="$code ($branch) @ $commit ($state_word)"
	fi
	[ -z "$outputs" ] || mkdir -p "$outputs" || { err "Could not create $outputs"; return 1; }
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
	[ -z "$plan" ] || header="$header$NL# plan:      $plan (sha256 $plan_sha), run $run"
	header="$header$NL$(printf '# purpose:   %s\n# code:      %s\n# outputs:   %s\n# resources: %s\n# run-id:    %s' \
		"$purpose" "$code_line" "${outputs:-none}" "$resources" "$run_id")"

	local where=""
	[ -z "$session" ] || where="$session:$window, "
	local venv_lines=""
	if [ -n "${VIRTUAL_ENV:-}" ]; then
		venv_lines="export VIRTUAL_ENV=$(sq "$VIRTUAL_ENV") PATH=$(sq "$VIRTUAL_ENV/bin"):\"\$PATH\""
	fi

	# The shell that runs the command writes the header, with its own PID, and the footer. It runs from a
	# file, so that no shell of the user's quotes it. The command runs in a session of its own, with no
	# terminal, so that a signal to this shell, such as closing the tmux window or `kill <PID>`, reaches
	# every process of the run: TERM first, KILL 10 seconds later. The footer waits until all have ended.
	local runner start_child
	runner="$(mktemp "${TMPDIR:-/tmp}/vrl-run-$run_id.XXXXXX")" || { err "Could not write the run's script"; return 1; }
	if command -v perl >/dev/null 2>&1; then
		start_child="perl -MPOSIX -e 'POSIX::setsid(); \$SIG{INT} = \$SIG{HUP} = \"DEFAULT\"; exec @ARGV or exit 127' bash -c $(sq "$cmd") $(sq "vrl-run-$run_id") >>$(sq "$log_path") 2>&1 </dev/null &"
	else
		start_child="set -m; bash -c $(sq "$cmd") $(sq "vrl-run-$run_id") >>$(sq "$log_path") 2>&1 </dev/null & set +m"
	fi
	cat >"$runner" <<RUNNER
rm -f -- $(sq "$runner")
umask 077
cd $(sq "$ws") || exit 97
exec 2>>$(sq "$log_path")
set -a; . ./.env; set +a
export CUDA_VISIBLE_DEVICES=$(sq "$gpus") CUDA_DEVICE_ORDER=PCI_BUS_ID PYTHONUNBUFFERED=1
$venv_lines
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
			{ rm -f "$runner"; err "tmux could not open the window"; return 1; }
	elif command -v perl >/dev/null 2>&1; then
		# A session of its own, with SIGINT and SIGHUP back to their defaults, which `&` would ignore.
		perl -MPOSIX -e 'POSIX::setsid(); $SIG{INT} = $SIG{HUP} = "DEFAULT"; exec @ARGV or exit 127' \
			bash "$runner" >/dev/null 2>&1 </dev/null &
	elif command -v setsid >/dev/null 2>&1; then
		setsid bash "$runner" >/dev/null 2>&1 </dev/null &
	else
		nohup bash "$runner" >/dev/null 2>&1 </dev/null &
	fi

	# Wait for the header, then up to --wait seconds for the end.
	local waited=0
	while [ "$waited" -lt 5 ] && ! grep -Fq "# run-id:    $run_id" "$log_path" 2>/dev/null; do
		sleep 1
		waited=$((waited + 1))
	done
	if ! grep -Fq "# run-id:    $run_id" "$log_path" 2>/dev/null; then
		err "The command did not start: no header with run-id $run_id in $log"
		return 1
	fi
	rmdir "$LOCK" 2>/dev/null
	waited=0
	while [ "$waited" -lt "$wait_s" ] && ! grep -Fq -- "# ---------- end $run_id ----------" "$log_path"; do
		sleep 1
		waited=$((waited + 1))
	done
	printf 'log       %s\n' "$log"
	printf 'run-id    %s\n' "$run_id"
	printf 'session   %s\n' "$(grep -A1 -F "# run-id:    $run_id" "$log_path" | sed -n 's/^# session: *//p')"
	printf 'code      %s\n' "$code_line"
	[ -z "$patch" ] || printf 'diff      %s\n' "$patch"
	if ! grep -Fq -- "# ---------- end $run_id ----------" "$log_path"; then
		printf 'status    running after %s s\n' "$wait_s"
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

# Quote a string for any shell of the sh family.
sq() {
	local s=${1//\'/\'\\\'\'}
	printf "'%s'" "$s"
}

# git without the repository's own hooks, fsmonitor, or external diff tools.
git_safe() {
	local dir="$1"
	shift
	git -C "$dir" -c core.fsmonitor= -c core.hooksPath=/dev/null -c core.quotepath=off -c color.ui=false "$@"
}


sha256_of() {
	if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | cut -d' ' -f1
	elif command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | cut -d' ' -f1
	else openssl dgst -sha256 "$1" | sed 's/.*= //'; fi
}

# The command of one run in an approved plan file, after checking where the file is and its hash.
plan_command() {
	local ws="$1" plan="$2" run="$3" want="$4" real plans got blocks rc
	case "$run" in "" | *[!A-Za-z0-9_.-]*) err "A run name holds only letters, digits, ., - and _"; return 1 ;; esac
	[ -f "$plan" ] && [ ! -L "$plan" ] || { err "No such plan file, or it is a symlink: $plan"; return 1; }
	real="$(cd "$(dirname "$plan")" && pwd -P)/$(basename "$plan")"
	plans="$(cd "$ws/docs/plans" 2>/dev/null && pwd -P)" || { err "This workspace has no docs/plans/"; return 1; }
	case "$real" in
		"$plans/"*) ;;
		*) err "The plan file must be under docs/plans/ of this workspace: $plan"; return 1 ;;
	esac
	got="$(sha256_of "$real")"
	if [ "$(printf '%s' "$got" | tr 'A-F' 'a-f')" != "$(printf '%s' "$want" | tr 'A-F' 'a-f')" ]; then
		err "The plan file changed since it was approved: its SHA-256 is $got, not $want. A changed plan needs a new approval."
		return 1
	fi
	# A block opens with a fence of three or more backticks or tildes whose info string holds the word
	# run=<run>, and closes only at a line that is a fence of the same character, at least as long.
	blocks="$(tr -d '\r' <"$real" | awk -v run="$run" '
		function fence(line,   m) {
			if (match(line, /^ ? ? ?(````*|~~~~*)/)) { m = substr(line, RSTART, RLENGTH); sub(/^ */, "", m); return m }
			return ""
		}
		{
			f = fence($0)
			if (inside) {
				if (f != "" && substr(f, 1, 1) == ch && length(f) >= len && $0 ~ /^ ? ? ?[`~][`~]*[ \t]*$/) { inside = 0; next }
				print
				next
			}
			if (f != "") {
				info = $0; sub(/^ ? ? ?[`~][`~]*/, "", info)
				n = split(info, words, /[ \t]+/)
				hit = 0
				for (i = 1; i <= n; i++) if (words[i] == "run=" run) hit = 1
				if (hit) { inside = 1; found++; ch = substr(f, 1, 1); len = length(f); next }
			}
		}
		END { if (inside) exit 5; if (found != 1) exit (found == 0 ? 3 : 4) }
	')"
	rc=$?
	case $rc in
		0) ;;
		3) err "The plan has no block for run $run: a fenced block whose info string holds run=$run"; return 1 ;;
		5) err "The plan's block for run $run never closes"; return 1 ;;
		*) err "The plan has more than one block for run $run"; return 1 ;;
	esac
	[ -n "$blocks" ] || { err "The plan's block for run $run is empty"; return 1; }
	printf '%s' "$blocks"
}

# The state of a log's last run: "open<TAB>id<TAB>pid", "finished<code><TAB>id", or "none".
log_state() {
	awk -v OFS='\t' '
		open && oid != "" { if ($0 == "# ---------- end " oid " ----------") { open = 0; closing = 1 }; next }
		/^# run-id:/ { id = $3 } /^# session:/ { s = $0 }
		/^# ---------- stdout/ { open = 1; oid = id; os = s; id = ""; fin = ""; next }
		/^# ---------- end/ && open { open = 0; closing = 1; next }
		closing && /^# finished:/ { fin = $0; closing = 0 }
		END {
			if (open) { pid = ""; if (match(os, /PID [0-9]+/)) pid = substr(os, RSTART + 4, RLENGTH - 4); print "open", oid, pid }
			else if (fin != "") { code = fin; sub(/.*exit code /, "", code); print "finished" code, oid }
			else print "none"
		}' "$1"
}

# The PIDs of this user's processes that have a file open for writing; every process of a run holds
# its log so, the command's children included, even after its shell is gone. Returns 2 when no way to
# tell exists here, neither /proc nor lsof.
writers_of() {
	local f="$1" real
	real="$(cd "$(dirname "$f")" 2>/dev/null && pwd -P)/$(basename "$f")"
	if [ "$(uname -s)" = Linux ] && [ -d /proc/self/fd ]; then
		ls -l /proc/[0-9]*/fd 2>/dev/null | awk -v f="$real" '$1 ~ /^l.w/ { i = index($0, " -> "); if (i && substr($0, i + 4) == f) n++ } END { exit !n }'
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

# The models of the given GPUs, such as `NVIDIA A100-SXM4-80GB`, or `unknown` without nvidia-smi.
gpu_model() {
	local models
	models="$(limited 15 nvidia-smi --query-gpu=index,name --format=csv,noheader 2>/dev/null |
		awk -F', *' -v ids=",$1," 'index(ids, "," $1 ",") { print $2 }' | sort -u |
		awk '{ printf "%s%s", (NR > 1 ? " + " : ""), $0 }')"
	printf '%s' "${models:-unknown}"
}

# Save what makes the checkout dirty, untracked files and binaries included, so that `git apply`
# on the commit rebuilds it; under a new name if an earlier diff differs.
save_diff() {
	local code="$1" outputs="$2" file tmp f
	mkdir -p "$outputs" || { err "Could not create $outputs"; return 1; }
	tmp="$(mktemp "$outputs/.git_diff.XXXXXX")" || { err "Could not write in $outputs"; return 1; }
	{
		git_safe "$code" diff --no-ext-diff --no-textconv --binary --src-prefix=a/ --dst-prefix=b/ HEAD
		git_safe "$code" ls-files -o --exclude-standard -z | while IFS= read -r -d '' f; do
			(cd "$code" && git -c core.fsmonitor= -c core.hooksPath=/dev/null -c color.ui=false \
				diff --no-index --no-ext-diff --no-textconv --binary --src-prefix=a/ --dst-prefix=b/ -- /dev/null "$f")
		done
	} >"$tmp"
	if grep -Eiq "$SECRET_RE" "$tmp"; then
		err "Warning: the saved diff seems to hold a secret; it is readable by you only. Check $outputs."
	fi
	file="$outputs/git_diff.patch"
	if [ -f "$file" ] && ! cmp -s "$tmp" "$file"; then
		file="$outputs/git_diff-$(date +%Y%m%d-%H%M%S).patch"
	fi
	mv "$tmp" "$file" && chmod 600 "$file"
	printf '%s' "$file"
}

main "$@"
