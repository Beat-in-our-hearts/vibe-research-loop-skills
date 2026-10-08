#!/usr/bin/env bash
# Print this machine's resource rows for a progress report, in the table of docs/AGENTS/tracking_training.md:
# one row per GPU, then memory, then storage, and below it which GPUs are free. It reads the real limits:
# each GPU from nvidia-smi, memory from the container's cgroup when that sets a limit, and storage from df
# on the folder that holds the outputs.
#
# Usage: resources.sh [--path DIR] [--free-mib N]
#
#   --path DIR    A folder on the filesystem that holds the outputs (default: runs if it exists, else .).
#   --free-mib N  A GPU counts as free when no process runs on it and it uses less than N MiB of memory
#                 (default: 1024). Whether a waiting run, a scheduler job, or another user claims it is for
#                 the caller to check.
#
# A process that nvidia-smi lists but ps cannot see belongs to another container or user. df gives the
# filesystem's size, not a quota: where docs/AGENTS/machine.md names a quota command, its numbers win.
#
# In remote mode, run it on the remote host: vrl_ssh.sh script <alias> --workspace <dir> -- resources.sh
#
# Everything runs inside main(), so that bash reads the whole script before running it when the
# script comes in on stdin.

main() {
	set -uo pipefail
	local path="" free_mib=1024
	while [ $# -gt 0 ]; do
		case "$1" in
			--path) path="${2:-}"; shift ;;
			--path=*) path="${1#--path=}" ;;
			--free-mib) free_mib="${2:-}"; shift ;;
			--free-mib=*) free_mib="${1#--free-mib=}" ;;
			-h | --help) usage; return 0 ;;
			*) err "Unknown argument: $1"; return 2 ;;
		esac
		shift
	done
	case "$free_mib" in "" | *[!0-9]*) err "--free-mib takes a whole number of MiB"; return 2 ;; esac
	if [ -z "$path" ]; then
		if [ -d runs ]; then path=runs; else path=.; fi
	fi
	[ -d "$path" ] || { err "No such folder: $path"; return 2; }
	# For tests: a folder that stands in for / when reading /proc and /sys.
	ROOT="${VRL_RESOURCES_ROOT:-}"

	printf '| Item | Status | Details |\n|---|---|---|\n'
	gpu_rows "$free_mib"
	memory_row
	storage_row "$path"
	printf '\n%s\n' "$FREE_LINE"
}

usage() { sed -n '2,/^# Everything runs inside/p' "$0" 2>/dev/null | sed '$d' | sed 's/^# \{0,1\}//'; }
err() { printf 'resources: %s\n' "$*" >&2; }

# Bytes as GiB or TiB, with one or two decimals.
human() { awk -v b="$1" 'BEGIN { if (b >= 1024^4) printf "%.2f TiB", b / 1024^4; else printf "%.1f GiB", b / 1024^3 }'; }
percent() { awk -v u="$1" -v t="$2" 'BEGIN { if (t > 0) printf "%d %%", u * 100 / t + 0.5; else printf "—" }'; }

gpu_rows() {
	local free_mib="$1" gpus apps index uuid util used total draw limit details procs free=""
	FREE_LINE="Free GPUs (no process, memory below $free_mib MiB): none"
	if ! command -v nvidia-smi >/dev/null 2>&1; then
		printf '| GPU | — | nvidia-smi not found |\n'
		FREE_LINE="Free GPUs: none, since nvidia-smi is not found"
		return
	fi
	gpus="$(nvidia-smi --query-gpu=index,uuid,utilization.gpu,memory.used,memory.total,power.draw,power.limit \
		--format=csv,noheader,nounits 2>/dev/null)" || {
		printf '| GPU | — | nvidia-smi failed |\n'
		FREE_LINE="Free GPUs: unknown, since nvidia-smi failed"
		return
	}
	apps="$(nvidia-smi --query-compute-apps=gpu_uuid,pid,used_memory --format=csv,noheader,nounits 2>/dev/null)"
	while IFS=, read -r index uuid util used total draw limit; do
		index="$(trim "$index")" uuid="$(trim "$uuid")" util="$(trim "$util")"
		used="$(trim "$used")" total="$(trim "$total")" draw="$(trim "$draw")" limit="$(trim "$limit")"
		[ -n "$index" ] || continue
		details="Memory $(awk -v u="$used" -v t="$total" 'BEGIN { printf "%.1f / %.1f GiB", u / 1024, t / 1024 }')"
		case "$draw$limit" in
			*N/A* | *"["*) ;;
			*) details="$details, power $(awk -v d="$draw" -v l="$limit" 'BEGIN { printf "%d / %d W", d + 0.5, l + 0.5 }')" ;;
		esac
		procs="$(gpu_processes "$uuid" "$apps")"
		if [ -n "$procs" ]; then
			details="$details; $procs"
		else
			details="$details; idle"
			if [ "$(printf '%s' "$used" | tr -cd '0-9')" -lt "$free_mib" ] 2>/dev/null; then
				free="${free:+$free, }$index"
			fi
		fi
		printf '| GPU %s | %s %% | %s |\n' "$index" "$util" "$details"
	done <<EOF
$gpus
EOF
	[ -z "$free" ] || FREE_LINE="Free GPUs (no process, memory below $free_mib MiB): $free"
}

trim() { printf '%s' "$1" | sed 's/^ *//; s/ *$//'; }

# The processes on one GPU, each as `PID <pid> <user>: <command>`, or as not visible here.
gpu_processes() {
	local uuid="$1" apps="$2" app_uuid pid mem user args out=""
	while IFS=, read -r app_uuid pid mem; do
		[ "$(trim "$app_uuid")" = "$uuid" ] || continue
		pid="$(trim "$pid")" mem="$(trim "$mem")"
		user="$(ps -o user= -p "$pid" 2>/dev/null | sed 's/ *$//')"
		if [ -n "$user" ]; then
			args="$(ps -o args= -p "$pid" 2>/dev/null | cut -c 1-60)"
			out="${out:+$out; }PID $pid $user, $mem MiB: $args"
		else
			out="${out:+$out; }PID $pid, $mem MiB: not visible here, so another container or user"
		fi
	done <<EOF
$apps
EOF
	printf '%s' "$out"
}

memory_row() {
	local limit used source
	case "$(uname -s)" in
		Darwin)
			limit="$(sysctl -n hw.memsize 2>/dev/null)"
			used="$(vm_stat 2>/dev/null | awk '
				/page size of/ { size = $8 }
				/Pages active/ { a = $3 } /Pages wired down/ { w = $4 } /occupied by compressor/ { c = $5 }
				END { printf "%d", (a + w + c) * size }')"
			source="macOS: active, wired, and compressed"
			;;
		*) linux_memory || return ;;
	esac
	if [ -n "${MEM_LIMIT:-}" ]; then limit="$MEM_LIMIT" used="$MEM_USED" source="$MEM_SOURCE"; fi
	if [ -z "$limit" ] || [ -z "$used" ]; then
		printf '| Memory | — | could not read the memory limit |\n'
		return
	fi
	printf '| Memory | %s | %s / %s (%s) |\n' "$(percent "$used" "$limit")" "$(human "$used")" "$(human "$limit")" "$source"
}

# Sets MEM_LIMIT, MEM_USED, and MEM_SOURCE from the nearest cgroup that limits memory, or else the host.
linux_memory() {
	local cg dir max cur inactive
	MEM_LIMIT="" MEM_USED="" MEM_SOURCE=""
	if [ -f "$ROOT/sys/fs/cgroup/cgroup.controllers" ]; then
		cg="$(sed -n 's/^0:://p' "$ROOT/proc/self/cgroup" 2>/dev/null)"
		dir="$ROOT/sys/fs/cgroup${cg%/}"
		while :; do
			max="$(cat "$dir/memory.max" 2>/dev/null)"
			if [ -n "$max" ] && [ "$max" != max ]; then
				cur="$(cat "$dir/memory.current" 2>/dev/null)"
				inactive="$(awk '$1 == "inactive_file" { print $2 }' "$dir/memory.stat" 2>/dev/null)"
				MEM_LIMIT="$max" MEM_USED=$((cur - ${inactive:-0})) MEM_SOURCE="cgroup v2 limit, without inactive file cache"
				return 0
			fi
			[ "$dir" != "$ROOT/sys/fs/cgroup" ] && [ -n "$dir" ] || break
			dir="${dir%/*}"
		done
	elif [ -f "$ROOT/sys/fs/cgroup/memory/memory.limit_in_bytes" ]; then
		dir="$ROOT/sys/fs/cgroup/memory"
		max="$(cat "$dir/memory.limit_in_bytes")"
		# cgroup v1 writes no limit as a number near 2^63.
		if [ "${#max}" -lt 19 ]; then
			cur="$(cat "$dir/memory.usage_in_bytes")"
			inactive="$(awk '$1 == "total_inactive_file" { print $2 }' "$dir/memory.stat" 2>/dev/null)"
			MEM_LIMIT="$max" MEM_USED=$((cur - ${inactive:-0})) MEM_SOURCE="cgroup v1 limit, without inactive file cache"
			return 0
		fi
	fi
	read -r MEM_LIMIT MEM_USED < <(awk '
		$1 == "MemTotal:" { t = $2 * 1024 } $1 == "MemAvailable:" { a = $2 * 1024 }
		END { printf "%d %d\n", t, t - a }' "$ROOT/proc/meminfo" 2>/dev/null)
	MEM_SOURCE="host total: no cgroup limit"
}

storage_row() {
	local path="$1" line used avail mounted
	line="$(df -Pk "$path" 2>/dev/null | awk 'NR == 2 { print $3, $4, $6 }')"
	if [ -z "$line" ]; then
		printf '| Storage | — | df could not read %s |\n' "$path"
		return
	fi
	read -r used avail mounted <<EOF
$line
EOF
	used=$((used * 1024)) avail=$((avail * 1024))
	printf '| Storage | %s | %s / %s (df on %s, mounted at %s) |\n' \
		"$(percent "$used" $((used + avail)))" "$(human "$used")" "$(human $((used + avail)))" "$path" "$mounted"
}

main "$@"
