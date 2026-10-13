---
name: vrl-search-papers
description: Search arXiv, Semantic Scholar, and Hugging Face Daily Papers for a vibe-research-loop project, and add at most three papers that pass its admission rules to the Papers database. Use for the daily literature search, after an experiment finishes, or when the user asks to find papers.
---

# Search papers

1. **Search.** Query arXiv, Semantic Scholar (with `fields=title,abstract,year,externalIds,url`), and Hugging Face Daily Papers (`huggingface.co/api/daily_papers?date=YYYY-MM-DD`) for the user's request, or else the Research Core's question, scope, and current direction; in post-experiment mode, for work that explains, supports, or contradicts the experiment's result, analyzed in its Results. Read each candidate's abstract, and the full text before adding it.
2. **Admit.** Add at most three papers, each directly relevant to an active research question, offering a method, result, or evidence you would use or must compare against, and not in Papers yet by Link or title; better none than a poor one.
3. **Page.** Create each in Papers with all its properties, reusing a Keyword before adding one, and fill sections 1–6 by the template.
4. **Report.** List for the user the papers added and the close candidates left out, each with why; the added ones wait in the Review Queue for Human Approved.

## Rules

- At the start, run `bash <kit>/scripts/check_update.sh`, where `<kit>` is `<this skill's folder>/../vrl-init-workspace`. Report a newer release once per session with its update command; update only when asked.
- Work from a vibe-research-loop workspace root (with `AGENTS.md` and `docs/AGENTS/`) and follow its rules. Elsewhere, tell the user and stop.
- Before your first `ntn` or `lark-cli` call, read `<kit>/references/pages.md` once per session, and again once its text has left your context, and follow it.
- If `docs/AGENTS/remote.md` exists, follow it, and run no code here.
- Never improvise what the scripts in `<kit>/scripts/` do: `launch_run.sh` starts every long-running command, `resources.sh` reports free GPUs, `gpu_hours.py` counts GPU hours, `vrl_ssh.sh` reaches the remote host. Read a script's `--help` only for an option no skill or rule file gives. If one refuses, tell the user why. Work around it only as a rule file says.
- Never make a Human-In-Loop decision: tick Human Approved, set Confirmed or Overturned, or change a Budget limit the user set.
