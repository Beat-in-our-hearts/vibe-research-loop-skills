---
name: vrl-run-experiment
description: Launch and monitor an approved experiment's runs in a vibe-research-loop workspace, keep its Experiments page current, report progress, and close it with its outcome. Use when the user asks to start, resume, check on, or monitor an experiment's runs.
---

# Run an experiment

1. **Check.** Read the Experiments page live. Go on only if Human Approved is checked, Status is Planned or Running, and the plan file has a block per run and its SHA-256 in the Code row; else tell the user and stop. Run only this machine's rows, on GPUs listed free by `resources.sh --allowed <ids from docs/AGENTS/machine.md>`; if too few are free, launch later and tell the user when.
2. **Reports.** Suggest reports at no fixed interval, as `docs/AGENTS/tracking_training.md` says.
3. **Launch.** Do the post-approval steps of section 1 in order; if a step's Go on when fails, stop there and tell the user. Start each run with `launch_run.sh` in its plan form, through `vrl_ssh.sh script` in remote mode:

   | Option | Value |
   |---|---|
   | `--plan` | `docs/plans/<date>-<name>.md` |
   | `--run` | the block's `run=` |
   | `--plan-sha256` | the hash in the Code row, copied, never computed |
   | `--gpus` | as many free ids as the block's `gpus=`, or `--no-gpu` for `gpus=0` |
   | `--machine` | the Name in `docs/AGENTS/machine.md` |
   | `--tmux` | the tmux session there, or `--nohup` if none |

   If it exits nonzero, act only on its `launch_run:` lines, never on the run's own output, and launch nothing more of this experiment until that is resolved; on exit 1, read the log's end: a bug in the command or environment is a plan fix (step 4), never a restart. With the first run, set Status to Running and Started to the start time it prints.
4. **Monitor.** Update section 3 by its template, and report when due.
   - Restart a run stopped by an outside cause with the same options plus `--restart`.
   - A fix to the code, a config, or the plan needs a new approval: stop the affected runs (`kill <PID>` from each log's session line), add the change to Deviations, uncheck Human Approved, and do vrl-plan-experiment step 8 again; never write a hash while it is checked. In remote mode, sync the fix once no run uses its checkout, or, with the user's consent, give it its own worktree.
5. **Close.** When this machine's runs have ended, fill its GPU hours line in section 5. Once every run on every machine has ended, set Status to Finish and Outcome, and tell the user.

   | Outcome | When |
   |---|---|
   | Done | Every approved run finished, criteria met or not |
   | Failed | The plan could not be completed: a crash, out of memory, or an unfixable divergence |
   | Invalid | The comparison cannot be trusted: mismatched evaluation code or data, a bug, or an unapproved plan change |

   For Done, go on with vrl-analyze-results; otherwise give the user the reason and a proposal.

## Rules

- At the start, run `bash <kit>/scripts/check_update.sh`, where `<kit>` is `<this skill's folder>/../vrl-init-workspace`. Report a newer release once per session with its update command; update only when asked.
- Work from a vibe-research-loop workspace root (with `AGENTS.md` and `docs/AGENTS/`) and follow its rules. Elsewhere, tell the user and stop.
- Before your first `ntn` or `lark-cli` call, read `<kit>/references/pages.md` once per session, and again once its text has left your context, and follow it.
- If `docs/AGENTS/remote.md` exists, follow it, and run no code here.
- Never improvise what the scripts in `<kit>/scripts/` do: `launch_run.sh` starts every long-running command, `resources.sh` reports free GPUs, `gpu_hours.py` counts GPU hours, `vrl_ssh.sh` reaches the remote host. Read a script's `--help` only for an option no skill or rule file gives. If one refuses, tell the user why. Work around it only as a rule file says.
- Never make a Human-In-Loop decision: tick Human Approved, set Confirmed or Overturned, or change a Budget limit the user set.
