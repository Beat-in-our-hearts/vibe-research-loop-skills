---
name: vrl-plan-experiment
description: Plan the next experiment of an approved idea in a vibe-research-loop workspace: its Experiments page, plan file, and smoke runs, for the user to approve. Use when the user asks to test an idea, design or plan an experiment, or pick up the next approved idea.
---

# Plan an experiment

1. **Idea.** Take the idea the user names, or else the highest-Priority approved idea in Backlog. If its Human Approved is unchecked, tell the user and stop. Read it and its earlier experiments, and decide:
   - Stage: the one the latest experiment's Conclusion proposes, or else the earliest not yet run whose previous stage's Go on when holds.
   - Budget left: each limit minus what the idea's experiments used: their number, the days to the Deadline, and single-GPU hours, from each finished experiment's GPU hours row plus `gpu_hours.py` on a running one's log folder, on each of its machines. If it exits 3, tell the user and stop.
   - Plan the whole stage if it fits the budget left, else the part that fits; if no useful part fits, tell the user and stop.
2. **Facts.** Read-only: check the code, environments, checkpoints, and data the plan needs on the current machine (`docs/AGENTS/machine.md`); what is missing is setup work. Read the code the plan builds on, and trace one training batch from the data loader to the total loss.
3. **Page.** Create the page in Experiments with Name (at most 15 words, or 20 characters in Chinese), ID (lowercase English words joined by hyphens, at most 24 characters, unique, never renamed), and Idea. If the idea's Status is Backlog, set it to Testing.
4. **Draft.** Fill the Review callout, then sections 1 and 2, by the template.
5. **Setup.** Do the setup steps of section 1 in order: the code and one config per run, by the git rules; the environments and data; the plan file, as in step 6; last, a short smoke run of each block's command, unchanged but for overrides that shorten it: `launch_run.sh --purpose '<date>-<name> / smoke <run>' --log logs/<date>-<name>/smoke-<run>.log --outputs tmp/smoke/<date>-<name>/<run>/ --code <checkout> --gpus <free ids from resources.sh> --machine <Name> --tmux <session> --wait <seconds> -- '<command>'`.
   - `launch_run.sh --pin <checkout>` must print the same before and after each smoke run. If not, send what the run wrote into the checkout to `$VRL_OUTPUTS`, or ignore it in the committed `.gitignore`, and smoke-run again.
   - In remote mode, first show the user the page link and every write these steps make on the remote host, syncs included, and make only those they approve. Keep `--wait` 20 seconds below the command limit.
6. **Update.** Update sections 1 and 2 from the smoke run, by the template, and the plan file `docs/plans/<date>-<name>.md` (the page's Created date and ID): a link to the page, then for each run its config file and one fenced block with the info string `bash run=<run> gpus=<count> env=<environment>`, holding its exact launch command. Run names hold only letters, digits, `.`, `-`, and `_`; a seed run as its own process is its own run, such as `baseline-s1`. Each command enters its checkout and activates its environment itself, writes to `$VRL_OUTPUTS`, and holds no token: a tool that needs a login uses the user's own.
7. **Self-review.** Read the page as the user would; revise it until every answer is yes:
   - Could a reader who missed this conversation tell what each run does and why each control is there, and follow one batch from the data to the total loss?
   - Is every term and number explained in plain words and traced to its source, and do the times fit the current machine?
   - Does each section hold what its template asks, with each fact stated once?
   - Does the plan file hold one block per run, each the command its smoke run ran, and did each smoke run leave its pin unchanged?
8. **Report.** Pin each block: add to its info string what `launch_run.sh --pin <checkout>` prints, or in remote mode the checkout's line from `vrl_ssh.sh sync`. Run `chmod go-w` on the plan file and record its SHA-256 (`sha256sum` or `shasum -a 256`) after its name in the Code row of section 2; in remote mode, instead commit the plan file, sync `.`, and record the hash the sync prints. Pin and record again whenever the plan file, the code, or a config changes before approval. Rewrite the Review callout, show the user the page link and its text, and ask them to review sections 1 and 2, by coloring text or in words, and to tick Human Approved; launch nothing before they do.

## Rules

- At the start, run `bash <kit>/scripts/check_update.sh`, where `<kit>` is `<this skill's folder>/../vrl-init-workspace`. Report a newer release once per session with its update command; update only when asked.
- Work from a vibe-research-loop workspace root (with `AGENTS.md` and `docs/AGENTS/`) and follow its rules. Elsewhere, tell the user and stop.
- Before reading or writing a page, read `<kit>/references/pages.md` once per session, and again once its text has left your context, and follow it.
- If `docs/AGENTS/remote.md` exists, follow it, and run no code here.
- Never improvise what the scripts in `<kit>/scripts/` do: `launch_run.sh` starts every long-running command, `resources.sh` reports free GPUs, `gpu_hours.py` counts GPU hours, `vrl_ssh.sh` reaches the remote host. Read a script's `--help` only for an option no skill or rule file gives. If one refuses, tell the user why. Work around it only as a rule file says.
- Never make a Human-In-Loop decision: tick Human Approved, set Confirmed or Overturned, or change a Budget limit the user set.
