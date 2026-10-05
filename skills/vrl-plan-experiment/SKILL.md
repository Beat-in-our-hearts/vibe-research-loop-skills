---
name: vrl-plan-experiment
description: Plan the next experiment of an approved idea in a vibe-research-loop workspace. Create its Experiments page in Notion - every run, a time estimate from measured numbers on the current machine, and a detail plan whose steps each have a condition to go on and a list of writes - and its plan file, prepare and smoke-test the code and configs, and ask the user to approve the plan. Use when the user asks to test an idea, design or plan an experiment, or pick up the next approved idea.
---

# Plan an experiment

An experiment is one controlled comparison: a baseline, a treatment that changes exactly one thing, and ablations when needed. Write the plan so a reviewer can follow it without this conversation: every run, every number with its source, every choice with its reason. Nothing runs until the user approves the plan.

1. **Idea.** Take the idea the user names, or else query Ideas for the approved ideas in Backlog and take the highest-Priority one. Go on only if its Human Approved is checked and its Budget has room; otherwise tell the user and stop. Read its Planned test, Budget, and earlier experiments. If it has earlier experiments, plan the next experiment that the latest one's Conclusion proposes.
2. **Facts.** Before designing anything, settle every fact the plan rests on, read-only:
   - Take every number from a source you can point to, such as a log, report, or results file, with the hardware it was measured on; estimate only what nobody has measured, and mark it as an estimate.
   - Read the current machine in `docs/AGENTS/machine.md`, and check the code, environments, checkpoints, and data the plan needs; count what is missing or must be rebuilt as setup work.
   - Read the code the plan builds on: what each hyperparameter you will list does, and which inputs and targets each component takes from a sample. Never infer them from a name.
   - Trace one training batch through the code, from the data loader to the total loss: the tensor shape after every step that changes it, where each component reads its input, where gradients stop, and every loss term with its formula, weight, averaging, and masking.
3. **Page.** Create the page in Experiments with Name (the experiment in a few words), ID (lowercase English words joined by hyphens, at most 24 characters, unique in Experiments, never renamed), and Idea. Leave Status at Planned and Human Approved unchecked. If the idea's Status is Backlog, set it to Testing.
4. **Draft.** Fill sections 1–3 by the template's instructions, in the language the workspace's language rules set for Notion pages, or the working language if they set none, with planned values where no config exists yet:
   - Runs: every run, evaluation-only checks included, with what it trains, how it is evaluated, and what it shows; why each control is there; and each design choice with its reason and the alternative you considered.
   - Deviations: every difference from the idea's Planned test, with its reason; copy the success criteria verbatim.
   - Data flow and losses: the traced batch, as a shape diagram and one line per loss term, for every model that differs, so a reviewer can check what the code computes without reading it.
   - Time estimate: every piece of work, from measured numbers scaled to the current machine, counting what the treatment adds over the baseline, re-evaluations, and environments to rebuild.
   - Detail plan: the steps in order, each with its output, condition to go on, time, and every write it makes.
5. **Setup.** Do the setup steps of the Detail plan in order: the code and one config per run, following the workspace's git rules on branches and worktrees; then the environments and data; last, a short smoke run of each config, logged in `logs/`. In remote mode, first show the user the page link and the writes these steps and the plan file make on the remote host, and make only the writes they approve. If a step's condition to go on fails, stop and report.
6. **Update.** Replace the planned values in section 3 from the config snapshots. Re-estimate the time from the smoke run's measured step times and the bottleneck it shows, and set Est. Hours to the new wall-clock from the first run to the end of the plan. Write `docs/plans/<date>-<name>.md`, where `<date>` is the page's Created date and `<name>` its ID: the question, design, runs, Detail plan, configuration, and exact launch command of each run, consistent with sections 1–3.
7. **Self-review.** Read the page back as the user would, and revise it until every answer is yes:
   - Can a reader tell how many runs there are, what each does, and why each is there?
   - Is every term, hyperparameter, and number explained in plain words, and every number traced to its source?
   - Can a reader follow one batch from the data to the total loss: every shape, where gradients stop, and every loss term with its weight?
   - Does the time estimate fit the current machine, show its basis, and separate measured from estimated numbers?
   - Does every deviation carry a reason, and are the success criteria copied unchanged?
   - Does every Detail plan step have a condition to go on and list its writes?
8. **Report.** Show the user the page link, the question, the runs with their machines, the time estimate before and after the smoke run next to the idea's Estimate table and the room left in its Budget, every deviation with its reason, and the writes of the post-approval steps, which ticking Human Approved also approves. Ask them to review sections 1–3, by coloring the text as the rules below describe or in words, and to tick Human Approved; launch nothing before they do.

## Rules

- Work from the root of a vibe-research-loop workspace, the directory with `AGENTS.md` and `docs/AGENTS/`, and follow its rules. Anywhere else, tell the user and stop.
- If `docs/AGENTS/remote.md` exists, this machine computes on a remote host over SSH, and that file says where each path lives and where each command runs: every workspace path but `AGENTS.md` and `docs/AGENTS/` is in the remote workspace, read and written locally through the mount; everything but file edits, `ntn`, and web requests runs on the remote host through the SSH master. Never fall back to the local machine.
- Use the `ntn` CLI for Notion, and look up its usage live: `ntn --help`, `ntn api ls`, `ntn api <path> -X <method> --spec`. Always run `ntn api ... < /dev/null`, or it waits on stdin.
- Take the IDs of the project page and the databases from `docs/notion/ids.md`. If it is missing, find them with `ntn api v1/search` by exact title, reading every page of results; ask the user which project if several match, and record the IDs there in a table with the columns Object, Title in Notion, Page ID, Database ID, and Data source ID.
- Create a page with `"template": {"type": "default", "timezone": "<TZ>"}`, where `<TZ>` is the `TZ` in the workspace's `.env`. It comes back blank while Notion applies the template: wait until the template's blocks appear.
- Fill each section by its gray instructions; once it is filled, delete its gray instruction lines and any `…` placeholder left in it. Delete the template's opening quote when you first fill the page. A section that a later step fills keeps its instructions and placeholders until that step fills it. To see the instructions of a cleaned section, read the database's template: `ntn api v1/data_sources/<data source ID>/templates`, then that template page's blocks.
- Write every page in sentences a colleague can follow without decoding. Common abbreviations such as w/, w/o, ckpt, bs, lr, approx., or SR are fine on their own, but never string abbreviations and symbols together with no words between them; spell an abbreviation out the first time only when it is uncommon in the field or made up for this project.
- Keep each table cell short: a value, a phrase, or one sentence. When a cell holds several points, put each on its own line within the cell (a `\n` in its rich text, since a cell cannot hold list blocks), starting with `1.`, `2.` when their order matters and `•` otherwise. When a cell would run past three lines, move its content into a list right below the table and leave a short pointer in the cell.
- Read a page before every write and read it back after; merge the user's edits instead of overwriting them.
- The user reviews a page by coloring its text or the text's background: red marks what they think is wrong, orange what they did not understand, purple what they cannot accept; other colors are not marks. Before every write to a page, read the colors of all its text, table cells included (`annotations.color` of each rich-text item, and the block's `color`), and answer each mark, telling the user what you change and why: fix red text; explain orange text in plainer words and rewrite it so that it no longer needs the explanation; for purple text, propose an alternative and leave the text and its mark in place until the user decides. Write rewritten text without the mark, and leave every mark you have not resolved in place.
- Add a figure by uploading its PNG with `ntn files create --filename <name>.png --content-type image/png < <file>`, then inserting it as an image block right above its caption.
- Write times in that time zone: `YYYY-MM-DD HH:MM` in text, and `"time_zone": "<TZ>"` on date properties.
- Never make a Human-In-Loop decision: tick Human Approved, set Confirmed or Overturned, or change a Budget limit the user has set.
