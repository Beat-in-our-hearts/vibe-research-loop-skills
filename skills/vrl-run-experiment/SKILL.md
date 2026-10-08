---
name: vrl-run-experiment
description: Launch and monitor an approved experiment's runs in a vibe-research-loop workspace, keep its Notion page's logs, status, and progress current, report on a schedule timed by what the runs do next, and close it with its outcome. Use when the user asks to start, resume, check on, or monitor an experiment's runs.
---

# Run an experiment

1. **Check.** Read the Experiments page live: Human Approved must be checked, Status must be Planned or Running, and the plan file must hold a launch command for every run in section 1; otherwise tell the user and stop. Run only the run-table rows assigned to this machine, on free GPUs.
2. **Reports.** Before the first run, suggest scheduled reports to the user, at no fixed interval: in Claude Code, they start `/loop` with no interval and a request such as "check on <ID> and report", and you time each report yourself; without such a scheduler, the user asks for each one. Time each report by what comes next: soon after the next evaluation, checkpoint, or run end, or when a waiting run can start; sooner while something is at risk, such as a run that may fail or a resource near its limit; further apart while nothing will change, but never so far that a failure would go unnoticed for long. End each report with the time of the next.
3. **Launch.** Go through the post-approval steps in section 1, in order; if a step's Go on when condition fails, stop there and report to the user. Start each run with its launch command from the plan, its log at `logs/<date>-<name>/<run>.log`, and its outputs in `runs/<date>-<name>/<run>/`. In remote mode, start it detached in its own window of the remote tmux session, and name that window in the log's `session` line. Add the launch commit to the Code row of section 2, and save `git diff` in the run folder if the checkout is dirty. With the first run, set Status to Running and Started to its start time.
4. **Monitor.** At every checkpoint or evaluation, update section 3, and Est. Hours when the ETA drifts more than 20%; report to the user at each time step 2 sets.
   - Restart a run that stopped for an outside reason, such as a node failure or preemption, with the same config, and add an incident row to section 3.
   - A fix that changes the code, a config, or the plan needs a new approval: stop the affected runs, record the change under Deviations, and ask the user.
5. **Close.** Once every run of the plan has ended, on every machine, set Status to Finish and Outcome as below, stop the scheduled reports, and tell the user.

   | Outcome | When |
   |---|---|
   | Done | Every run in the approved plan finished, even if the success criteria are missed |
   | Failed | The plan could not be completed: a crash, out of memory, or a divergence that could not be fixed |
   | Invalid | The comparison cannot be trusted: mismatched evaluation code or data, a bug, or a plan change without a new approval |

   Go on with vrl-analyze-results for Done; for Failed or Invalid, give the user the reason and a proposal.

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
