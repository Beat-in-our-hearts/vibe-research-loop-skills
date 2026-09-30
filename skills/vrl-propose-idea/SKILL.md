---
name: vrl-propose-idea
description: Write a testable research hypothesis into the project's Ideas database in Notion, with its motivation, feasibility, planned test, and proposed budget, for the user to approve. Use in a vibe-research-loop workspace when the user wants to add, draft, or brainstorm research ideas, or when a finding or paper suggests one.
---

# Propose an idea

An idea is one falsifiable hypothesis, written down so that the user can judge its feasibility before anything is built.

1. **Context.** Read the project's Research Core, its Direction Log included, then the Ideas database and the sources the idea comes from: findings, papers, or the user's own words. If an idea is already in Ideas, point the user to it instead of adding it again.
2. **Page.** Create one page per idea in Ideas, and leave Status at Backlog and Human Approved unchecked:

   | Property | Value |
   |---|---|
   | Name | The hypothesis, stated so that it can be falsified |
   | ID | Lowercase English words joined by hyphens, at most 24 characters, unique in Ideas (add `-2`, `-3` if taken); never renamed |
   | Priority | Your proposal: High, Medium, or Low |
   | Related | @mentions of the finding and paper pages it comes from |

3. **Body.** Fill sections 1–4. Write the success criteria in Planned test as a pass/fail threshold, fixed before anything runs; the Budget limits are only your proposal.
4. **Report.** Show the user one table with each idea's page link, hypothesis, success criteria, and proposed budget. Ask them to review it, set the Budget limits, and tick Human Approved; build nothing before they do.

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
