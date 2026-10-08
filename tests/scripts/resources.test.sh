#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2016,SC2034 # Sourced helpers, literal test strings, and variables used across files.
# Tests for resources.sh, with the fake nvidia-smi and fake /proc and cgroup trees.
. "$(dirname "$0")/lib.sh"
R="$SCRIPTS/resources.sh"
export PATH="$FAKES:$PATH" FAKE_GPU_DIR="$TMP_ROOT/gpu"
mkdir -p "$FAKE_GPU_DIR" "$TMP_ROOT/ws/logs/d" "$TMP_ROOT/ws/runs" "$TMP_ROOT/bin"
cd "$TMP_ROOT/ws" || exit 1
GPUS='0, GPU-a, 96, 39117, 47104, 344.1, 350.0
1, GPU-b, 0, 12, 47104, 31.0, 350.0
2, GPU-c, 0, 3, 81559, [N/A], [N/A]
3, GPU-d, 100, 200, 81559, 300.0, 400.0
4, GPU-e, 0, 2, 81559, 50, 400
5, GPU-f, 0, 412, 81559, 50, 400'
printf '%s\n' "$GPUS" >"$FAKE_GPU_DIR/gpus"
printf '0, Disabled\n1, Disabled\n2, Enabled\n3, Disabled\n4, Disabled\n5, Disabled\n' >"$FAKE_GPU_DIR/mig"
sleep 300 & MINE=$!
disown "$MINE"
printf 'GPU-a, %s, 39000\n' "$MINE" >"$FAKE_GPU_DIR/apps"
header() {
	printf '# command:   python train.py --tag a|b\n# purpose:   d / %s\n# code:      none\n# outputs:   none\n' "$1"
	printf '# resources: box, %s, Python env gpu2\n# run-id:    abc123def456\n# session:   vrl:d/x, PID 1\n' "$2"
	printf '# started:   2026-10-08 12:00:00 +04:00\n# ---------- stdout + stderr ----------\nloading data\n'
}
header 'warm' 'GPU 4 (A100)' >logs/d/warm.log
# A process of this test holds the log open for writing, as a running run does.
sleep 301 >>logs/d/warm.log 2>&1 &
CLAIMER=$!
disown "$CLAIMER"
header 'done' 'GPUs 0, 1 (A100)' >logs/d/done.log
printf '# ---------- end abc123def456 ----------\n# finished:  2026-10-08 13:00:00 +04:00 (1:00:00), exit code 0\n' >>logs/d/done.log
header 'dead' 'GPU 1 (A100)' >logs/d/dead.log
CLEANUP_HOOK='kill $MINE $CLAIMER 2>/dev/null'

test_free_rule() {
	run bash "$R" --samples 1 --allowed 0-5
	expect_out "free: 1" && expect_out "0 (a process)" && expect_out "2 (MIG is on)" && expect_out "3 (utilization 100 %)" &&
		expect_out "4 (claimed by d/warm)" && expect_out "5 (memory 412 MiB in use)" && expect_out "claimed: 4 by d/warm"
	expect_no_out "by d/done" && expect_no_out "by d/dead" && expect_no_out "2 by"
}

test_processes_unknown_means_free_unknown() {
	FAKE_APPS_FAIL=1 run bash "$R" --samples 1 --rows
	expect_out "free: unknown" && expect_out "processes unknown" && expect_no_out "no process"
}

test_lost_gpu_means_free_unknown() {
	printf '%s\nUnable to determine the device handle for GPU 0000:3B:00.0\n' "$GPUS" >"$FAKE_GPU_DIR/gpus"
	run bash "$R" --samples 1
	printf '%s\n' "$GPUS" >"$FAKE_GPU_DIR/gpus"
	expect_out "| GPU ? | unknown |" && expect_out "free: unknown (nvidia-smi lists a GPU it cannot read"
}

test_odd_numbers_count_as_busy() {
	printf '%s\n6, GPU-g, ., 1, 81559, 50, 400\n7, GPU-h, 5.9, 1, 81559, 50, 400\n' "$GPUS" >"$FAKE_GPU_DIR/gpus"
	run bash "$R" --samples 1 --allowed 6,7
	printf '%s\n' "$GPUS" >"$FAKE_GPU_DIR/gpus"
	expect_out "free: none" && expect_out "6 (utilization or memory unknown)" && expect_out "7 (utilization 5.9 %)"
}

test_allowed_ids_and_ranges() {
	run bash "$R" --samples 1 --allowed 2,3; expect_out "free: none" && expect_no_out "1 ("
	run bash "$R" --samples 1 --allowed 0-1,9; expect_out "free: 1" && expect_out "GPU 9 is allowed, but nvidia-smi does not list it"
	run bash "$R" --samples 1 --allowed 0-3000000; expect_out "free: unknown (--allowed"
}

test_hung_nvidia_smi() {
	start=$(date +%s)
	FAKE_SMI_HANG=1 VRL_SMI_LIMIT=2 run bash "$R" --samples 1
	expect_out "free: unknown (nvidia-smi timed out)" && expect [ $(($(date +%s) - start)) -lt 15 ]
	pkill -f '^sleep 1000$' 2>/dev/null
	return 0
}

test_slurm_makes_free_unknown() {
	printf '#!/bin/sh\n' >"$TMP_ROOT/bin/sbatch"; chmod +x "$TMP_ROOT/bin/sbatch"
	PATH="$TMP_ROOT/bin:$PATH" run bash "$R" --samples 1
	rm -f "$TMP_ROOT/bin/sbatch"
	expect_out "free: unknown (a Slurm scheduler" && expect_out "note: this machine has a Slurm scheduler"
	SLURM_JOB_ID=42 run bash "$R" --samples 1
	expect_out "free: unknown (inside a Slurm job"
}

test_logs_through_a_symlink_and_missing_logs() {
	mkdir -p "$TMP_ROOT/elsewhere"
	mv logs "$TMP_ROOT/elsewhere/logs" && ln -s "$TMP_ROOT/elsewhere/logs" logs
	run bash "$R" --samples 1 --allowed 4
	rm logs && mv "$TMP_ROOT/elsewhere/logs" logs
	expect_out "4 (claimed by d/warm)"
	run bash "$R" --samples 1 --logs nowhere
	expect_out "note: no logs folder at nowhere"
}

test_other_users_command_lines_hidden() {
	printf 'GPU-b, 1, 100\n' >"$FAKE_GPU_DIR/apps"
	run bash "$R" --samples 1
	printf 'GPU-a, %s, 39000\n' "$MINE" >"$FAKE_GPU_DIR/apps"
	expect_out "PID 1, 100 MiB: another user" && expect_no_out "launchd" && expect_no_out "/sbin/init"
}

test_storage_with_spaces() {
	mkdir -p "dir with space"
	run bash "$R" --samples 1 --path "dir with space"
	expect_out "| Storage (filesystem, not the quota) |" && expect_no_out "mounted at 100%"
}

test_cgroup_v2_tightest_limit() {
	f="$TMP_ROOT/root"; mkdir -p "$f/proc/self" "$f/sys/fs/cgroup/kube/pod"
	touch "$f/sys/fs/cgroup/cgroup.controllers"; echo '0::/kube/pod' >"$f/proc/self/cgroup"
	echo 34359738368 >"$f/sys/fs/cgroup/kube/pod/memory.max"; echo 8589934592 >"$f/sys/fs/cgroup/kube/memory.max"
	echo 4294967296 >"$f/sys/fs/cgroup/kube/memory.current"; echo 'inactive_file 0' >"$f/sys/fs/cgroup/kube/memory.stat"
	printf '#!/bin/sh\necho Linux\n' >"$TMP_ROOT/bin/uname"; chmod +x "$TMP_ROOT/bin/uname"
	PATH="$TMP_ROOT/bin:$PATH" VRL_RESOURCES_ROOT="$f" run bash "$R" --samples 1 --logs nowhere
	rm -f "$TMP_ROOT/bin/uname"
	expect_out "4.0 GiB / 8.0 GiB (cgroup v2 limit"
}

test_cgroup_v1_own_path() {
	f="$TMP_ROOT/root1"; mkdir -p "$f/proc/self" "$f/sys/fs/cgroup/memory/slurm/job1"
	echo '4:memory:/slurm/job1' >"$f/proc/self/cgroup"
	echo 9223372036854771712 >"$f/sys/fs/cgroup/memory/memory.limit_in_bytes"
	echo 68719476736 >"$f/sys/fs/cgroup/memory/slurm/job1/memory.limit_in_bytes"
	echo 1073741824 >"$f/sys/fs/cgroup/memory/slurm/job1/memory.usage_in_bytes"
	printf '#!/bin/sh\necho Linux\n' >"$TMP_ROOT/bin/uname"; chmod +x "$TMP_ROOT/bin/uname"
	PATH="$TMP_ROOT/bin:$PATH" VRL_RESOURCES_ROOT="$f" run bash "$R" --samples 1 --logs nowhere
	rm -f "$TMP_ROOT/bin/uname"
	expect_out "1.0 GiB / 64.0 GiB (cgroup v1 limit"
}

test_pipe_in_cells_is_escaped() {
	run bash "$R" --samples 1 --rows
	printf '%s\n' "$OUT" | grep '^| GPU 0 ' | awk -F'[^\\\\]\\|' 'NF != 4 { bad = 1 } END { exit bad }' || { printf '%s\n' "$OUT" | grep '^| GPU 0'; FAILED=1; }
}

test_help_through_stdin() {
	OUT="$(bash -s -- --help <"$R" 2>&1)"
	expect_out "Usage: resources.sh"
}

run_tests
