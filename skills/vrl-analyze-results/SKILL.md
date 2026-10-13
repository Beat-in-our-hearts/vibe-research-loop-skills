---
name: vrl-analyze-results
description: Analyze a finished experiment in a vibe-research-loop workspace: results, figures, related work, the idea's budget, and the next step. Use when an experiment's runs have finished.
---

# Analyze results

1. **Check.** Go on only if Status is Finish with Outcome Done. For Failed or Invalid, write only the reason in the Criteria met and Next step rows of section 5, and stop.
2. **Numbers.** Compute the results by the template's section 4.
3. **Figures.** Draw the figures by the same section.
4. **Literature.** Run vrl-search-papers in its post-experiment mode.
5. **Page.** Fill section 4, and the Criteria met and Reproduce rows of section 5.
6. **Budget.** Count the idea's budget left, as step 1 of vrl-plan-experiment does.
7. **Next.** If the full test met its success criteria, a Budget limit is reached, or several experiments in a row brought no gain, stop iterating and draft the finding with vrl-write-finding. Otherwise propose in the Next step row the next stage if this one met its Go on when, else this stage again with one change. Rewrite the Review callout for the results, then show the user Table 1, the figures, and the next step.

## Rules

- At the start, run `bash <kit>/scripts/check_update.sh`, where `<kit>` is `<this skill's folder>/../vrl-init-workspace`. Report a newer release once per session with its update command; update only when asked.
- Work from a vibe-research-loop workspace root (with `AGENTS.md` and `docs/AGENTS/`) and follow its rules. Elsewhere, tell the user and stop.
- Before reading or writing a page, read `<kit>/references/pages.md` once per session, and again once its text has left your context, and follow it.
- If `docs/AGENTS/remote.md` exists, follow it, and run no code here.
- Never improvise what the scripts in `<kit>/scripts/` do: `launch_run.sh` starts every long-running command, `resources.sh` reports free GPUs, `gpu_hours.py` counts GPU hours, `vrl_ssh.sh` reaches the remote host. Read a script's `--help` only for an option no skill or rule file gives. If one refuses, tell the user why. Work around it only as a rule file says.
- Never make a Human-In-Loop decision: tick Human Approved, set Confirmed or Overturned, or change a Budget limit the user set.
