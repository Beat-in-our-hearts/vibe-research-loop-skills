---
name: vrl-propose-idea
description: Write a testable research hypothesis into the project's Ideas database in Notion, for the user to approve - its line of thought, motivation, feasibility, a planned test listing every group, and a budget giving the single-GPU and multi-GPU time on the current machine. Use in a vibe-research-loop workspace when the user wants to add, draft, or brainstorm research ideas, or when a finding or paper suggests one.
---

# Propose an idea

An idea is one falsifiable hypothesis, written down so the user can judge its feasibility before anything is built. Write it the way a researcher explains an idea to a colleague.

1. **Context.** Read the project's Research Core, its Direction Log included, then Ideas and the idea's sources: findings, papers, earlier experiments, or the user's own words. If an idea is already in Ideas, point the user to it instead of adding it again.
2. **Facts.** Before writing, settle every fact the plan rests on, read-only:
   - Use exactly the settings the user named: model and size, data, scale. If you have to infer one, say so and confirm it with the user.
   - Take every number from a source you can point to: a report, log, results file, or paper. Where a number was measured, quote the measurement; estimate only what nobody has measured, and say it is an estimate.
   - Read the current machine's GPUs in `docs/AGENTS/machine.md`, for the budget. Leave checking the code, environment, checkpoints, and data to the experiment's plan.
3. **Line of thought.** Before writing any section, draft its five steps in plain words: Goal (what you want), Observations (what you saw), Hypothesis (what you guess), Test (how you would check it), and Decision (what you would do with each outcome). Every section must follow from them; where one does not, change the section or the line of thought.
4. **Page.** Create one page per idea in Ideas, and leave Status at Backlog and Human Approved unchecked:

   | Property | Value |
   |---|---|
   | Name | The hypothesis, stated so it can be falsified |
   | ID | Lowercase English words joined by hyphens, at most 24 characters, unique in Ideas (add `-2`, `-3` if taken); never renamed |
   | Priority | Your proposal: High, Medium, or Low |
   | Related | @mentions of the finding, paper, and experiment pages it comes from |

5. **Body.** Fill the line of thought and sections 1–4 by the template's instructions, in the language the workspace's language rules set for Notion pages, or in the working language if they set none:
   - Groups: every group, the baseline and any control included, with what it changes, whether it trains, how it is evaluated, and its seeds; say why each control is there.
   - Success criteria: pass/fail thresholds fixed before anything runs, with every metric defined in one plain sentence where it first appears.
   - Budget: for each group and in total, the time on a single GPU and on the current machine's GPUs, each traced in a few words to a measured number, or marked as a guess. The limits are only your proposal.
6. **Self-review.** Read the page back as the user would, and revise it until every answer is yes:
   - Can a reader tell how many groups run, what each one changes, and why each is there?
   - Is every term and metric explained in plain words, and every number traced to its source?
   - Does the budget give each group's single-GPU time and the totals on one GPU and on the current machine, each with its basis?
   - Does each section follow from the line of thought, with no step missing?
   - Are the settings the user named used unchanged?
7. **Report.** Show the user one table with each idea's page link, hypothesis, groups, success criteria, and proposed budget, then the facts you could not settle. Ask them to review the page (by coloring its text as the rules below describe, or in words), set the Budget limits, and tick Human Approved; build nothing before they do.

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
