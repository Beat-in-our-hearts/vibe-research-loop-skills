---
name: vrl-write-finding
description: Draft a finding in a vibe-research-loop workspace - a verified result worth keeping, from an idea's finished experiments or from any other measurement, such as a performance test or a code optimization - with a claim no broader than its evidence and publication-style figures, tables, and analysis on the Findings page in Notion; once the user confirms it, close the idea it resolves, if any, and log any change of direction. Use when an idea's testing ends, when a verified result such as a benchmark or a tuning is worth recording, or when the user asks to write up or close a result.
---

# Write a finding

1. **Evidence.** Collect what the claim rests on, with its result files and plotting scripts: the idea's experiments with Outcome Done, or Failed where the failure is the result, never Invalid; else measurements, each against a baseline on the same machine, repeated where numbers vary, with raw results under `runs/findings/<date>-<id>/`.
2. **Page.** Create the page in Findings with Name (the claim in short, at most 15 words, or 20 characters in Chinese), ID (lowercase hyphenated English, at most 24 characters, unique, never renamed), and Related (@mentions of the idea and experiments, if any).
3. **Body.** Fill the Conclusion callout and sections 1–3 by the template.
4. **Report.** Show the user the page link and its Conclusion, and ask them to review it.
5. **After review.** Once Status reads Confirmed, set the idea it resolves, if any, as below. If it changes direction, add `YYYY-MM-DD — change — @finding` to the Research Core's Direction Log. If it replaces an earlier finding, tell the user, who sets that one to Overturned.

   | Conclusion | Idea's Status |
   |---|---|
   | Supported | Finish, Outcome Supported |
   | Rejected | Finish, Outcome Rejected |
   | Inconclusive | Parked |

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
