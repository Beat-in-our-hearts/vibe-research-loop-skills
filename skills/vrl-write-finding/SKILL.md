---
name: vrl-write-finding
description: Draft a finding in a vibe-research-loop workspace from a verified result, such as an idea's experiments, a benchmark, or a code optimization, with a claim no broader than its evidence, and close the idea it resolves once the user confirms it. Use when an idea's testing ends, a verified result is worth keeping, or the user asks to write up or close a result.
---

# Write a finding

1. **Evidence.** Collect what the claim rests on, with its result files and plotting scripts: the idea's experiments with Outcome Done, or Failed where the failure is the result, never Invalid; else measurements, each against a baseline on the same machine, repeated where numbers vary, with raw results under `runs/findings/<date>-<id>/`.
2. **Page.** Create the page in Findings with Name (the claim in short), ID, and Related (@mentions of the idea and experiments, if any).
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
- Before your first `ntn` or `lark-cli` call, read `<kit>/references/pages.md` once per session, and again once its text has left your context, and follow it.
- If `docs/AGENTS/remote.md` exists, follow it, and run no code here.
- Never improvise what the scripts in `<kit>/scripts/` do: `launch_run.sh` starts every long-running command, `resources.sh` reports free GPUs, `gpu_hours.py` counts GPU hours, `vrl_ssh.sh` reaches the remote host. Read a script's `--help` only for an option no skill or rule file gives. If one refuses, tell the user why. Work around it only as a rule file says.
- Never make a Human-In-Loop decision: tick Human Approved, set Confirmed or Overturned, or change a Budget limit the user set.
