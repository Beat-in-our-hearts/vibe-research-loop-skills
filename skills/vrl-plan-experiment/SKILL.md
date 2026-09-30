---
name: vrl-plan-experiment
description: Plan the next experiment of an approved idea in a vibe-research-loop workspace. Create its Experiments page in Notion and its plan file, prepare and smoke-test the code and configs, and ask the user to approve the plan. Use when the user asks to test an idea, design or plan an experiment, or pick up the next approved idea.
---

# Plan an experiment

An experiment is one controlled comparison: a baseline, a treatment that changes exactly one thing, and ablations when needed. Nothing runs until the user approves its plan.

1. **Idea.** Take the idea the user names, or else the first one in the Ideas view Ready to Implement. Go on only if its Human Approved is checked and its Budget has room; otherwise tell the user and stop. Read its Planned test, its Budget, and its earlier experiments.
2. **Page.** Create the page in Experiments with Name (the experiment in a few words), ID (lowercase English words joined by hyphens, at most 24 characters, unique in Experiments, never renamed), and Idea. Leave Status at Planned and Human Approved unchecked. If the idea's Status is Backlog, set it to Testing.
3. **Code.** Implement the change and one config per run, following the workspace's git rules on branches and worktrees. Check them with a short smoke run, logged in `logs/`, and set Est. Hours from the measured step time × the total steps.
4. **Plan.** Write `docs/plans/<date>-<name>.md`, where `<date>` is the page's Created date and `<name>` its ID: the question, the design, the run table, the configuration, and the exact launch command of each run. Fill sections 1–3 of the page to match it.
5. **Report.** Show the user the page link, the question, the runs with their machines, the estimated compute, and every deviation from the idea's Planned test. Ask them to review sections 1–3 and tick Human Approved; launch nothing before they do.

## Rules

- Work from the root of a vibe-research-loop workspace, the directory with `AGENTS.md` and `docs/AGENTS/`, and follow its rules. Anywhere else, tell the user and stop.
- Use the `ntn` CLI for Notion, and look its usage up live: `ntn --help`, `ntn api ls`, `ntn api <path> -X <method> --spec`. Always run `ntn api ... < /dev/null`, or it waits on stdin.
- Take the IDs of the project page and the databases from `docs/notion/ids.md`. If it is missing, find them by title with `ntn api v1/search`, ask the user which project if several match, and record them there.
- Create a page with `"template": {"type": "default", "timezone": "Asia/Dubai"}`. It comes back blank while Notion applies the template, so wait until the template's blocks appear.
- Fill a page by following the gray instructions of each section: replace every `…` placeholder, and keep the instructions, which later steps still need.
- Read a page before every write and read it back after; merge the user's edits instead of overwriting them.
- Add a figure by uploading its PNG with `ntn files create --filename <name>.png --content-type image/png < <file>`, then inserting it as an image block right above its caption.
- Write times in UAE time: `YYYY-MM-DD HH:MM` in text, and `"time_zone": "Asia/Dubai"` on date properties.
- Never make a Human-In-Loop decision: tick Human Approved, set Confirmed or Overturned, or change a Budget limit the user has set.
