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
- Use the `ntn` CLI for Notion, and look its usage up live: `ntn --help`, `ntn api ls`, `ntn api <path> -X <method> --spec`. Always run `ntn api ... < /dev/null`, or it waits on stdin.
- Take the IDs of the project page and the databases from `docs/notion/ids.md`. If it is missing, find them by title with `ntn api v1/search`, ask the user which project if several match, and record them there.
- Create a page with `"template": {"type": "default", "timezone": "<TZ>"}`, where `<TZ>` is the `TZ` in the workspace's `.env`. It comes back blank while Notion applies the template, so wait until the template's blocks appear.
- Fill a page by following the gray instructions of each section: replace every `…` placeholder, and keep the instructions, which later steps still need.
- Read a page before every write and read it back after; merge the user's edits instead of overwriting them.
- Add a figure by uploading its PNG with `ntn files create --filename <name>.png --content-type image/png < <file>`, then inserting it as an image block right above its caption.
- Write times in that time zone: `YYYY-MM-DD HH:MM` in text, and `"time_zone": "<TZ>"` on date properties.
- Never make a Human-In-Loop decision: tick Human Approved, set Confirmed or Overturned, or change a Budget limit the user has set.
