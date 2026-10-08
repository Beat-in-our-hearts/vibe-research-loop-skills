---
name: vrl-night-watch
description: Keep watch over a vibe-research-loop workspace while the user sleeps, by default from 22:00 to 10:00 in the project's time zone - without asking the user anything, launch the next approved experiment whenever a GPU is free and not claimed, monitor the runs, and leave a morning report of what ran and what waits for the user. Use only when the user starts it, usually through a self-paced loop.
disable-model-invocation: true
---

# Night watch

While the user sleeps, keep the GPUs busy with work the user has already approved, and never wait for an answer. The user starts it before going to bed:
- in Claude Code, with `/loop /vrl-night-watch` and no interval, so that you choose each wake-up yourself;
- elsewhere, from a scheduled job, such as cron, that runs this skill every half hour.

Other hours go after the command, such as `/vrl-night-watch 23:00-08:00`.

1. **Start.** At the first wake-up:
   - Take the window from the command, or else 22:00 to 10:00, in the project's time zone, the `TZ` in `.env`. Before the window starts, schedule the next wake-up at its start and end the turn.
   - Check that this session can run unattended. If a command the watch needs would stop for a permission prompt, tell the user now, before the window starts, how to allow it, such as with an allowlist or Claude Code's auto mode, but never with a mode that skips every check. Such commands include `nvidia-smi`, a launch command, the memory store's CLI (`ntn` or `lark-cli`), and `ssh` in remote mode.
   - Tell the user the window, the approved experiments in line, and the time of the morning report.
2. **No questions.** Inside the window, never ask the user anything, and never wait for an answer or a prompt.
   - Wherever a step here or in vrl-run-experiment would need the user, leave that work where it is and record what they must decide, and why, for the morning report. Such steps include an approval, a deviation, a failed Go on when condition, and a fix that changes the plan.
   - Launch only what the user approved. Never plan or approve an experiment; never change code, a config, or a plan; and never stop a process you did not start.
3. **Each wake-up.**
   1. **Runs.** Check every run of the experiments with Status Running, as steps 4 and 5 of vrl-run-experiment do: update their pages, restart a run that stopped for an outside reason, and close an experiment whose runs have all ended, leaving its analysis for the morning report. A run that needs a fix stays stopped.
   2. **GPUs.** Read `nvidia-smi`, and the scheduler's queue if `docs/AGENTS/machine.md` names a scheduler. A GPU is free when no process runs on it, its memory is nearly empty, and nothing claims it: no waiting run of a Running experiment is assigned to it, no scheduler job holds it, and no one else uses it.
   3. **Next experiment.** When a GPU is free, take the approved experiment next in line: Status Planned and Human Approved checked, by its idea's Priority, then the earliest Created. Launch it as steps 1, 3, and 4 of vrl-run-experiment do, but only if all of these hold; otherwise record why, and try the next one:
      - its plan file holds a launch command for each run, and the steps before approval are done, the smoke run included;
      - its runs assigned to this machine fit the free GPUs, or its steps let them start one at a time;
      - the idea's Budget limits allow it, counted as vrl-plan-experiment counts the budget left, and the storage that holds the outputs is not nearly full.
   4. **Next wake-up.** Schedule it by what comes next: soon after a run's next evaluation or end, so that a freed GPU does not sit idle; at most an hour later while nothing changes, to catch a GPU that someone else frees; and at the end of the window.
4. **Morning report.** At the end of the window, stop launching and end the scheduled wake-ups; the runs keep going. Show the user the report, and append it to `logs/<date>-night-watch.log`, where `<date>` is the morning's date:
   - what ran overnight: each run launched, finished, or restarted, with its experiment, its GPU, and its outcome or progress;
   - each GPU's use over the night, and when one sat idle, why;
   - what waits for the user, each item with what they need to decide: an experiment skipped, a run stopped for a fix, an approval to give, or a finished experiment to analyze.

## Rules

- At the start, run `bash <this skill's folder>/../vrl-init-workspace/scripts/check_update.sh` where the skills are installed, the local machine in remote mode. If it reports a newer release, tell the user once in the session, with the update command it prints, and go on; never update the skills unless the user asks.
- Work from the root of a vibe-research-loop workspace, the directory with `AGENTS.md` and `docs/AGENTS/`, and follow its rules. Anywhere else, tell the user and stop.
- If `docs/AGENTS/remote.md` exists, this machine computes on a remote host over SSH, and that file says where each path lives and where each command runs: every workspace path but `AGENTS.md` and `docs/AGENTS/` is in the remote workspace, read and written locally through the mount; everything but file edits, `ntn`, and web requests runs on the remote host through the SSH master. Never fall back to the local machine.
- If `docs/AGENTS/feishu.md` exists, the project's memory store is Feishu, not Notion: wherever this skill names Notion, `ntn`, a page, a database, or a property, do what that file says instead. It replaces the rules below that only make sense in Notion.
- Use the `ntn` CLI for Notion, and look up its usage live: `ntn --help`, `ntn api ls`, `ntn api <path> -X <method> --spec`. Always run `ntn api ... < /dev/null`, or it waits on stdin.
- Take the IDs of the project page and the databases from `docs/notion/ids.md`. If it is missing, find them with `ntn api v1/search` by exact title, reading every page of results; ask the user which project if several match, and record the IDs there in a table with the columns Object, Title in Notion, Page ID, Database ID, and Data source ID.
- Create each new page from its database's template file, never from a template in Notion: `ideas.md`, `experiments.md`, `findings.md`, or `papers.md` in `<this skill's folder>/../vrl-init-workspace/references/guide/notion_guide/templates/`. Give the page the default properties in the file's header, and write each part of the body below its line only when you fill it, at its place in the template, by its instructions in italics, which stay in the file: a page holds only content, never instruction text or a `…` placeholder.
- A page whose headings differ from its template's was written from an older template: find each section by its name, not its number, and tell the user before you write to it.
- An Ideas, Experiments, or Findings page opens with a callout that tells the user what they decide and how. Whenever such a page goes to them for review, rewrite the callout in place as its template says.
- Write Notion pages in the language the workspace's language rules set for them, or else in the reply language. That covers the headings, labels, and table headers you take from a template. Use property names and the options of select and status properties exactly as the database defines them, and keep identifiers, code, paths, and commands as they are.
- Write every page in sentences a colleague can follow without decoding, and state each fact once, where it belongs: elsewhere, refer to it by page and section name instead of repeating it, unless a template asks for it again, as an opening callout, Decided by, or a finding does. Give a reason only for a deviation, a control, an estimate, or a ✘, or where a template asks for one. Common abbreviations such as w/, w/o, ckpt, bs, lr, approx., or acc. are fine on their own, but never string abbreviations and symbols together with no words between them; spell an abbreviation out the first time only when it is uncommon in the field or made up for this project.
- Keep each table cell short: a value, a phrase, or one sentence. When a cell holds several points, put each on its own line within the cell (a `\n` in its rich text, since a cell cannot hold list blocks), starting with `1.`, `2.` when their order matters and `•` otherwise. When a cell would run past three lines, move its content into a list right below the table and leave a short pointer in the cell.
- Read a page before every write and read it back after; merge the user's edits instead of overwriting them.
- The user reviews a page by coloring its text or the text's background: red marks what they think is wrong, orange what they did not understand, purple what they cannot accept; other colors are not marks. Before every write to a page, read the colors of all its text, table cells included (`annotations.color` of each rich-text item, and the block's `color`), and answer each mark, telling the user what you change and why: fix red text; explain orange text in plainer words and rewrite it so that it no longer needs the explanation; for purple text, propose an alternative and leave the text and its mark in place until the user decides. Write rewritten text without the mark, and leave every mark you have not resolved in place.
- Add a figure by uploading its PNG with `ntn files create --filename <name>.png --content-type image/png < <file>`, then inserting it as an image block right above its caption.
- Write times in the project's time zone, the `TZ` in the workspace's `.env`: `YYYY-MM-DD HH:MM` in text, and `"time_zone": "<TZ>"` on date properties.
- Never make a Human-In-Loop decision: tick Human Approved, set Confirmed or Overturned, or change a Budget limit the user has set.
