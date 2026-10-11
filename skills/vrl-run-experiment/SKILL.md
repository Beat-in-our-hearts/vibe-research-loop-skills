---
name: vrl-run-experiment
description: Launch and monitor an approved experiment's runs in a vibe-research-loop workspace, keep its Notion page's logs, status, and progress current, report on a schedule timed by what the runs do next, and close it with its outcome. Use when the user asks to start, resume, check on, or monitor an experiment's runs.
---

# Run an experiment

1. **Check.** Read the Experiments page live. Human Approved must be checked, Status must be Planned or Running, and the plan file must hold a block for every run in section 1, with the plan file's SHA-256 after its name in the Code row of section 2; otherwise tell the user and stop. Run only this machine's rows of the run table, on GPUs that `resources.sh --allowed <the GPU ids in docs/AGENTS/machine.md>` lists as free. If too few are free for a run, launch it later and tell the user when; on `free: unknown`, report the reason and launch nothing. Report every `not free:` reason no run explains, and every `note:` line.
2. **Reports.** Before the first run, suggest scheduled reports as `docs/AGENTS/tracking_training.md` says; in Claude Code, the user starts them with `/loop`, no interval, and a request such as "check on <ID> and report".
3. **Launch.** Go through the post-approval steps in section 1 in order; if a step's Go on when condition fails, stop there and report to the user. Start each run with `launch_run.sh` in its plan form, through `vrl_ssh.sh script` in remote mode:

   | Option | Value |
   |---|---|
   | `--plan` | `docs/plans/<date>-<name>.md` |
   | `--run` | the run's name, as in its block's `run=` |
   | `--plan-sha256` | the hash in the Code row, copied, never computed from the file |
   | `--gpus` | as many ids as the block's `gpus=`, from the `free:` line, or `--no-gpu` for `gpus=0` |
   | `--machine` | the Name in `docs/AGENTS/machine.md` |
   | `--tmux` | the tmux session in `docs/AGENTS/machine.md`, or `--nohup` where it names none |

   Its exit code: 0 started; 1 the run ended at once: read the log's end, and treat a bug in the command as a plan fix (step 4), never a restart; 2 a wrong option, or a missing tmux session, which you start with the command in `docs/AGENTS/machine.md`; 3 refused: report the reason and launch nothing more of this experiment. Add the launch commit to the Code row of section 2. With the first run, set Status to Running and Started to the start time `launch_run.sh` prints.
4. **Monitor.** At every checkpoint or evaluation, update section 3 by its template, and report to the user when each report is due.
   - Restart a run that stopped for an outside reason, such as a node failure or preemption, with the same options plus `--restart`, after starting the tmux session again if it is gone, and add an incident row to section 3.
   - A fix that changes the code, a config, or the plan needs a new approval: stop the affected runs with `kill <PID>` from each log's session line, record the change under Deviations, uncheck Human Approved, pin the blocks and record the new SHA-256 as vrl-plan-experiment step 8 does, rewrite the Review callout, and ask the user to tick it again. In remote mode, commit the fix, and sync it only once no run using its checkout is still going, unaffected ones included; or, with the user's consent, put it in its own worktree and pin the changed blocks to it. Never write a hash while Human Approved is checked.
5. **Close.** When this machine's runs have all ended, add its line to the GPU hours row of section 5, from `gpu_hours.py` on this experiment's log folder. Once every run of the plan has ended, on every machine, set Status to Finish and Outcome as below, stop the scheduled reports, and tell the user.

   | Outcome | When |
   |---|---|
   | Done | Every run in the approved plan finished, even if the success criteria are missed |
   | Failed | The plan could not be completed: a crash, out of memory, or a divergence that could not be fixed |
   | Invalid | The comparison cannot be trusted: mismatched evaluation code or data, a bug, or a plan change without a new approval |

   Go on with vrl-analyze-results for Done; for Failed or Invalid, give the user the reason and a proposal.

## Rules

- At the start, run `bash <this skill's folder>/../vrl-init-workspace/scripts/check_update.sh`. If it reports a newer release, tell the user once per session, with its update command, and go on; update the skills only when asked.
- Work from the root of a vibe-research-loop workspace, which holds `AGENTS.md` and `docs/AGENTS/`, and follow its rules; elsewhere, tell the user and stop.
- If `docs/AGENTS/remote.md` exists, follow it: edit code, plans, and tests here and send them only as commits with `vrl_ssh.sh sync`, recording the pins and plan hashes it prints. Read logs and results with `vrl_ssh.sh read`, `run`, or `launch_run.sh --status`, and bring back with `vrl_ssh.sh fetch` only a figure to upload or a lock file to commit. Write plotting and analysis scripts on the remote host. Run no code here, not even a quick check.
- Never improvise what the scripts in `<this skill's folder>/../vrl-init-workspace/scripts/` do: `launch_run.sh` starts every long-running command, `resources.sh` reports resources and free GPUs, `gpu_hours.py` counts GPU hours, `vrl_ssh.sh` reaches the remote host. Read a script's `--help` only when you need an option that this skill or a rule file does not give. If one refuses or cannot count something (exit code 3), tell the user why; work around it by hand only where a rule file says how.
- If `docs/AGENTS/feishu.md` exists, the memory store is Feishu, not Notion: follow that file instead wherever this skill names Notion, `ntn`, a page, a database, or a property, and wherever a rule below makes sense only in Notion.
- Use the `ntn` CLI for Notion and look up its usage live: `ntn --help`, `ntn api ls`, `ntn api <path> -X <method> --spec`. Always run `ntn api ... < /dev/null`, or it waits on stdin.
- Take the IDs of the project page and databases from `docs/notion/ids.md`. If it is missing, find them by exact title with `ntn api v1/search`, reading every page of results, ask the user which project if several match, and record them there with the columns Object, Title in Notion, Page ID, Database ID, and Data source ID.
- Create each new page from its database's template file, never from a Notion template: `ideas.md`, `experiments.md`, `findings.md`, or `papers.md` in `<this skill's folder>/../vrl-init-workspace/references/guide/notion_guide/templates/`. Set the default properties from the file's header, and write each part of the body only when you fill it, at its place, by its italic instructions. A page holds only content: no instruction text, no `…` placeholder. Whenever an Ideas, Experiments, or Findings page goes to the user for review, rewrite its opening callout in place as its template says.
- A page whose headings differ from its template's comes from an older template: find each section by name, not number, and tell the user before writing to it.
- Write pages, template headings, labels, and table headers included, in the language the workspace's language rules set for them, or else the reply language, with property names and select and status options exactly as the database defines them.
- Write sentences a colleague can follow without decoding. State each fact once, where it belongs, and elsewhere point to its page and section, unless a template asks to repeat it. Give a reason only for a deviation, a control, an estimate, a ✘, or where a template asks. Common abbreviations such as w/o, ckpt, or lr are fine, but never string abbreviations and symbols together without words. Spell out at first use only those uncommon in the field or made up for this project.
- Keep each table cell to a value, a phrase, or one sentence. Put a cell's several points on separate lines within it (a `\n` in its rich text, since a cell cannot hold list blocks), starting with `1.`, `2.` when order matters and `•` otherwise. When a cell would run past three lines, move its content into a list right below the table, with a short pointer in the cell.
- The user marks text for review by coloring it or its background red, orange, or purple; other colors are not marks. Read a page before every write, with the colors of all its text, table cells included (each rich-text item's `annotations.color` and the block's `color`), and read it back after; merge the user's edits instead of overwriting them. Answer each mark, telling the user what you change and why. Red means wrong: fix it. Orange means not understood: explain it in plainer words and rewrite it so it needs no explanation. Purple means not acceptable: propose an alternative, and keep the text and mark until the user decides. Write rewritten text without the mark; leave unresolved marks in place.
- Add a figure by uploading its PNG with `ntn files create --filename <name>.png --content-type image/png < <file>` and inserting it as an image block right above its caption.
- Write times in the `TZ` of the workspace's `.env`: `YYYY-MM-DD HH:MM` in text, and `"time_zone": "<TZ>"` on date properties.
- Never make a Human-In-Loop decision: tick Human Approved, set Confirmed or Overturned, or change a Budget limit the user has set.
