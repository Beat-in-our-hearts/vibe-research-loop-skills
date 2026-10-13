#!/usr/bin/env bash
# Print this machine's resource rows for a progress report, in the table of
# docs/AGENTS/tracking_training.md, and say which GPUs are free to launch a run on.
#
# Run it from the workspace root, or in remote mode on the remote host:
#   vrl_ssh.sh script <alias> --workspace <dir> -- resources.sh [options]
#
# Everything runs inside main(), so that bash reads the whole script before running it when the
# script comes in on stdin.

usage() {
	cat <<'EOF'
Usage: resources.sh [--allowed IDS] [--logs DIR] [--path DIR] [--free-mib N] [--max-util P]
                    [--samples N] [--limit S] [--rows]

Prints a table row per GPU, then memory and storage, then the lines `free:` (GPUs a run may start
on now, "none", or "unknown (<reason>)"), `not free:` (each other allowed GPU, with the reason),
`claimed:` (GPUs a running log claims), and `note:` (what limits these lines). A GPU is free only if
nvidia-smi answers in time and lists its processes without error, MIG is off on it, and no running
log claims it: a log under --logs with no footer yet, still written by one of your processes, whose
header names the GPU. Free is "unknown" when this cannot be told, under Slurm, or when nvidia-smi
lists a GPU it cannot read. Other users' processes show by user name only.

  --allowed IDS   The GPU ids experiments may use, from docs/AGENTS/machine.md, such as 0,1 or 0-3.
  --logs DIR      The logs folder (default: logs, if it exists).
  --path DIR      A folder on the outputs' filesystem (default: runs, if it exists, else .); its
                  row shows df, not the quota.
  --free-mib N    Memory use in MiB below which a GPU with no process may be free (default 256).
  --max-util P    Utilization in percent up to which it may be free (default 5).
  --samples N     Samples, 2 seconds apart, in each of which a free GPU must be free (default 2).
  --limit S       The time limit of the whole script, in seconds (default 45), at most 15 per
                  nvidia-smi call.
  --rows          Print the rows only, without the table header.
Exit codes: 0 done; 2 bad arguments.
EOF
}

main() {
	set -uo pipefail
	local allowed="" logs="" path="" free_mib=256 max_util=5 samples=2 limit=45 rows_only=0
	while [ $# -gt 0 ]; do
		case "$1" in
			--allowed) allowed="${2:-}"; shift ;;
			--logs) logs="${2:-}"; shift ;;
			--path) path="${2:-}"; shift ;;
			--free-mib) free_mib="${2:-}"; shift ;;
			--max-util) max_util="${2:-}"; shift ;;
			--samples) samples="${2:-}"; shift ;;
			--limit) limit="${2:-}"; shift ;;
			--rows) rows_only=1 ;;
			-h | --help) usage; return 0 ;;
			*) err "Unknown argument: $1; see resources.sh --help"; return 2 ;;
		esac
		shift
	done
	# The local machine of a remote-mode workspace runs no code; the remote host sets VRL_REMOTE.
	if [ -z "${VRL_REMOTE:-}" ] && in_remote_workspace; then
		err "This is the local machine of a remote-mode workspace: run resources.sh on the remote host, through vrl_ssh.sh script."
		return 2
	fi
	is_uint "$free_mib" && is_uint "$max_util" && is_uint "$samples" && is_uint "$limit" &&
		[ "$samples" -ge 1 ] && [ "$samples" -le 5 ] ||
		{ err "--free-mib, --max-util, --samples (1 to 5), and --limit take whole numbers"; return 2; }
	case "$allowed" in
		*[!0-9,-]* | ,* | *, | *,,*) err "--allowed takes GPU ids such as 0,1 or 0-3"; return 2 ;;
	esac
	if [ -z "$path" ]; then
		if [ -d runs ]; then path=runs; else path=.; fi
	fi
	[ -d "$path" ] || { err "No such folder for --path: $path; give a folder that exists"; return 2; }
	NOTE_LINES=""
	if [ -z "$logs" ]; then
		if [ -d logs ]; then logs=logs; else note "no logs folder here, so no running log can claim a GPU"; fi
	elif [ ! -d "$logs" ]; then
		note "no logs folder at $logs, so no running log can claim a GPU"
		logs=""
	fi
	# For tests: a folder that stands in for / when reading /proc and /sys, and a shorter limit.
	ROOT="${VRL_RESOURCES_ROOT:-}"
	SMI_LIMIT="${VRL_SMI_LIMIT:-15}"
	DEADLINE=$(($(date +%s) + 10#$limit))

	[ "$rows_only" = 1 ] || printf '| Item | Status | Details |\n|---|---|---|\n'
	gpu_rows "$allowed" "$logs" "$free_mib" "$max_util" "$samples"
	memory_row
	storage_row "$path"
	printf '\n%s\n' "$FREE_LINE"
	[ -z "$NOT_FREE_LINE" ] || printf '%s\n' "$NOT_FREE_LINE"
	[ -z "$CLAIMED_LINE" ] || printf '%s\n' "$CLAIMED_LINE"
	[ -z "$NOTE_LINES" ] || printf '%s' "$NOTE_LINES"
	return 0
}

err() { printf 'resources: %s\n' "$*" >&2; }
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

is_uint() { case "$1" in "" | *[!0-9]*) return 1 ;; esac; }
# A number such as 12 or 3.5: digits, with at most one dot between digits.
is_num() { printf '%s' "$1" | grep -Eq '^[0-9]+(\.[0-9]+)?$'; }
# Whether number $1 is above number $2; false for anything that is not a number.
num_gt() { is_num "$1" && is_num "$2" && awk -v a="$1" -v b="$2" 'BEGIN { exit !(a > b) }'; }
num_lt() { is_num "$1" && is_num "$2" && awk -v a="$1" -v b="$2" 'BEGIN { exit !(a < b) }'; }
cell() { printf '%s' "$1" | tr '\n' ' ' | sed 's/|/\\|/g'; }
trim() { printf '%s' "$1" | sed 's/^ *//; s/ *$//'; }
note() { NOTE_LINES="${NOTE_LINES}note: $*
"; }

# The seconds a call may take: at most $1, and never past the deadline; 1 at the least.
budget() {
	local left=$((DEADLINE - $(date +%s)))
	[ "$left" -ge 1 ] || left=1
	[ "$left" -lt "$1" ] && echo "$left" || echo "$1"
}

# limited <seconds> <command...>: run it, ending its process group at the limit; 124 when cut.
limited() {
	local limit="$1"
	shift
	if command -v timeout >/dev/null 2>&1; then
		timeout -k 2 "$limit" "$@"
	elif command -v gtimeout >/dev/null 2>&1; then
		gtimeout -k 2 "$limit" "$@"
	elif command -v perl >/dev/null 2>&1; then
		perl -e '$SIG{ALRM} = sub { kill "TERM", -$pid; sleep 2; kill "KILL", -$pid; exit 124 };
			$pid = fork; if (!$pid) { setpgrp(0, 0); exec @ARGV[1..$#ARGV] or exit 127 }
			alarm $ARGV[0]; waitpid $pid, 0; exit($? & 127 ? 128 + ($? & 127) : $? >> 8)' "$limit" "$@"
	else
		"$@"
	fi
}

# Bytes as GiB or TiB.
human() { awk -v b="$1" 'BEGIN { if (b >= 1024^4) printf "%.2f TiB", b / 1024^4; else printf "%.1f GiB", b / 1024^3 }'; }
percent() { awk -v u="$1" -v t="$2" 'BEGIN { if (t > 0) printf "%.0f %%", u * 100 / t; else printf "unknown" }'; }

# The ids in a list such as 0,1 or 0-3, at most 64 of them and each below 1024; nothing if it is odd.
expand_ids() {
	printf '%s' "$1" | tr -d ' ' | awk -F, '{
		for (i = 1; i <= NF; i++) {
			if ($i ~ /^[0-9]+$/) { lo = hi = $i + 0 }
			else if ($i ~ /^[0-9]+-[0-9]+$/) { split($i, r, "-"); lo = r[1] + 0; hi = r[2] + 0 }
			else exit 1
			if (hi < lo || hi >= 1024 || hi - lo > 64) exit 1
			for (g = lo; g <= hi; g++) { out = out " " g; if (++n > 64) exit 1 }
		}
		print out
	}'
}

in_list() { case " $2 " in *" $1 "*) return 0 ;; esac; return 1; }

# Slurm, PBS, LSF, or SGE: a job's own variables, or the commands that submit jobs.
slurm_here() {
	[ -n "${SLURM_JOB_ID:-}${PBS_JOBID:-}${LSB_JOBID:-}" ] || { [ -n "${JOB_ID:-}" ] && [ -n "${SGE_ROOT:-}" ]; } ||
		command -v sbatch >/dev/null 2>&1 || command -v squeue >/dev/null 2>&1 || command -v qsub >/dev/null 2>&1 ||
		command -v bsub >/dev/null 2>&1 || [ -e /etc/slurm/slurm.conf ] || [ -e /etc/slurm-llnl/slurm.conf ]
}

# OPEN_FILES: on Linux, the files this user's processes hold open for writing, from one /proc scan.
read_open_files() {
	OPEN_FILES=""
	if [ "$(uname -s)" = Linux ] && [ -d /proc/self/fd ]; then
		OPEN_FILES="$(ls -l /proc/[0-9]*/fd 2>/dev/null | awk '$1 ~ /^l.w/ { i = index($0, " -> "); if (i) print substr($0, i + 4) }')"
		OPEN_MODE=proc
	elif command -v lsof >/dev/null 2>&1; then
		OPEN_MODE=lsof
	else
		OPEN_MODE=none
	fi
}

# Whether one of this user's processes writes the file: 0 yes, 1 no, 2 cannot tell.
written() {
	local real="$1"
	case "$OPEN_MODE" in
		proc) printf '%s\n' "$OPEN_FILES" | grep -Fxq -- "$real" ;;
		lsof) limited "$(budget 10)" lsof -w -Fa -- "$real" 2>/dev/null | awk '/^a/ && /[wu]/ { n++ } END { exit !n }' ;;
		*) return 2 ;;
	esac
}

# CLAIMS: "<id>=<run>" words for the GPUs of every running log: a log with no footer at its end,
# which one of this user's processes still writes. Only its last header's resources line counts.
read_claims() {
	local logs="$1" f real ids id name rc
	CLAIMS="" CLAIMS_UNKNOWN=""
	[ -n "$logs" ] || return 0
	read_open_files
	while IFS= read -r f; do
		[ -n "$f" ] || continue
		tail -n 1 "$f" 2>/dev/null | grep -q '^# finished:' && continue
		head -c 4096 "$f" 2>/dev/null | grep -q '^# command:' || continue
		real="$(cd "$(dirname "$f")" 2>/dev/null && pwd -P)/$(basename "$f")"
		written "$real"
		rc=$?
		if [ "$rc" = 2 ]; then
			CLAIMS_UNKNOWN="no lsof or /proc here, so running logs cannot be told"
			continue
		fi
		[ "$rc" = 0 ] || continue
		ids="$(awk '/^# resources:/ { r = $0 } /^# ---------- stdout/ { last = r } END { print last }' "$f" |
			sed -n 's/^# resources: [^,]*, [Gg][Pp][Uu][Ss]\{0,1\} \([0-9][0-9, -]*\).*/\1/p')"
		name="$(basename "$(dirname "$f")")/$(basename "$f" .log)"
		for id in $(expand_ids "$ids"); do CLAIMS="$CLAIMS $id=$name"; done
	done <<EOF
$(limited "$(budget 15)" find -L "$logs" -type f 2>/dev/null)
EOF
}

claim_of() {
	local w
	for w in $CLAIMS; do [ "${w%%=*}" = "$1" ] && { printf '%s' "${w#*=}"; return 0; }; done
	return 1
}

gpu_rows() {
	local allowed="$1" logs="$2" free_mib="$3" max_util="$4" samples="$5"
	local gpus apps mig n i index uuid util used total draw limit rest details procs who reason
	local free="" not_free="" claimed="" busy="" lost=0 apps_failed=0 allowed_ids="" seen=""
	FREE_LINE="free: none" NOT_FREE_LINE="" CLAIMED_LINE=""
	if ! command -v nvidia-smi >/dev/null 2>&1; then
		printf '| GPU | unknown | nvidia-smi not found |\n'
		FREE_LINE="free: unknown (nvidia-smi not found)"
		return
	fi
	if [ -n "$allowed" ]; then
		allowed_ids="$(expand_ids "$allowed")" || { FREE_LINE="free: unknown (--allowed is not a list of GPU ids)"; return; }
	fi
	read_claims "$logs"

	# Each sample may mark a GPU busy, with its reason; the last sample fills the rows.
	i=1
	while [ "$i" -le "$samples" ]; do
		[ "$i" = 1 ] || sleep 2
		gpus="$(limited "$(budget "$SMI_LIMIT")" nvidia-smi --query-gpu=index,uuid,utilization.gpu,memory.used,memory.total,power.draw,power.limit,name \
			--format=csv,noheader,nounits 2>/dev/null)"
		n=$?
		if [ "$n" -ne 0 ] || [ -z "$gpus" ]; then
			if [ "$n" = 124 ]; then reason="nvidia-smi timed out"; else reason="nvidia-smi failed"; fi
			printf '| GPU | unknown | %s |\n' "$reason"
			FREE_LINE="free: unknown ($reason)"
			return
		fi
		if ! apps="$(limited "$(budget "$SMI_LIMIT")" nvidia-smi --query-compute-apps=gpu_uuid,pid,used_memory --format=csv,noheader,nounits 2>/dev/null)"; then
			apps_failed=1
		fi
		while IFS=, read -r index uuid util used total draw limit rest; do
			index="$(trim "$index")" uuid="$(trim "$uuid")" util="$(trim "$util")" used="$(trim "$used")"
			is_uint "$index" || continue
			[ -z "$(gpu_processes "$uuid" "$apps")" ] || { mark "$index" "a process"; continue; }
			if ! is_num "$util" || ! is_num "$used"; then mark "$index" "utilization or memory unknown"; continue; fi
			num_gt "$util" "$max_util" && { mark "$index" "utilization $util %"; continue; }
			num_lt "$used" "$free_mib" || mark "$index" "memory $used MiB in use"
		done <<EOF
$gpus
EOF
		i=$((i + 1))
	done
	mig="$(limited "$(budget "$SMI_LIMIT")" nvidia-smi --query-gpu=index,mig.mode.current --format=csv,noheader 2>/dev/null)"

	while IFS=, read -r index uuid util used total draw limit rest; do
		index="$(trim "$index")" uuid="$(trim "$uuid")" util="$(trim "$util")" used="$(trim "$used")"
		total="$(trim "$total")" draw="$(trim "$draw")" limit="$(trim "$limit")" rest="$(trim "$rest")"
		if ! is_uint "$index"; then
			if [ -n "$(trim "$index$uuid")" ]; then
				lost=1
				printf '| GPU ? | unknown | %s |\n' "$(cell "$(trim "$index $uuid $util")")"
			fi
			continue
		fi
		seen="$seen $index"
		details=""
		[ -z "$rest" ] || details="$rest, "
		if is_num "$used" && is_num "$total"; then
			details="${details}memory $(awk -v u="$used" -v t="$total" 'BEGIN { printf "%.1f / %.1f GiB", u / 1024, t / 1024 }')"
		else
			details="${details}memory unknown"
		fi
		if is_num "$draw" && is_num "$limit"; then
			details="$details, power $(awk -v d="$draw" -v l="$limit" 'BEGIN { printf "%.0f / %.0f W", d, l }')"
		fi
		who="$(claim_of "$index")" && claimed="${claimed:+$claimed; }$index by $who"
		procs="$(gpu_processes "$uuid" "$apps")"
		if [ -n "$who" ]; then
			details="$details; run $who"
		elif [ -n "$procs" ]; then
			details="$details; $procs"
		elif [ "$apps_failed" = 1 ]; then
			details="$details; processes unknown"
		else
			details="$details; no process"
		fi
		is_num "$util" && util="$util %" || util="unknown"
		printf '| GPU %s | %s | %s |\n' "$index" "$util" "$(cell "$details")"

		if [ -n "$allowed_ids" ] && ! in_list "$index" "$allowed_ids"; then
			continue
		fi
		reason=""
		if printf '%s\n' "$mig" | grep -Eiq "^ *$index *, *enabled"; then
			reason="MIG is on"
		elif [ -n "$who" ]; then
			reason="claimed by $who"
		elif in_list "$index" "$busy"; then
			eval "reason=\"\${REASON_$index}\""
		elif [ "$apps_failed" = 1 ]; then
			reason="processes unknown"
		fi
		if [ -z "$reason" ]; then
			free="${free:+$free,}$index"
		else
			not_free="${not_free:+$not_free; }$index ($reason)"
		fi
	done <<EOF
$gpus
EOF
	for i in $allowed_ids; do
		in_list "$i" "$seen" || note "GPU $i is allowed, but nvidia-smi does not list it"
	done
	if [ "$apps_failed" = 1 ]; then
		FREE_LINE="free: unknown (nvidia-smi could not list the processes)"
	elif [ "$lost" = 1 ]; then
		FREE_LINE="free: unknown (nvidia-smi lists a GPU it cannot read, so the GPU numbers may have moved)"
	elif [ -n "$CLAIMS_UNKNOWN" ]; then
		FREE_LINE="free: unknown ($CLAIMS_UNKNOWN)"
	elif [ -n "${SLURM_JOB_ID:-}${PBS_JOBID:-}${LSB_JOBID:-}" ]; then
		FREE_LINE="free: unknown (inside a scheduler's job, which has its own GPUs)"
	elif slurm_here; then
		FREE_LINE="free: unknown (a job scheduler assigns the GPUs)"
	else
		FREE_LINE="free: ${free:-none}"
	fi
	slurm_here && note "this machine has a job scheduler: launch through it as docs/AGENTS/machine.md says"
	[ -z "$not_free" ] || NOT_FREE_LINE="not free: $not_free"
	[ -z "$claimed" ] || CLAIMED_LINE="claimed: $claimed"
}

# mark <index> <reason>: mark a GPU busy; the index is a plain number, checked by the caller.
mark() {
	in_list "$1" "$busy" || busy="$busy $1"
	eval "REASON_$1=\$2"
}

# The processes on one GPU: this user's with their command, other users' by name only.
gpu_processes() {
	local uuid="$1" apps="$2" app_uuid pid mem rest user uid args out="" me
	me="$(id -u)"
	while IFS=, read -r app_uuid pid mem rest; do
		[ -n "$(trim "$app_uuid")" ] && [ "$(trim "$app_uuid")" = "$uuid" ] || continue
		pid="$(trim "$pid")" mem="$(trim "$mem")"
		is_uint "$pid" || continue
		is_num "$mem" || mem="unknown"
		uid="$(ps -o uid= -p "$pid" 2>/dev/null | tr -d ' ')"
		user="$(ps -o user= -p "$pid" 2>/dev/null | tr -d ' ')"
		if [ -z "$uid" ]; then
			out="${out:+$out; }PID $pid, $mem MiB: not visible here, so another container or user"
		elif [ "$uid" = "$me" ]; then
			args="$(ps -o args= -p "$pid" 2>/dev/null | awk '{ print substr($0, 1, 48) }')"
			out="${out:+$out; }PID $pid, $mem MiB: $args"
		else
			out="${out:+$out; }PID $pid, $mem MiB: another user ($user)"
		fi
	done <<EOF
$apps
EOF
	printf '%s' "$out"
}

memory_row() {
	local limit="" used="" source=""
	MEM_LIMIT="" MEM_USED="" MEM_SOURCE=""
	case "$(uname -s)" in
		Darwin)
			limit="$(sysctl -n hw.memsize 2>/dev/null)"
			used="$(vm_stat 2>/dev/null | awk '
				/page size of/ { size = $8 }
				/Pages active/ { a = $3 } /Pages wired down/ { w = $4 } /occupied by compressor/ { c = $5 }
				END { printf "%.0f", (a + w + c) * size }')"
			source="macOS: active, wired, and compressed"
			;;
		*)
			linux_memory
			limit="$MEM_LIMIT" used="$MEM_USED" source="$MEM_SOURCE"
			;;
	esac
	if ! is_uint "$limit" || ! is_uint "$used" || [ "$limit" = 0 ]; then
		printf '| Memory | unknown | could not read the memory limit |\n'
		return
	fi
	printf '| Memory | %s | %s / %s (%s) |\n' "$(percent "$used" "$limit")" "$(human "$used")" "$(human "$limit")" "$source"
}

# Sets MEM_LIMIT, MEM_USED, and MEM_SOURCE from the tightest cgroup limit above this process, or the host.
linux_memory() {
	local cg dir max cur inactive best="" best_dir=""
	if [ -f "$ROOT/sys/fs/cgroup/cgroup.controllers" ]; then
		cg="$(sed -n 's/^0:://p' "$ROOT/proc/self/cgroup" 2>/dev/null)"
		dir="$ROOT/sys/fs/cgroup${cg%/}"
		while :; do
			max="$(cat "$dir/memory.max" 2>/dev/null)"
			if is_uint "$max" && { [ -z "$best" ] || [ "$max" -lt "$best" ]; }; then best="$max" best_dir="$dir"; fi
			[ "$dir" != "$ROOT/sys/fs/cgroup" ] && [ -n "$dir" ] || break
			dir="${dir%/*}"
		done
		if [ -n "$best" ]; then
			cur="$(cat "$best_dir/memory.current" 2>/dev/null)"
			inactive="$(awk '$1 == "inactive_file" { print $2 }' "$best_dir/memory.stat" 2>/dev/null)"
			if is_uint "$cur"; then
				MEM_LIMIT="$best" MEM_USED=$((cur - ${inactive:-0})) MEM_SOURCE="cgroup v2 limit, without inactive file cache"
				[ "$MEM_USED" -ge 0 ] || MEM_USED=0
				return 0
			fi
		fi
	elif [ -d "$ROOT/sys/fs/cgroup/memory" ]; then
		cg="$(awk -F: '$2 ~ /(^|,)memory(,|$)/ { print $3; exit }' "$ROOT/proc/self/cgroup" 2>/dev/null)"
		dir="$ROOT/sys/fs/cgroup/memory${cg%/}"
		[ -d "$dir" ] || dir="$ROOT/sys/fs/cgroup/memory"
		while :; do
			max="$(cat "$dir/memory.limit_in_bytes" 2>/dev/null)"
			# cgroup v1 writes no limit as a number near 2^63.
			if is_uint "$max" && [ "${#max}" -lt 19 ] && { [ -z "$best" ] || [ "$max" -lt "$best" ]; }; then
				best="$max" best_dir="$dir"
			fi
			[ "$dir" != "$ROOT/sys/fs/cgroup/memory" ] && [ -n "$dir" ] || break
			dir="${dir%/*}"
		done
		if [ -n "$best" ]; then
			cur="$(cat "$best_dir/memory.usage_in_bytes" 2>/dev/null)"
			inactive="$(awk '$1 == "total_inactive_file" { print $2 }' "$best_dir/memory.stat" 2>/dev/null)"
			if is_uint "$cur"; then
				MEM_LIMIT="$best" MEM_USED=$((cur - ${inactive:-0})) MEM_SOURCE="cgroup v1 limit, without inactive file cache"
				[ "$MEM_USED" -ge 0 ] || MEM_USED=0
				return 0
			fi
		fi
	fi
	read -r MEM_LIMIT MEM_USED < <(awk '
		$1 == "MemTotal:" { t = $2 * 1024 } $1 == "MemAvailable:" { a = $2 * 1024 }
		END { if (t > 0) printf "%.0f %.0f\n", t, t - a }' "$ROOT/proc/meminfo" 2>/dev/null)
	MEM_SOURCE="host total: no cgroup limit"
}

storage_row() {
	local path="$1" line used avail mounted label="Storage (filesystem, not the quota)"
	# df -P prints one line per filesystem; find the capacity field rather than counting columns,
	# since a device or mount point may hold spaces.
	line="$(limited "$(budget 10)" df -Pk -- "$path" 2>/dev/null | awk 'NR > 1 {
		for (i = 2; i <= NF; i++) if ($i ~ /^[0-9]+%$/) {
			m = $(i + 1); for (j = i + 2; j <= NF; j++) m = m " " $j
			print $(i - 2), $(i - 1), m; exit
		}
	}')"
	read -r used avail mounted <<EOF
$line
EOF
	if ! is_uint "${used:-}" || ! is_uint "${avail:-}"; then
		printf '| %s | unknown | df could not read %s |\n' "$label" "$(cell "$path")"
		return
	fi
	used=$((used * 1024)) avail=$((avail * 1024))
	printf '| %s | %s | %s / %s (df on %s, mounted at %s) |\n' "$label" \
		"$(percent "$used" $((used + avail)))" "$(human "$used")" "$(human $((used + avail)))" "$(cell "$path")" "$(cell "$mounted")"
}

main "$@"
