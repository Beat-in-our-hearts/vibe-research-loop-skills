---
name: vrl-run-experiment
description: Launch and monitor the runs of an approved experiment in a vibe-research-loop workspace, keep its Notion page's logs, status, and progress current, report at the agreed interval, and close it with its outcome. Use when the user asks to start, resume, check on, or monitor an experiment's runs.
---

# Run an experiment

1. **Check.** Read the Experiments page live: Human Approved must be checked, Status must be Planned or Running, and the plan file must match sections 1–3; otherwise tell the user and stop. Run only the rows of the run table assigned to this machine, on GPUs that are free.
2. **Interval.** Before the first run, agree with the user how often to report progress.
3. **Launch.** Start each run with its launch command from the plan, its log at `logs/<date>-<name>/<run>.log`, and its outputs in `runs/<date>-<name>/<run>/`. Add the launch commit to the Code row of section 3, and save `git diff` in the run folder if the checkout is dirty. With the first run, set Status to Running and Started to its start time.
4. **Monitor.** At every checkpoint or evaluation, update section 4, and Est. Hours when the ETA drifts more than 20%; report to the user at the agreed interval.
   - Restart a run that stopped for an outside reason, such as a node failure or preemption, with the same config, and add an anomaly row.
   - A fix that changes the code, a config, or the plan needs a new approval: stop the affected runs, record the change under Deviations, and ask the user.
5. **Close.** Once every run of the plan has ended, on every machine, set Status to Finish and Outcome as below, and tell the user.

   | Outcome | When |
   |---|---|
   | Done | Every run in the approved plan finished, even if the success criteria are missed |
   | Failed | The plan could not be completed: a crash, out of memory, or a divergence that could not be fixed |
   | Invalid | The comparison cannot be trusted: mismatched evaluation code or data, a bug, or a change to the plan without a new approval |

   Go on with vrl-analyze-results for Done; for Failed or Invalid, give the user the reason and a proposal.

## Rules

- Work from the root of a vibe-research-loop workspace, the directory with `AGENTS.md` and `docs/AGENTS/`, and follow its rules. Anywhere else, tell the user and stop.
- Use the `ntn` CLI for Notion, and look its usage up live: `ntn --help`, `ntn api ls`, `ntn api <path> -X <method> --spec`. Always run `ntn api ... < /dev/null`, or it waits on stdin.
- Take the IDs of the project page and the databases from `docs/notion/ids.md`. If it is missing, find them by title with `ntn api v1/search`, ask the user which project if several match, and record them there.
- Create a page with `"template": {"type": "default", "timezone": "Asia/Dubai"}`. It comes back blank while Notion applies the template, so wait until the template's blocks appear.
- Fill a page by following the gray instructions of each section: replace every `…` placeholder, and keep the instructions, which later steps still need.
- Read a page before every write and read it back after; merge the user's edits instead of overwriting them.
- Add a figure by uploading its PNG with `ntn files create --filename <name>.png --content-type image/png < <file>`, then inserting it as an image block right above its caption.
- Write times in UAE time: `YYYY-MM-DD HH:MM` in text, and `"time_zone": "Asia/Dubai"` on date properties.
- Never make a Human-In-Loop decision: tick Human Approved, set Confirmed or Overturned, or change a Budget limit the user has set.
