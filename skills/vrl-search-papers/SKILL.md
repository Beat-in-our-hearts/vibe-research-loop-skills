---
name: vrl-search-papers
description: Search arXiv, Semantic Scholar, and Hugging Face Daily Papers for work relevant to a vibe-research-loop project, and add at most three papers that pass the Literature Library's admission rules to its Papers database in Notion, for the user to approve. Use for the daily literature search, after an experiment finishes, or when the user asks to find papers.
---

# Search papers

1. **Search.** Query arXiv, Semantic Scholar (with `fields=title,abstract,year,externalIds,url`), and Hugging Face Daily Papers (`huggingface.co/api/daily_papers?date=YYYY-MM-DD`) for the user's request, or else the Research Core's question, scope, and current direction; in post-experiment mode, for work that explains, supports, or contradicts the experiment's result, analyzed in its Results. Read each candidate's abstract, and the full text before adding it.
2. **Admit.** Add at most three papers, each directly relevant to an active research question, offering a method, result, or evidence you would use or must compare against, and not in Papers yet by Link or title.
3. **Page.** Create each in Papers with all its properties, reusing a Keyword before adding one, and fill sections 1–6 by the template.
4. **Report.** List for the user the papers added and the close candidates left out, each with why; the added ones wait in the Review Queue for Human Approved.

## Rules

- At the start, run `bash <kit>/scripts/check_update.sh`, where `<kit>` is `<this skill's folder>/../vrl-init-workspace`. Report a newer release once per session with its update command; update only when asked.
- Work from a vibe-research-loop workspace root (with `AGENTS.md` and `docs/AGENTS/`) and follow its rules. Elsewhere, tell the user and stop.
- If `docs/AGENTS/remote.md` exists, follow it. Edit here, send only commits with `vrl_ssh.sh sync`, and take pins and plan hashes from its output. Read results there; fetch only figures or lock files. Run no code here.
- Never improvise what the scripts in `<kit>/scripts/` do: `launch_run.sh` starts every long-running command, `resources.sh` reports free GPUs, `gpu_hours.py` counts GPU hours, `vrl_ssh.sh` reaches the remote host. Read a script's `--help` only for an option no skill or rule file gives. If one refuses, tell the user why. Work around it only as a rule file says.
- If `docs/AGENTS/feishu.md` exists, follow it instead wherever these instructions concern Notion.
- For Notion, use the `ntn` CLI; see `ntn --help`, `ntn api ls`, `ntn api <path> -X <method> --spec`. Always run `ntn api ... < /dev/null`.
- Take project page and database IDs from `docs/notion/ids.md`. If missing, find them by exact title with `ntn api v1/search`, reading all result pages. Ask the user if several projects match. Record them there in columns Object, Title in Notion, Page ID, Database ID, Data source ID.
- Create each page from its database's template file in `<kit>/references/guide/notion_guide/templates/`, not a Notion template, with its header's default properties. Write each part only when you fill it, at its place, by its italic instructions. Leave no instruction text or `…`. When a page goes to review, rewrite its opening callout in place as its template says.
- If headings differ from the template's, find sections by name and tell the user before writing.
- Write pages, headings and labels included, in the language the workspace rules set, else the reply language. Use property and option names exactly as defined.
- State each fact once, where it belongs, and elsewhere point to it unless a template asks otherwise. Give reasons only for deviations, controls, estimates, and ✘, or where a template asks. Spell out at first use abbreviations uncommon in the field or made up here. Never chain abbreviations and symbols without words.
- Keep a table cell to a value, phrase, or sentence. Put several points on separate lines (`\n` in rich text), starting `1.`, `2.` if ordered, else `•`. Move content over three lines to a list below the table, leaving a pointer.
- Read a page before and after every write; merge the user's edits. Read every color, table cells included: each rich-text item's `annotations.color` and the block's `color`. Red, orange, or purple text or background is a review mark. Answer each, telling the user what you change and why. Red (wrong): fix it. Orange (unclear): explain it plainly, and rewrite it to need no explanation. Purple (not acceptable): propose an alternative; keep the text and mark until the user decides. Rewritten text loses its mark. Unresolved marks stay.
- Upload a figure's PNG with `ntn files create --filename <name>.png --content-type image/png < <file>` and place it as an image block right above its caption.
- Write times in the `TZ` of `.env`: `YYYY-MM-DD HH:MM` in text, `"time_zone": "<TZ>"` on date properties.
- Never make a Human-In-Loop decision: tick Human Approved, set Confirmed or Overturned, or change a Budget limit the user set.
