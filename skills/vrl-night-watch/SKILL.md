---
name: vrl-night-watch
description: Keep watch over a vibe-research-loop workspace while the user sleeps, by default from 22:00 to 10:00 in the project's time zone - without asking the user anything, launch the next approved run whenever a GPU is free and not claimed, monitor the runs, and leave a morning report of what ran and what waits for the user. Never pick it on your own; use it only when the user starts it by name, usually through `/loop /vrl-night-watch` or a scheduled automation.
---

# Night watch

Start: `/loop /vrl-night-watch` with no interval in Claude Code; a Codex automation running `$vrl-night-watch` every 30 minutes in the workspace, not a worktree; or a cron job every half hour.

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
5. **Morning report.** At the first wake-up after the window, stop launching; show the user this report and log it:
   - each run launched, finished, or restarted overnight, with its experiment, GPU, and outcome or progress;
   - GPU use, by `gpu_hours.py --json --since '<window start>' --until '<window end>'` on `logs/`, why each GPU of machine.md short of the window's hours idled, from the log, and hours it could not count;
   - runs still going, with ETA, for the user to take over with vrl-run-experiment;
   - what waits for the user, and what they must decide: skipped experiments, runs stopped for a fix, approvals, experiments to analyze.

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
