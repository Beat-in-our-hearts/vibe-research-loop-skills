---
name: vrl-plan-experiment
description: Plan the next experiment of an approved idea in a vibe-research-loop workspace. Create its Experiments page in Notion and its plan file, prepare and smoke-test the code and configs, and ask the user to approve the plan. Use when the user asks to test an idea, design or plan an experiment, or pick up the next approved idea.
---

# Plan an experiment

An experiment is one controlled comparison: a baseline, a treatment that changes exactly one thing, and ablations when needed. Nothing runs until the user approves its plan.

1. **Idea.** Take the idea the user names, or else query Ideas for the approved ideas still in Backlog and take the one with the highest Priority. Go on only if its Human Approved is checked and its Budget has room; otherwise tell the user and stop. Read its Planned test, its Budget, and its earlier experiments.
2. **Page.** Create the page in Experiments with Name (the experiment in a few words), ID (lowercase English words joined by hyphens, at most 24 characters, unique in Experiments, never renamed), and Idea. Leave Status at Planned and Human Approved unchecked. If the idea's Status is Backlog, set it to Testing.
3. **Code.** Implement the change and one config per run, following the workspace's git rules on branches and worktrees. Check them with a short smoke run, logged in `logs/`, and set Est. Hours from the measured step time × the total steps.
4. **Plan.** Write `docs/plans/<date>-<name>.md`, where `<date>` is the page's Created date and `<name>` its ID: the question, the design, the run table, the configuration, and the exact launch command of each run. Fill sections 1–3 of the page to match it.
5. **Report.** Show the user the page link, the question, the runs with their machines, the estimated compute, and every deviation from the idea's Planned test. Ask them to review sections 1–3 and tick Human Approved; launch nothing before they do.

## Rules

- Work from the root of a vibe-research-loop workspace, the directory with `AGENTS.md` and `docs/AGENTS/`, and follow its rules. Anywhere else, tell the user and stop.
- If `docs/AGENTS/remote.md` exists, this machine computes on a remote host over SSH, and that file says where each path lives and where each command runs: every workspace path but `AGENTS.md` and `docs/AGENTS/` is in the remote workspace, read and written locally through the mount, and everything but file edits, `ntn`, and web requests runs on the remote host through the SSH master. Never fall back to the local machine.
- Use the `ntn` CLI for Notion, and look its usage up live: `ntn --help`, `ntn api ls`, `ntn api <path> -X <method> --spec`. Always run `ntn api ... < /dev/null`, or it waits on stdin.
- Take the IDs of the project page and the databases from `docs/notion/ids.md`. If it is missing, find them with `ntn api v1/search` by their exact titles, reading every page of results; ask the user which project if several match, and record them there in a table with the columns Object, Title in Notion, Page ID, Database ID, and Data source ID.
- Create a page with `"template": {"type": "default", "timezone": "<TZ>"}`, where `<TZ>` is the `TZ` in the workspace's `.env`. It comes back blank while Notion applies the template, so wait until the template's blocks appear.
- Fill a page by following the gray instructions of each section, then keep only the content: once a section is filled, delete its gray instruction lines and any `…` placeholder left in it, and delete the template's opening quote. A section that a later step fills keeps its instructions and placeholders until that step fills it. To see the instructions of a section that has already been cleaned, read them from the database's template: `ntn api v1/data_sources/<data source ID>/templates`, then that template page's blocks.
- Read a page before every write and read it back after; merge the user's edits instead of overwriting them.
- Add a figure by uploading its PNG with `ntn files create --filename <name>.png --content-type image/png < <file>`, then inserting it as an image block right above its caption.
- Write times in that time zone: `YYYY-MM-DD HH:MM` in text, and `"time_zone": "<TZ>"` on date properties.
- Never make a Human-In-Loop decision: tick Human Approved, set Confirmed or Overturned, or change a Budget limit the user has set.
