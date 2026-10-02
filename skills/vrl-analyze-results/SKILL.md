---
name: vrl-analyze-results
description: Analyze a finished experiment in a vibe-research-loop workspace. Compute its results from the metrics files, draw publication-style figures and tables, search for related work, fill the results and conclusion of its Notion page, update the idea's budget, and decide the next step. Use when an experiment's runs have finished.
---

# Analyze results

1. **Check.** Read the Experiments page: Status must be Finish with Outcome Done. For Failed or Invalid, write only the reason in the checks table and Next step, and stop.
2. **Numbers.** Compute every result from the final metrics files, never from logs or memory: mean ± std over seeds, and the difference from the baseline. Investigate a result that looks too good before you report it.
3. **Figures.** Draw each figure with a script from the result files, and save it as PDF and PNG, with its script, under `runs/<date>-<name>/figures/`.
4. **Literature.** Search for work that explains, supports, or contradicts the result, in the post-experiment mode of vrl-search-papers, and cite it as evidence.
5. **Page.** Fill sections 5 and 6: Table 1, the figures, one observation per row, and the checks, each ✔ or ✘ with the reason for every ✘. The code-review check passes only after the user has reviewed the code. In section 6, answer whether the success criteria were met, with the deciding numbers, and write the Reproduce command.
6. **Budget.** Update Used in the idea's Budget.
7. **Next.** If the success criteria were met, a Budget limit is reached, or several experiments in a row brought no improvement, stop iterating on the idea and draft its finding with vrl-write-finding. Otherwise propose the next experiment. Report Table 1, the figures, and the next step to the user.

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
