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
Usage: resources.sh [--allowed IDS] [--logs DIR] [--path DIR] [--quota-cmd CMD] [--free-mib N]
                    [--max-util P] [--samples N] [--rows]

Prints one table row per GPU, then memory, then storage, and below the table:
  free: <ids>        GPUs a run may start on now, or "none", or "unknown (<reason>)"
  not free: <list>   each other allowed GPU with the reason, such as a run, a process, or MIG
  claimed: <list>    GPUs that a running log claims, with the run

A GPU is free only when all of these hold, in every sample:
  - nvidia-smi answers within 60 s and lists its processes without an error;
  - no process runs on it, its memory use is below --free-mib, and its utilization is at most
    --max-util;
  - MIG is off on it;
  - no log under --logs claims it: a run whose header names the GPU, whose run has no footer, and
    whose process is still alive;
  - it is among --allowed, when given.
Whether a scheduler job holds it is not checked: on a machine with Slurm, free is "unknown".

  --allowed IDS    The GPU ids experiments may use, from docs/AGENTS/machine.md, such as 0,1,2,3.
  --logs DIR       The logs folder (default: logs, if it exists).
  --path DIR       A folder on the filesystem that holds the outputs (default: runs, if it exists,
                   else .).
  --quota-cmd CMD  The command docs/AGENTS/machine.md gives for the storage quota; its output is
                   printed below the table, since df gives the filesystem, not the quota.
  --free-mib N     Memory below which a GPU without processes may count as free (default 1024).
  --max-util P     Utilization in percent up to which it may count as free (default 5).
  --samples N      Samples of each GPU, 2 seconds apart (default 2).
  --rows           Print the rows only, without the table header, to put them under task rows.

Processes of other users are shown by user name only, never by command line.
Exit codes: 0 done; 2 bad arguments.
EOF
}

main() {
	set -uo pipefail
	local allowed="" logs="" path="" quota_cmd="" free_mib=1024 max_util=5 samples=2 rows_only=0
	while [ $# -gt 0 ]; do
		case "$1" in
			--allowed) allowed="${2:-}"; shift ;;
			--allowed=*) allowed="${1#*=}" ;;
			--logs) logs="${2:-}"; shift ;;
			--logs=*) logs="${1#*=}" ;;
			--path) path="${2:-}"; shift ;;
			--path=*) path="${1#*=}" ;;
			--quota-cmd) quota_cmd="${2:-}"; shift ;;
			--quota-cmd=*) quota_cmd="${1#*=}" ;;
			--free-mib) free_mib="${2:-}"; shift ;;
			--free-mib=*) free_mib="${1#*=}" ;;
			--max-util) max_util="${2:-}"; shift ;;
			--max-util=*) max_util="${1#*=}" ;;
			--samples) samples="${2:-}"; shift ;;
			--samples=*) samples="${1#*=}" ;;
			--rows) rows_only=1 ;;
			-h | --help) usage; return 0 ;;
			*) err "Unknown argument: $1"; return 2 ;;
		esac
		shift
	done
	is_uint "$free_mib" && is_uint "$max_util" && is_uint "$samples" && [ "$samples" -ge 1 ] ||
		{ err "--free-mib, --max-util, and --samples take whole numbers, --samples at least 1"; return 2; }
	case "$allowed" in
		*[!0-9,]* | ,* | *, | *,,*) err "--allowed takes GPU ids such as 0,1"; return 2 ;;
	esac
	if [ -z "$path" ]; then
		if [ -d runs ]; then path=runs; else path=.; fi
	fi
	[ -d "$path" ] || { err "No such folder: $path"; return 2; }
	if [ -z "$logs" ] && [ -d logs ]; then logs=logs; fi
	# For tests: a folder that stands in for / when reading /proc and /sys, and a shorter time limit.
	ROOT="${VRL_RESOURCES_ROOT:-}"
	SMI_LIMIT="${VRL_SMI_LIMIT:-60}"

	[ "$rows_only" = 1 ] || printf '| Item | Status | Details |\n|---|---|---|\n'
	gpu_rows "$allowed" "$logs" "$free_mib" "$max_util" "$samples"
	memory_row
	storage_row "$path" "$quota_cmd"
	printf '\n%s\n' "$FREE_LINE"
	[ -z "$NOT_FREE_LINE" ] || printf '%s\n' "$NOT_FREE_LINE"
	[ -z "$CLAIMED_LINE" ] || printf '%s\n' "$CLAIMED_LINE"
	[ -z "$NOTE_LINES" ] || printf '%s' "$NOTE_LINES"
	if [ -n "$quota_cmd" ]; then
		printf '\nQuota, from `%s`:\n```\n' "$quota_cmd"
		limited 60 bash -c "$quota_cmd" 2>&1 | head -n 20
		printf '```\n'
	fi
	return 0
}

err() { printf 'resources: %s\n' "$*" >&2; }
is_uint() { case "$1" in "" | *[!0-9]*) return 1 ;; esac; }
is_num() { case "$1" in "" | *[!0-9.]* | *.*.*) return 1 ;; esac; }
cell() { printf '%s' "$1" | tr '\n' ' ' | sed 's/|/\\|/g'; }
trim() { printf '%s' "$1" | sed 's/^ *//; s/ *$//'; }
note() { NOTE_LINES="${NOTE_LINES}note: $*
"; }

# limited <seconds> <command...>: run it, ending it at the limit; 124 when the limit cut it.
limited() {
	local limit="$1"
	shift
	if command -v timeout >/dev/null 2>&1; then
		timeout -k 5 "$limit" "$@"
	elif command -v gtimeout >/dev/null 2>&1; then
		gtimeout -k 5 "$limit" "$@"
	elif command -v perl >/dev/null 2>&1; then
		perl -e '$SIG{ALRM} = sub { kill "TERM", $pid; sleep 2; kill "KILL", $pid; exit 124 };
			$pid = fork; if (!$pid) { exec @ARGV[1..$#ARGV] or exit 127 }
			alarm $ARGV[0]; waitpid $pid, 0; exit($? & 127 ? 128 + ($? & 127) : $? >> 8)' "$limit" "$@"
	else
		"$@"
	fi
}

# Bytes as GiB or TiB.
human() { awk -v b="$1" 'BEGIN { if (b >= 1024^4) printf "%.2f TiB", b / 1024^4; else printf "%.1f GiB", b / 1024^3 }'; }
percent() { awk -v u="$1" -v t="$2" 'BEGIN { if (t > 0) printf "%.0f %%", u * 100 / t; else printf "unknown" }'; }

expand_ids() {
	local part out=""
	for part in $(printf '%s' "$1" | tr ',' ' '); do
		case "$part" in
			*-*) out="$out $(seq "${part%-*}" "${part#*-}" 2>/dev/null | tr '\n' ' ')" ;;
			*) out="$out $part" ;;
		esac
	done
	printf '%s' "$out"
}

in_list() { case " $2 " in *" $1 "*) return 0 ;; esac; return 1; }

# CLAIMS: "<id>=<run>" words for the GPUs that open logs with a live process claim.
read_claims() {
	local logs="$1" res pid file name ids id
	CLAIMS=""
	[ -n "$logs" ] && [ -d "$logs" ] || return 0
	while IFS="$(printf '\t')" read -r res pid file; do
		[ -n "$file" ] || continue
		kill -0 "$pid" 2>/dev/null || continue
		name="$(basename "$(dirname "$file")")/$(basename "$file" .log)"
		ids="$(printf '%s' "$res" | sed -n 's/.*[Gg][Pp][Uu][Ss]\{0,1\}[ :=]*\([0-9][0-9,-]*\).*/\1/p')"
		for id in $(expand_ids "$ids"); do CLAIMS="$CLAIMS $id=$name"; done
	done <<EOF
$(find "$logs" -type f -size -200000k 2>/dev/null | while read -r f; do
		awk -v OFS="$(printf '\t')" '
			/^# run-id:/ { id = $3 } /^# session:/ { s = $0 } /^# resources:/ { r = $0 }
			/^# ---------- stdout/ { open = 1; oid = id; os = s; or_ = r; id = "" }
			/^# ---------- end/ && open && (oid == "" || index($0, oid)) { open = 0 }
			END { if (open && match(os, /PID [0-9]+/)) print or_, substr(os, RSTART + 4, RLENGTH - 4), FILENAME }
		' "$f" 2>/dev/null
	done)
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
	local free="" not_free="" claimed="" busy_ids=""
	FREE_LINE="free: none" NOT_FREE_LINE="" CLAIMED_LINE="" NOTE_LINES=""
	if [ -n "${SLURM_JOB_ID:-}" ] || command -v sbatch >/dev/null 2>&1; then
		note "this machine has a Slurm scheduler: launch through it as docs/AGENTS/machine.md says"
	fi
	if ! command -v nvidia-smi >/dev/null 2>&1; then
		printf '| GPU | unknown | nvidia-smi not found |\n'
		FREE_LINE="free: unknown (nvidia-smi not found)"
		return
	fi
	read_claims "$logs"
	local allowed_ids=""
	[ -z "$allowed" ] || allowed_ids="$(expand_ids "$allowed")"

	# Each sample may veto a GPU; the last sample fills the rows.
	i=1
	while [ "$i" -le "$samples" ]; do
		[ "$i" = 1 ] || sleep 2
		gpus="$(limited "$SMI_LIMIT" nvidia-smi --query-gpu=index,uuid,utilization.gpu,memory.used,memory.total,power.draw,power.limit \
			--format=csv,noheader,nounits 2>/dev/null)"
		n=$?
		if [ "$n" -ne 0 ] || [ -z "$gpus" ]; then
			if [ "$n" = 124 ]; then reason="nvidia-smi timed out"; else reason="nvidia-smi failed"; fi
			printf '| GPU | unknown | %s |\n' "$reason"
			FREE_LINE="free: unknown ($reason)"
			return
		fi
		if ! apps="$(limited "$SMI_LIMIT" nvidia-smi --query-compute-apps=gpu_uuid,pid,used_memory --format=csv,noheader,nounits 2>/dev/null)"; then
			FREE_LINE="free: unknown (nvidia-smi could not list the processes)"
			APPS_FAILED=1
		fi
		while IFS=, read -r index uuid util used total draw limit rest; do
			index="$(trim "$index")" uuid="$(trim "$uuid")" util="$(trim "$util")" used="$(trim "$used")"
			is_uint "$index" || continue
			procs="$(gpu_processes "$uuid" "$apps")"
			if [ -n "$procs" ]; then
				in_list "$index" "$busy_ids" || busy_ids="$busy_ids $index"
				eval "REASON_$index=\"a process\""
			elif ! is_num "$util" || ! is_num "$used"; then
				in_list "$index" "$busy_ids" || busy_ids="$busy_ids $index"
				eval "REASON_$index=\"utilization or memory unknown\""
			elif [ "${util%.*}" -gt "$max_util" ]; then
				in_list "$index" "$busy_ids" || busy_ids="$busy_ids $index"
				eval "REASON_$index=\"utilization $util %\""
			elif [ "${used%.*}" -ge "$free_mib" ]; then
				in_list "$index" "$busy_ids" || busy_ids="$busy_ids $index"
				eval "REASON_$index=\"memory $used MiB in use\""
			fi
		done <<EOF
$gpus
EOF
		i=$((i + 1))
	done
	mig="$(limited "$SMI_LIMIT" nvidia-smi --query-gpu=index,mig.mode.current --format=csv,noheader 2>/dev/null)"

	while IFS=, read -r index uuid util used total draw limit rest; do
		index="$(trim "$index")" uuid="$(trim "$uuid")" util="$(trim "$util")" used="$(trim "$used")"
		total="$(trim "$total")" draw="$(trim "$draw")" limit="$(trim "$limit")"
		if ! is_uint "$index"; then
			[ -z "$(trim "$index$uuid")" ] || printf '| GPU ? | unknown | %s |\n' "$(cell "$(trim "$index $uuid $util")")"
			continue
		fi
		if is_num "$used" && is_num "$total"; then
			details="Memory $(awk -v u="$used" -v t="$total" 'BEGIN { printf "%.1f / %.1f GiB", u / 1024, t / 1024 }')"
		else
			details="Memory unknown"
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
		else
			details="$details; idle"
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
		elif in_list "$index" "$busy_ids"; then
			eval "reason=\"\${REASON_$index}\""
		elif [ "${APPS_FAILED:-0}" = 1 ]; then
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
	if [ "${APPS_FAILED:-0}" = 1 ]; then
		:
	elif [ -n "${SLURM_JOB_ID:-}" ] || command -v sbatch >/dev/null 2>&1; then
		[ -n "${SLURM_JOB_ID:-}" ] && FREE_LINE="free: ${free:-none}" || FREE_LINE="free: unknown (a Slurm scheduler assigns the GPUs)"
	else
		FREE_LINE="free: ${free:-none}"
	fi
	[ -z "$not_free" ] || NOT_FREE_LINE="not free: $not_free"
	[ -z "$claimed" ] || CLAIMED_LINE="claimed: $claimed"
}

# The processes on one GPU: this user's with their command, other users' by name only.
gpu_processes() {
	local uuid="$1" apps="$2" app_uuid pid mem rest user uid args out=""
	local me
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
	local path="$1" quota_cmd="$2" line used avail mounted label
	# df -P prints one line per filesystem; find the capacity field rather than counting columns,
	# since a device or mount point may hold spaces.
	line="$(df -Pk -- "$path" 2>/dev/null | awk 'NR > 1 {
		for (i = 2; i <= NF; i++) if ($i ~ /^[0-9]+%$/) {
			m = $(i + 1); for (j = i + 2; j <= NF; j++) m = m " " $j
			print $(i - 2), $(i - 1), m; exit
		}
	}')"
	if [ -n "$quota_cmd" ]; then label="Storage (filesystem; the quota is below)"; else label="Storage (filesystem, not the quota)"; fi
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
