---
name: vrl-search-papers
description: Search arXiv, Semantic Scholar, and Hugging Face Daily Papers for work relevant to a vibe-research-loop project, and add at most three papers that pass the Literature Library's admission rules to its Papers database in Notion, for the user to approve. Use for the daily literature search, after an experiment finishes, or when the user asks to find papers.
---

# Search papers

The Literature Library is shared by every project and strictly curated.

| Mode | Look for | The analysis goes to |
|---|---|---|
| Daily | Work on the research question, scope, and current direction in the project's Research Core | The new papers' own pages |
| Post-experiment | Work that explains, supports, or contradicts a finished experiment's result | That experiment's Results |
| On request | What the user asks for | The new papers' own pages |

1. **Search.** Query arXiv (`https://export.arxiv.org/api/query?search_query=...`), Semantic Scholar (`https://api.semanticscholar.org/graph/v1/paper/search?query=...&fields=title,abstract,year,externalIds,url`; on a 429, wait and retry once), and Hugging Face Daily Papers (`https://huggingface.co/api/daily_papers?date=YYYY-MM-DD`). Read each candidate's abstract, and the full text of any you might add.
2. **Admit.** Add a paper only if it is directly relevant to an active research question, offers a method, result, or evidence you would use or must compare against, and is not in Papers yet, by its Link and its title. Add at most three papers in this run; zero is a valid result.
3. **Page.** Create each page in Papers with Title, ID (usually the method name and year; unique, never renamed), Link (arXiv, DOI, or publisher page), Keywords (reuse one before adding one), Corresponding Authors, and Affiliations. Fill sections 1–6 from what you actually read.
4. **Report.** List the papers added, each with one line on why it passed, and the close candidates left out, with why. Tell the user the new papers wait in the Review Queue view for Human Approved.

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
