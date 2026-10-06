# Tracking training

- Before a long task starts, such as a training plan's first run, suggest scheduled reports to the user: the agent wakes itself to report, at no fixed interval, as it does when the user starts `/loop` without an interval in Claude Code. Where the agent has no such scheduler, the user asks for each report.
- Time each report by what comes next: soon after the next evaluation, checkpoint, or task end, or when a waiting task can start; sooner while something is at risk, such as a run that may fail or a resource near its limit; further apart while nothing will change, but never so far that a failure would go unnoticed for long. End each report with the time of the next, and stop the scheduled reports once every task has ended.
- Between reports, never hold a command open to wait; check with short commands when a report is due.
- Write each report in the reply language: the time with its UTC offset, then one table. Its rows are the plan's tasks in plan order, then each GPU, then memory, then the storage quota.
- Task rows:
  - Status: ✅ done, ▶ with the phase that is running (Training, Eval), ⏳ waiting, or ❌ failed.
  - Done: the result, with the comparison and its p-value; write > or < only when the difference is significant, and ≈ otherwise; add any published reference number.
  - Running: epoch and step, overall progress, the latest losses, and the GPU it runs on.
  - Waiting: what it needs and how long it should take.
- Resource rows: Status is the usage in percent, which for a GPU is its utilization; Details give used / limit, and for a GPU also its power and the task it runs. Read the real limits, not host-wide numbers: the container's memory limit, `nvidia-smi` for each GPU, and the quota of the filesystem that holds the outputs.
- Below the table, add one line for each thing that needs the user: a failure, a limit nearly reached, a result that looks too good.

## Example

**Plan `env-c-comparison` · 2026-09-30 10:05 +00:00**

| Item | Status | Details |
|---|---|---|
| Env A | ✅ | Method X 82.4 % > baseline 78.0 % (p = 0.01) |
| Env B | ✅ | Method X 70.2 % ≈ baseline 69.5 % (p = 0.41) |
| Env C, train method X | ▶ Training | Epoch 3/5, step 10,200 (about 56 % overall); val loss 0.0087; GPU 0 |
| Env C, eval method X | ⏳ | 13 seeds, about 3 min each |
| Env C, train baseline | ⏳ | About 3.3 h, 8 workers |
| GPU 0 | 96 % | Memory 38.2 / 46.0 GiB, power 344 / 350 W; Env C, train method X |
| GPU 1 | 0 % | Memory 0.4 / 46.0 GiB, power 31 / 350 W; idle |
| Memory | 64 % | 102 / 160 GiB |
| Storage quota | 81 % | 1.21 / 1.50 TB |
