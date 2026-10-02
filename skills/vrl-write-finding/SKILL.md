---
name: vrl-write-finding
description: Draft a finding from an idea's finished experiments in a vibe-research-loop workspace, with a claim no broader than its evidence and publication-style figures, tables, and analysis on the Findings page in Notion; once the user confirms it, close the idea and log any change of direction. Use when an idea's testing ends, or when the user asks to write up or close a result.
---

# Write a finding

A finding reads like the experiments section of a paper. Most findings are negative, and a failure deserves as careful a record as a success. It counts only once the user confirms it.

1. **Evidence.** Collect the idea and the experiments with Outcome Done that the claim rests on, with their result files and plotting scripts. Take every number from them as it is; never recompute it.
2. **Page.** Create the page in Findings with Name (the claim, no broader than the evidence), ID (lowercase English words joined by hyphens, at most 24 characters, unique in Findings, never renamed), and Related (@mentions of the idea and the experiments). Status stays Under Review.
3. **Body.** Fill sections 1–3: at least one table and two figures, saved as PDF and PNG with their scripts under `runs/findings/<date>-<id>/`, each followed by its analysis; then the one-sentence conclusion, supported, rejected, or inconclusive, with its conditions and confidence.
4. **Report.** Show the user the page link, the claim, and the conclusion, and ask them to review it.
5. **After review.** Once the page's Status reads Confirmed, update the idea as below. If the finding calls for a change of direction, add `YYYY-MM-DD — change — @finding` to the Direction Log in the project's Research Core. If it replaces an earlier finding, tell the user, who sets that one to Overturned.

   | Conclusion | Idea |
   |---|---|
   | Supported | Status Finish, Outcome Supported |
   | Rejected | Status Finish, Outcome Rejected |
   | Inconclusive | Status Parked |

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
