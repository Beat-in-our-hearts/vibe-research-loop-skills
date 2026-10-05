---
name: vrl-search-papers
description: Search arXiv, Semantic Scholar, and Hugging Face Daily Papers for work relevant to a vibe-research-loop project, and add at most three papers that pass the Literature Library's admission rules to its Papers database in Notion, for the user to approve. Use for the daily literature search, after an experiment finishes, or when the user asks to find papers.
---

# Search papers

The Literature Library is shared by every project and strictly curated: better no paper than a poor one.

| Mode | Look for | The analysis goes to |
|---|---|---|
| Daily | Work on the research question, scope, and current direction in the project's Research Core | The new papers' own pages |
| Post-experiment | Work that explains, supports, or contradicts a finished experiment's result | That experiment's Results and analysis |
| On request | What the user asks for | The new papers' own pages |

1. **Search.** Query the sources below, then read each candidate's abstract, and the full text of any you might add.

   | Source | Endpoint |
   |---|---|
   | arXiv | `https://export.arxiv.org/api/query?search_query=...` |
   | Semantic Scholar | `https://api.semanticscholar.org/graph/v1/paper/search?query=...&fields=title,abstract,year,externalIds,url`; without an API key it often answers 429, so wait and retry once |
   | Hugging Face Daily Papers | `https://huggingface.co/api/daily_papers?date=YYYY-MM-DD` |

2. **Admit.** Add a paper only if all of these hold:
   - it is directly relevant to an active research question;
   - it offers a method, result, or evidence you would use or must compare against;
   - Papers does not have it yet: check its Link and its title;
   - no more than three papers are added in this run; zero is a valid result.
3. **Page.** Create each page in Papers with Title, ID (usually the method name and year, e.g. `openvla-2024`; unique, never renamed), Link (arXiv, DOI, or publisher page), Keywords (reuse one before adding one), Corresponding Authors, and Affiliations. Leave Human Approved unchecked. Fill sections 1–6 from what you actually read.
4. **Report.** List the papers added, each with one line on why it passed, and the close candidates you left out, with why. Tell the user the new papers wait in the Review Queue view for Human Approved.

## Rules

- Work from the root of a vibe-research-loop workspace, the directory with `AGENTS.md` and `docs/AGENTS/`, and follow its rules. Anywhere else, tell the user and stop.
- If `docs/AGENTS/remote.md` exists, this machine computes on a remote host over SSH, and that file says where each path lives and where each command runs: every workspace path but `AGENTS.md` and `docs/AGENTS/` is in the remote workspace, read and written locally through the mount; everything but file edits, `ntn`, and web requests runs on the remote host through the SSH master. Never fall back to the local machine.
- Use the `ntn` CLI for Notion, and look up its usage live: `ntn --help`, `ntn api ls`, `ntn api <path> -X <method> --spec`. Always run `ntn api ... < /dev/null`, or it waits on stdin.
- Take the IDs of the project page and the databases from `docs/notion/ids.md`. If it is missing, find them with `ntn api v1/search` by exact title, reading every page of results; ask the user which project if several match, and record the IDs there in a table with the columns Object, Title in Notion, Page ID, Database ID, and Data source ID.
- Create a page with `"template": {"type": "default", "timezone": "<TZ>"}`, where `<TZ>` is the `TZ` in the workspace's `.env`. It comes back blank while Notion applies the template: wait until the template's blocks appear.
- Fill each section by its gray instructions; once it is filled, delete its gray instruction lines and any `…` placeholder left in it. Delete the template's opening quote when you first fill the page. A section that a later step fills keeps its instructions and placeholders until that step fills it. To see the instructions of a cleaned section, read the database's template: `ntn api v1/data_sources/<data source ID>/templates`, then that template page's blocks.
- Read a page before every write and read it back after; merge the user's edits instead of overwriting them.
- The user reviews a page by coloring its text or the text's background: red marks what they think is wrong, orange what they did not understand, purple what they cannot accept; other colors are not marks. Before every write to a page, read the colors of all its text, table cells included (`annotations.color` of each rich-text item, and the block's `color`), and answer each mark, telling the user what you change and why: fix red text; explain orange text in plainer words and rewrite it so that it no longer needs the explanation; for purple text, propose an alternative and leave the text and its mark in place until the user decides. Write rewritten text without the mark, and leave every mark you have not resolved in place.
- Add a figure by uploading its PNG with `ntn files create --filename <name>.png --content-type image/png < <file>`, then inserting it as an image block right above its caption.
- Write times in that time zone: `YYYY-MM-DD HH:MM` in text, and `"time_zone": "<TZ>"` on date properties.
- Never make a Human-In-Loop decision: tick Human Approved, set Confirmed or Overturned, or change a Budget limit the user has set.
