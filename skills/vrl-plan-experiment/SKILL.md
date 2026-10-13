---
name: vrl-plan-experiment
description: Plan the next experiment of an approved idea in a vibe-research-loop workspace. Create its Experiments page in Notion - every run, and steps that each have a condition to go on, a time from measured numbers on the current machine, and a list of writes - and its plan file of launch commands, prepare and smoke-test the code and configs, and ask the user to approve the plan. Use when the user asks to test an idea, design or plan an experiment, or pick up the next approved idea.
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
