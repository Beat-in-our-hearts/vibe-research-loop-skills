---
name: vrl-run-experiment
description: Launch and monitor an approved experiment's runs in a vibe-research-loop workspace, keep its Notion page's logs, status, and progress current, report on a schedule timed by what the runs do next, and close it with its outcome. Use when the user asks to start, resume, check on, or monitor an experiment's runs.
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
- If `docs/AGENTS/remote.md` exists, follow it. Edit here, send only commits with `vrl_ssh.sh sync`, and take pins and plan hashes from its output. Read results there; fetch only figures or lock files. Run no code here.
- Never improvise what the scripts in `<kit>/scripts/` do: `launch_run.sh` starts every long-running command, `resources.sh` reports free GPUs, `gpu_hours.py` counts GPU hours, `vrl_ssh.sh` reaches the remote host. Read a script's `--help` only for an option no skill or rule file gives. If one refuses, tell the user why. Work around it only as a rule file says.
- If `docs/AGENTS/feishu.md` exists, follow it instead wherever these instructions concern Notion.
- For Notion, use the `ntn` CLI; see `ntn --help`, `ntn api ls`, `ntn api <path> -X <method> --spec`. Always run `ntn api ... < /dev/null`.
- Take project page and database IDs from `docs/notion/ids.md`. If missing, find them by exact title with `ntn api v1/search`, reading all result pages. Ask the user if several projects match. Record them there in columns Object, Title in Notion, Page ID, Database ID, Data source ID.
- Create each page from its database's template file in `<kit>/references/guide/notion_guide/templates/`, not a Notion template, with its header's default properties. Write each part only when you fill it, at its place, by its italic instructions. Leave no instruction text or `…`. When a page goes to review, rewrite its opening callout in place as its template says.
- If headings differ from the template's, find sections by name and tell the user before writing.
- Write pages, headings and labels included, in the language the workspace rules set, else the reply language. Use property and option names exactly as defined.
- State each fact once, where it belongs, and elsewhere point to it unless a template asks otherwise. Give reasons only for deviations, controls, estimates, and ✘, or where a template asks. Spell out at first use abbreviations uncommon in the field or made up here. Never chain abbreviations and symbols without words.
- Keep a table cell to a value, phrase, or sentence. Put several points on separate lines (`\n` in rich text), starting `1.`, `2.` if ordered, else `•`. Move content over three lines to a list below the table, leaving a pointer.
- Read a page before and after every write; merge the user's edits. Read every color, table cells included: each rich-text item's `annotations.color` and the block's `color`. Red, orange, or purple text or background is a review mark. Answer each, telling the user what you change and why. Red (wrong): fix it. Orange (unclear): explain it plainly, and rewrite it to need no explanation. Purple (not acceptable): propose an alternative; keep the text and mark until the user decides. Rewritten text loses its mark. Unresolved marks stay.
- Upload a figure's PNG with `ntn files create --filename <name>.png --content-type image/png < <file>` and place it as an image block right above its caption.
- Write times in the `TZ` of `.env`: `YYYY-MM-DD HH:MM` in text, `"time_zone": "<TZ>"` on date properties.
- Never make a Human-In-Loop decision: tick Human Approved, set Confirmed or Overturned, or change a Budget limit the user set.
