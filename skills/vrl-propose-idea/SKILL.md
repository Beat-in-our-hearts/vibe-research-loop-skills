---
name: vrl-propose-idea
description: Write a testable research hypothesis into a vibe-research-loop project's Ideas database, with its test, stages, and budget, for the user to approve. Use when the user wants to add, draft, or brainstorm ideas, or when a finding or paper suggests one.
---

# Propose an idea

1. **Context.** Read the Research Core with its Direction Log, Ideas, and the idea's sources. If Ideas has the idea already, point the user to it instead.
2. **Facts.** Before writing, settle every fact the idea rests on, read-only: keep the settings the user named, and confirm any you infer; cite a source for each number, and mark what nobody measured as an estimate. Leave checking code and data to the experiment's plan.
3. **Line of thought.** Draft it first, by the template; every section must follow from it.
4. **Page.** Create one page in Ideas per falsifiable hypothesis, with Name (the hypothesis in short), ID, Priority (your proposal), and Related (its source pages).
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
- Before your first `ntn` or `lark-cli` call, read `<kit>/references/pages.md` once per session, and again once its text has left your context, and follow it.
- If `docs/AGENTS/remote.md` exists, follow it, and run no code here.
- Never improvise what the scripts in `<kit>/scripts/` do: `launch_run.sh` starts every long-running command, `resources.sh` reports free GPUs, `gpu_hours.py` counts GPU hours, `vrl_ssh.sh` reaches the remote host. Read a script's `--help` only for an option no skill or rule file gives. If one refuses, tell the user why. Work around it only as a rule file says.
- Never make a Human-In-Loop decision: tick Human Approved, set Confirmed or Overturned, or change a Budget limit the user set.
