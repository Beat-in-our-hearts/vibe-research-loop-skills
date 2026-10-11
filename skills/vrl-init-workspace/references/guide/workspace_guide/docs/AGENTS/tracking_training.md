# Tracking training

- Before a long task starts, such as a training plan's first run, suggest scheduled reports to the user, timed by the agent itself, as with `/loop` without an interval in Claude Code; without such a scheduler, the user asks for each report.
- Time each report by what comes next: soon after the next evaluation, checkpoint, task end, or a waiting task's start; sooner while something is at risk, such as a failing run or a resource near its limit; further apart while nothing will change, yet never so far that a failure goes unnoticed for long. End each report with the time of the next, and stop the reports once every task has ended.
- Between reports, never hold a command open to wait; check with short commands when a report is due.
- Write each report in the reply language: the time with its UTC offset, then one table as in the example: the plan's tasks in plan order, then the resources.
- Task rows, by Status: ✅ done, with the result, the comparison and its p-value (> or < only when significant, ≈ otherwise), and any published reference number; ▶ and the running phase (Training, Eval), with epoch and step, overall progress, the latest losses, and its GPU; ⏳ waiting, with what it needs and how long it should take; ❌ failed.
- Take the GPU, memory, and storage rows from `resources.sh --rows --allowed <the GPU ids experiments may use>`, one of the VRL scripts, and add a storage quota row from this machine's quota command, if any.
- Below the table, add one line for each thing that needs the user: a failure, a limit nearly reached, a result that looks too good, a GPU that `resources.sh` lists as not free for a reason no run explains, such as another user's process, and any `note:` it prints.

## Example

**Plan `env-c-comparison` · 2026-09-30 10:05 +00:00**

| Item | Status | Details |
|---|---|---|
| Env A | ✅ | Method X 82.4 % > baseline 78.0 % (p = 0.01) |
| Env C, train method X | ▶ Training | Epoch 3/5, step 10,200 (about 56 % overall); val loss 0.0087; GPU 0 |
| Env C, train baseline | ⏳ | About 3.3 h, 8 workers |
| GPU 0 | 96 % | Memory 38.2 / 46.0 GiB, power 344 / 350 W; run 2026-09-30-env-c-comparison/train-method-x |
| Memory | 64 % | 102 / 160 GiB |
| Storage quota | 81 % | 1.21 / 1.50 TB |
