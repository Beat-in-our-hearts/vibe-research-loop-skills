---
name: vrl-propose-idea
description: Write a testable research hypothesis into the project's Ideas database in Notion - its line of thought, motivation, feasibility, a planned test that lists every group and stage, and a budget estimated from measured numbers on the current machine - for the user to approve. Use in a vibe-research-loop workspace when the user wants to add, draft, or brainstorm research ideas, or when a finding or paper suggests one.
---

# Propose an idea

An idea is one falsifiable hypothesis, written down so that the user can judge its feasibility before anything is built. Write it the way a researcher explains an idea to a colleague: what they want, what they saw, what they guess, how they would check it, and what they would do with each outcome.

1. **Context.** Read the project's Research Core, its Direction Log included, then the Ideas database and the sources the idea comes from: findings, papers, earlier experiments, or the user's own words. If an idea is already in Ideas, point the user to it instead of adding it again.
2. **Facts.** Before writing, settle every fact the plan rests on, read-only:
   - Use exactly the settings the user named: the model and its size, the data, the scale. If you have to infer one, say so and confirm it with the user.
   - Take every number from a source you can point to: a report, a log, a results file, or a paper. Never estimate what was measured.
   - Read the current machine in `docs/AGENTS/machine.md`, and check that what the test needs exists: code, environment, checkpoints, and data. Count what is missing as setup work.
3. **Line of thought.** Write its five steps before any section, in plain words: Goal, Observations, Hypothesis, Test, and Decision. Every section must follow from them; where one does not, change the section or the line of thought.
4. **Page.** Create one page per idea in Ideas, and leave Status at Backlog and Human Approved unchecked:

   | Property | Value |
   |---|---|
   | Name | The hypothesis, stated so that it can be falsified |
   | ID | Lowercase English words joined by hyphens, at most 24 characters, unique in Ideas (add `-2`, `-3` if taken); never renamed |
   | Priority | Your proposal: High, Medium, or Low |
   | Related | @mentions of the finding, paper, and experiment pages it comes from |

5. **Body.** Fill the line of thought and sections 1–4 by the template's instructions, in the language the workspace's rules set for Notion:
   - Groups: every group, the baseline and any control included, with what it changes, whether it trains, how it is evaluated, and its seeds; say why each control is there.
   - Stages: begin with the smallest test that can show whether the idea is promising, with the condition for going on; a later stage needs a new approval.
   - Success criteria: pass/fail thresholds fixed before anything runs, with every metric defined in one plain sentence where it first appears.
   - Budget: estimate every piece of work, setup and re-evaluations included, from measured numbers scaled to the current machine; name what limits its speed, mark what is measured and what is estimated, and give the total task time and the wall-clock time. The limits are only your proposal.
6. **Self-review.** Read the page back as the user would, and revise it until every answer is yes:
   - Can a reader tell how many groups run, what each one changes, and why each is there?
   - Is every term and metric explained in plain words, and every number traced to its source?
   - Does the budget show its arithmetic, separate measured from estimated numbers, and fit the current machine?
   - Does each section follow from the line of thought, with no step missing?
   - Are the settings the user named used unchanged?
7. **Report.** Show the user one table with each idea's page link, hypothesis, groups, success criteria, and proposed budget, then the facts you could not settle. Ask them to review the page, by coloring its text as the rules below describe or in words, to set the Budget limits, and to tick Human Approved; build nothing before they do.

## Rules

- Work from the root of a vibe-research-loop workspace, the directory with `AGENTS.md` and `docs/AGENTS/`, and follow its rules. Anywhere else, tell the user and stop.
- If `docs/AGENTS/remote.md` exists, this machine computes on a remote host over SSH, and that file says where each path lives and where each command runs: every workspace path but `AGENTS.md` and `docs/AGENTS/` is in the remote workspace, read and written locally through the mount, and everything but file edits, `ntn`, and web requests runs on the remote host through the SSH master. Never fall back to the local machine.
- Use the `ntn` CLI for Notion, and look its usage up live: `ntn --help`, `ntn api ls`, `ntn api <path> -X <method> --spec`. Always run `ntn api ... < /dev/null`, or it waits on stdin.
- Take the IDs of the project page and the databases from `docs/notion/ids.md`. If it is missing, find them with `ntn api v1/search` by their exact titles, reading every page of results; ask the user which project if several match, and record them there in a table with the columns Object, Title in Notion, Page ID, Database ID, and Data source ID.
- Create a page with `"template": {"type": "default", "timezone": "<TZ>"}`, where `<TZ>` is the `TZ` in the workspace's `.env`. It comes back blank while Notion applies the template, so wait until the template's blocks appear.
- Fill a page by following the gray instructions of each section, then keep only the content: once a section is filled, delete its gray instruction lines and any `…` placeholder left in it, and delete the template's opening quote. A section that a later step fills keeps its instructions and placeholders until that step fills it. To see the instructions of a section that has already been cleaned, read them from the database's template: `ntn api v1/data_sources/<data source ID>/templates`, then that template page's blocks.
- Read a page before every write and read it back after; merge the user's edits instead of overwriting them.
- The user reviews a page by coloring its text, in the text or its background: red marks what they think is wrong, orange what they did not understand, and purple what they cannot accept. Before every write, read the colors of every segment, table cells included (`annotations.color` of each rich-text item, and the block's `color`). For each mark, tell the user what you change and why: fix red, explain orange in plainer words and rewrite it so it no longer needs the explanation, and for purple propose an alternative and wait for their decision. Rewritten text drops the mark; leave a mark you have not resolved in place.
- Add a figure by uploading its PNG with `ntn files create --filename <name>.png --content-type image/png < <file>`, then inserting it as an image block right above its caption.
- Write times in that time zone: `YYYY-MM-DD HH:MM` in text, and `"time_zone": "<TZ>"` on date properties.
- Never make a Human-In-Loop decision: tick Human Approved, set Confirmed or Overturned, or change a Budget limit the user has set.
