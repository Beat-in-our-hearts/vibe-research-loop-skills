# Tracking training

- Before a long task, such as a plan's first run, suggest reports you schedule yourself, as with `/loop` and no interval in Claude Code; without such a scheduler, the user asks for each.
- Time each report soon after the next evaluation, checkpoint, task end, or waiting task's start; sooner while something is at risk; never so late that a failure goes unnoticed. End it with the next report's time; stop once every task has ended.
- Never hold a command open to wait; check with short commands.
- A report: the time with its UTC offset, then one table as below, the plan's tasks in plan order, then the rows of `resources.sh --rows --allowed <experiment GPU ids>` and a storage quota row from the quota command, if any.
- Task rows: ✅ done, with the result, the comparison with its p-value (> or < only when significant, else ≈), and any published reference; ▶ and the phase, with epoch, step, overall progress, latest losses, and GPU; ⏳ waiting, with what it needs and how long it takes; ❌ failed.
- Below the table, one line per thing that needs the user: a failure, a limit nearly reached, a result that looks too good, a GPU not free for a reason no run explains, and each `note:` line.

**Plan `env-c-comparison` · 2026-09-30 10:05 +00:00**

| Item | Status | Details |
|---|---|---|
| Env A | ✅ | Method X 82.4 % > baseline 78.0 % (p = 0.01) |
| Env C, method X | ▶ Training | Epoch 3/5, step 10,200 (56 % overall); val loss 0.0087; GPU 0 |
| Env C, baseline | ⏳ | About 3.3 h, 8 workers |
| Storage quota | 81 % | 1.21 / 1.50 TB |
