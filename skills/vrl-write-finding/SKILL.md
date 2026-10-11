---
name: vrl-write-finding
description: Draft a finding in a vibe-research-loop workspace - a verified result worth keeping, from an idea's finished experiments or from any other measurement, such as a performance test or a code optimization - with a claim no broader than its evidence and publication-style figures, tables, and analysis on the Findings page in Notion; once the user confirms it, close the idea it resolves, if any, and log any change of direction. Use when an idea's testing ends, when a verified result such as a benchmark or a tuning is worth recording, or when the user asks to write up or close a result.
---

# Write a finding

A finding records a verified result: what an idea's experiments showed, or a result with no idea or experiment behind it, such as a performance test or a code optimization. It counts only once the user confirms it.

1. **Evidence.** Collect what the claim rests on, with its result files and plotting scripts. Take every number from them as it is, p-values included, never recomputed; compute here only a test that no experiment ran, such as one on measurements, by a script saved with the figures.
   - From the research loop: the idea and its experiments whose results can be trusted: Outcome Done, or Failed where the failure is itself the result, such as running out of memory; never Outcome Invalid.
   - Otherwise: the measurements, such as a benchmark or a profile, each with the commit, the machine, and the command that produced it, against a baseline measured the same way on the same machine, repeated where its numbers vary. Keep their raw results and logs under `runs/findings/<date>-<id>/`.
2. **Page.** Create the page in Findings with Name (the claim in short, no broader than the evidence, at most 15 words, or 20 characters in Chinese; the Conclusion callout states it in full), ID (lowercase English words joined by hyphens, at most 24 characters, unique in Findings, never renamed), and Related (@mentions of the idea and the experiments, if any). Status stays Under Review.
3. **Body.** Fill the Conclusion callout and sections 1–3 by the template's instructions, like the experiments section of a paper.
4. **Report.** Show the user the page link, the claim, and the conclusion, and ask them to review it.
5. **After review.** Once Status reads Confirmed, update the idea it resolves, if any, as below. If the finding calls for a change of direction, add `YYYY-MM-DD — change — @finding` to the Direction Log in the project's Research Core. If it replaces an earlier finding, tell the user, who sets that one to Overturned.

   | Conclusion | Idea |
   |---|---|
   | Supported | Status Finish, Outcome Supported |
   | Rejected | Status Finish, Outcome Rejected |
   | Inconclusive | Status Parked |

## Rules

- At the start, run `bash <this skill's folder>/../vrl-init-workspace/scripts/check_update.sh`. If it reports a newer release, tell the user once per session, with its update command, and go on; update the skills only when asked.
- Work from the root of a vibe-research-loop workspace, which holds `AGENTS.md` and `docs/AGENTS/`, and follow its rules; elsewhere, tell the user and stop.
- If `docs/AGENTS/remote.md` exists, follow it: edit code, plans, and tests here and send them only as commits with `vrl_ssh.sh sync`, recording the pins and plan hashes it prints. Read logs and results with `vrl_ssh.sh read`, `run`, or `launch_run.sh --status`, and bring back with `vrl_ssh.sh fetch` only a figure to upload or a lock file to commit. Write plotting and analysis scripts on the remote host. Run no code here, not even a quick check.
- Never improvise what the scripts in `<this skill's folder>/../vrl-init-workspace/scripts/` do: `launch_run.sh` starts every long-running command, `resources.sh` reports resources and free GPUs, `gpu_hours.py` counts GPU hours, `vrl_ssh.sh` reaches the remote host. Read a script's `--help` only when you need an option that this skill or a rule file does not give. If one refuses or cannot count something (exit code 3), tell the user why; work around it by hand only where a rule file says how.
- If `docs/AGENTS/feishu.md` exists, the memory store is Feishu, not Notion: follow that file instead wherever this skill names Notion, `ntn`, a page, a database, or a property, and wherever a rule below makes sense only in Notion.
- Use the `ntn` CLI for Notion and look up its usage live: `ntn --help`, `ntn api ls`, `ntn api <path> -X <method> --spec`. Always run `ntn api ... < /dev/null`, or it waits on stdin.
- Take the IDs of the project page and databases from `docs/notion/ids.md`. If it is missing, find them by exact title with `ntn api v1/search`, reading every page of results, ask the user which project if several match, and record them there with the columns Object, Title in Notion, Page ID, Database ID, and Data source ID.
- Create each new page from its database's template file, never from a Notion template: `ideas.md`, `experiments.md`, `findings.md`, or `papers.md` in `<this skill's folder>/../vrl-init-workspace/references/guide/notion_guide/templates/`. Set the default properties from the file's header, and write each part of the body only when you fill it, at its place, by its italic instructions. A page holds only content: no instruction text, no `…` placeholder. Whenever an Ideas, Experiments, or Findings page goes to the user for review, rewrite its opening callout in place as its template says.
- A page whose headings differ from its template's comes from an older template: find each section by name, not number, and tell the user before writing to it.
- Write pages, template headings, labels, and table headers included, in the language the workspace's language rules set for them, or else the reply language, with property names and select and status options exactly as the database defines them.
- Write sentences a colleague can follow without decoding. State each fact once, where it belongs, and elsewhere point to its page and section, unless a template asks to repeat it. Give a reason only for a deviation, a control, an estimate, a ✘, or where a template asks. Common abbreviations such as w/o, ckpt, or lr are fine, but never string abbreviations and symbols together without words. Spell out at first use only those uncommon in the field or made up for this project.
- Keep each table cell to a value, a phrase, or one sentence. Put a cell's several points on separate lines within it (a `\n` in its rich text, since a cell cannot hold list blocks), starting with `1.`, `2.` when order matters and `•` otherwise. When a cell would run past three lines, move its content into a list right below the table, with a short pointer in the cell.
- The user marks text for review by coloring it or its background red, orange, or purple; other colors are not marks. Read a page before every write, with the colors of all its text, table cells included (each rich-text item's `annotations.color` and the block's `color`), and read it back after; merge the user's edits instead of overwriting them. Answer each mark, telling the user what you change and why. Red means wrong: fix it. Orange means not understood: explain it in plainer words and rewrite it so it needs no explanation. Purple means not acceptable: propose an alternative, and keep the text and mark until the user decides. Write rewritten text without the mark; leave unresolved marks in place.
- Add a figure by uploading its PNG with `ntn files create --filename <name>.png --content-type image/png < <file>` and inserting it as an image block right above its caption.
- Write times in the `TZ` of the workspace's `.env`: `YYYY-MM-DD HH:MM` in text, and `"time_zone": "<TZ>"` on date properties.
- Never make a Human-In-Loop decision: tick Human Approved, set Confirmed or Overturned, or change a Budget limit the user has set.
