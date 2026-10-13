---
name: vrl-night-watch
description: Watch a vibe-research-loop workspace overnight: launch approved runs on free GPUs without asking the user anything, and leave a morning report. Never pick it on your own; use it only when the user starts it by name, usually through `/loop /vrl-night-watch` or an automation.
---

# Night watch

The window is 22:00 to 10:00 in `.env`'s `TZ`, or the hours given, such as `23:00-08:00`. The only memory between wake-ups is `logs/<date>-night-watch.log`, dated by the window's last morning. Call every command in the exact form its permission rule allows, with `S` the VRL scripts path in `docs/AGENTS/machine.md`, `check_update.sh` included: `bash S/<script>.sh …` and `python3 S/gpu_hours.py …`; in remote mode, `bash S/vrl_ssh.sh script A --workspace R --limit L -- <script> …`, and `bash S/vrl_ssh.sh read A --workspace R --limit L -- <path>`, without `--lines`, with `A`, `R`, and `L` from `docs/AGENTS/remote.md`.

1. **Permissions.** Only at the first `/loop` wake-up, or a run by hand before an automation or job exists: read `<this skill's folder>/references/permissions.md`, give the user its rules with this machine's values, and recommend Claude Code's `dontAsk` mode, never one that skips every check.
2. **No questions.** Inside the window, never ask or wait for the user.
   - Leave work that needs them, such as an approval, a deviation, a failed Go on when, or a plan fix; log what they must decide, and why.
   - Launch only approved runs. Never plan or approve an experiment, or change code, configs, plans, or the Code row's SHA-256; never pass `--resume` or `--new-session`; never stop a process you did not start.
   - Append each launch, with its commit, and each restart, refusal, and skip to the log at once.
3. **Each wake-up.** Read the time with `date`. Work out the current window, or the last and next, with dates and UTC offsets.
   - On a fixed interval, if the log's last `wake-up <time> started` line is under an hour old with no `ended` line after it, end the turn; else append a started line, and an ended one at the end.
   - From an hour before the window, create its log, with both ends, if missing. In the window, do step 4; after it, do step 5 if the last window's log holds no report.
   - With `/loop`, end each wake-up by scheduling the next within the hour: in the window, soon after a run's next evaluation or end, by the window's end; outside, at its start if sooner. Stop the loop after the morning report.
4. **Inside the window.**
   1. **Runs.** Check runs of Running experiments as steps 4 and 5 of vrl-run-experiment do, leaving analysis to the morning report. Restart with `--restart`, after starting a missing tmux session, only a run with no log footer and no live process; one needing a fix stays stopped.
   2. **GPUs.** Only GPUs on the `free:` line of `resources.sh --allowed <machine.md's GPU ids>` are free; record why none is, and each `note:` line.
   3. **Launch.** While a GPU is free, launch the next run in line as steps 1, 3, and 4 of vrl-run-experiment do: first waiting runs of Running experiments, oldest first; then of the next experiment with Status Planned and Human Approved, by its idea's Priority, then earliest Created. Launch a run only if every earlier step, the smoke run included, is done or is a run; the tmux session runs or starts; the idea's Budget allows it, counted as in vrl-plan-experiment step 1 by `gpu_hours.py` without exit 3; and storage is not nearly full, per machine.md's quota command if any. Else record why and try the next. If `launch_run.sh` exits with anything but 0, record its reason and launch nothing more of that experiment. In remote mode, never sync.
5. **Morning report.** At the first wake-up after the window, stop launching, and write the report as `<this skill's folder>/references/morning_report.md` says.

## Rules

- At the start, run `bash <kit>/scripts/check_update.sh`, where `<kit>` is `<this skill's folder>/../vrl-init-workspace`. Report a newer release once per session with its update command; update only when asked.
- Work from a vibe-research-loop workspace root (with `AGENTS.md` and `docs/AGENTS/`) and follow its rules. Elsewhere, tell the user and stop.
- Before your first `ntn` or `lark-cli` call, read `<kit>/references/pages.md` once per session, and again once its text has left your context, and follow it.
- If `docs/AGENTS/remote.md` exists, follow it, and run no code here.
- Never improvise what the scripts in `<kit>/scripts/` do: `launch_run.sh` starts every long-running command, `resources.sh` reports free GPUs, `gpu_hours.py` counts GPU hours, `vrl_ssh.sh` reaches the remote host. Read a script's `--help` only for an option no skill or rule file gives. If one refuses, tell the user why. Work around it only as a rule file says.
- Never make a Human-In-Loop decision: tick Human Approved, set Confirmed or Overturned, or change a Budget limit the user set.
