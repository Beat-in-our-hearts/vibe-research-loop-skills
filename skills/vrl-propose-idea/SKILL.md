---
name: vrl-propose-idea
description: Write a testable research hypothesis into the project's Ideas database in Notion, for the user to approve - its line of thought, the evidence and assumptions behind it, a planned test listing every group, and stages from the smallest test to the full one, each with its single-GPU and multi-GPU time on the current machine, under proposed budget limits. Use in a vibe-research-loop workspace when the user wants to add, draft, or brainstorm research ideas, or when a finding or paper suggests one.
---

# Propose an idea

1. **Context.** Read the Research Core with its Direction Log, Ideas, and the idea's sources. If Ideas has the idea already, point the user to it instead.
2. **Facts.** Before writing, settle every fact the idea rests on, read-only: keep the settings the user named, and confirm any you infer; cite a source for each number, and mark what nobody measured as an estimate. Leave checking code and data to the experiment's plan.
3. **Line of thought.** Draft it first, by the template; every section must follow from it.
4. **Page.** Create one page in Ideas per falsifiable hypothesis, with Name, ID (lowercase hyphenated English, at most 24 characters, unique, never renamed), Priority (your proposal), and Related (its source pages).
5. **Body.** Fill the line of thought and sections 1–3 by the template.
6. **Self-review.** Read the page as the user would, and revise it until every answer is yes:
   - Can a reader tell how many groups run, what each changes, and why?
   - Is every term and metric plain, and every number traced to its source?
   - Does every stage give what it tests, both times with their basis, and its Go on when?
   - Does every section follow from the line of thought, with no fact repeated?
   - Are the settings the user named unchanged?
7. **Report.** Show the user one table of each idea's link, hypothesis, full-test time, and proposed limits, then the facts you could not settle. Ask them to review the page, set the Budget limits, and tick Human Approved; build nothing before they do.

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
