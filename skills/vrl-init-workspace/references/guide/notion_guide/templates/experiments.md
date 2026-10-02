# Experiments template

| | |
|---|---|
| Database | Experiments |
| Template | Create an empty template in the database in the Notion app (New ▾ → + New template), then fill its body with the content below |
| Default properties | Status = Planned · Human Approved = unchecked |

Everything below the line is the template body exactly as it appears in Notion. Text in *italics* is gray in Notion: those lines are instructions. Each starts with who acts and when — Agent (on creation), Agent (during runs), Agent (after runs), Agent (after review), or Human (review) — and says where the content comes from. This file is the source of truth; the rules for syncing it to Notion are in [`../operations.md`](../operations.md).

---

> One page = one controlled experiment: the baseline, the treatment, and any ablations, compared side by side. Sections 1–3 are the plan: runs start only after a human ticks Human Approved. Write the plan in plain words that a reviewer can follow without the conversation behind it: every run, every number with its source, every choice with its reason. Start by setting a short, unique ID, e.g. `lr-warmup-ablation`; it also names the output folder.

## 1. Objective

*Agent (on creation), then Human (review): state, in plain words, the one question this experiment answers and what you expect to see. Copy the success criteria verbatim from the idea's Planned test; never restate or loosen them. If a deviation changes how a criterion is measured, explain it under Deviations in section 2 and leave the copied text unchanged.*

| Item | Content |
|---|---|
| Idea | *…* |
| Question | *…* |
| Success criteria | *…* |

## 2. Design and plan

*Agent (on creation): give the plan file's location and name, e.g. `docs/plans/<date>-<name>.md`, and keep the design and plan on this page consistent with it. Exactly one independent variable; every other factor that could affect the result is a controlled variable and stays identical across runs. Under Deviations, number each difference from the idea's Planned test, and any time estimate above the idea's, with its reason: approving the plan accepts them, and any change after approval needs a new approval.*

| Item | Content |
|---|---|
| Plan file | *…* |
| Independent variable | *…* |
| Controlled variables | *…* |
| Deviations | *…* |

**Runs.** *Agent (on creation): one row per run, every run the comparison needs, controls included, such as a check that only evaluates an existing checkpoint; add ablation runs as needed. The run name is its folder under `runs/<date>-<name>/`. Setting: for the baseline, what it is; for every other run, only what differs from the baseline. Training: what it trains and for how many steps, or none, with the checkpoint it loads. Evaluation: the benchmark, the number of episodes or samples, and the metrics. Shows: what this run tells us. Machine is the name in the machine's profile; runs compared with each other use the same GPU type. Below the table, say in one sentence why each control is there; then explain, in plain words, each design choice the comparison depends on: what was chosen, why, and the alternative considered.*

| Run | Setting | Training | Evaluation | Shows | Machine |
|---|---|---|---|---|---|
| baseline | *…* | *…* | *…* | *…* | *…* |
| treatment | *…* | *…* | *…* | *…* | *…* |

**Data per sample.** *Agent (on creation): only when a training sample holds more than one input and its target, as in sequence models or a model with several branches; otherwise delete this part. One row per component that reads the data, such as the policy and a world-model branch: the inputs and targets it takes, by position relative to the current step t, e.g. frames t−1 and t, or actions a_t … a_t+14 in groups of five. Read them from the data-loading code, not from config names.*

| Component | Inputs | Targets |
|---|---|---|
| *…* | *…* | *…* |

**Time estimate.** *Agent (on creation): start with the current machine from `docs/AGENTS/machine.md`: its GPUs, CPU cores, and memory. Then one row per piece of work in the Detail plan: setup, such as writing the code, building or rebuilding an environment, and converting data; the smoke run; each run's training and evaluation, re-evaluating a reused baseline in a new environment included; and any diagnostics. In Basis, give the measured number, its source, and the hardware it was measured on, then how it scales to this machine, adding what the treatment costs beyond the baseline, such as extra data loading or compute per sample; mark each number measured or estimated, and name what limits the speed, such as the GPU, CPU data loading or video decoding, or the simulator. End with the total task hours, and the wall-clock hours with the planned concurrency, e.g. three runs sharing one GPU. After the smoke run, re-estimate from its measured step times and say what changed; a human confirms the new estimate when approving the plan. Set Est. Hours to the wall-clock hours from the first run to the end of the plan.*

| Item | Basis | Estimate |
|---|---|---|
| *…* | *…* | *…* |

**Detail plan.** *Agent (on creation): the steps in the order they run, one row per step. What it does: in plain words. Output: what it produces. Go on when: the condition the next step needs; if it fails, stop and report to a human. Time: from the time estimate above. Writes: every file or folder the step creates or changes, and where, such as the worktree, an environment, data, and run and log folders. The first steps prepare the code, the environments, and the data, and end with the smoke run; they are done while planning. The steps after them wait for Human Approved, which also approves the writes they list.*

| Step | What it does | Output | Go on when | Time | Writes |
|---|---|---|---|---|---|
| *…* | *…* | *…* | *…* | *…* | *…* |

## 3. Configuration

*Agent (on creation): fill from the config snapshots and the launch record, never from memory; write the essentials only, since the snapshot files hold the full config. Before the smoke run, write the planned values and say that they are planned; replace them from the snapshots once it passes. Model: architecture and initial weights (name plus version or hash). Data: dataset version and splits. Code: repository, branch, base commit, worktree path, entry point, launch command, and commit. Evaluation: metrics, evaluation code version (locked for the whole comparison), and statistics (number of seeds, mean ± std). Files: where inputs, outputs, and logs live; outputs go to `runs/<date>-<name>/<run>/` and logs to `logs/<date>-<name>/<run>.log`, where `<date>` is the Created date and `<name>` is this experiment's ID. For embodied experiments, add an Environment row: simulator or robot, evaluation episodes, and the success definition.*

| Item | Content |
|---|---|
| Model | *…* |
| Data | *…* |
| Code | *…* |
| Evaluation | *…* |
| Files | *…* |

**Code changes.** *Agent (on creation): one row per file the experiment adds or changes, with its role in plain words and the code it was adapted from (repository, commit, and file), or — if it was written from scratch.*

| File | Role | Reference source |
|---|---|---|
| *…* | *…* | *…* |

**Hyperparameters.** *Agent (on creation): one row per key hyperparameter, from the config snapshots, adding rows as needed; keep each name as the config writes it. In Meaning, say in plain words what the value does, as the code that reads it uses it rather than as its name suggests. Mark Changed with ✔ only where the value differs from the baseline.*

| Parameter | Meaning | Value | Baseline | Changed |
|---|---|---|---|---|
| *…* | *…* | *…* | *…* |  |

## 4. Logs

*Agent (during runs): update at every checkpoint or evaluation. Overwrite the status row; regenerate the training-loss and primary-validation-metric curves from metrics.csv, one line per run, and replace the old figures below; add an anomaly row for every incident (divergence, NaN, plateau, restart). If the ETA drifts more than 20% from Est. Hours, update Est. Hours. Write every time in the project's time zone.*

| Progress | Latest metrics | Updated |
|---|---|---|
| *…* | *…* | *…* |

**Curves**

| Step | Anomaly | Action |
|---|---|---|
| *—* | *none* | *—* |

## 5. Results and analysis

*Agent (after runs), then Human (review): compute from the final metrics files; report mean ± std over seeds and the difference from the baseline, rounded consistently; investigate suspiciously good results before reporting them. Show the results in figures and tables, never in text alone: Table 1 plus at least one figure, such as the primary metric per run with error bars, and more for secondary metrics or ablations. Save each figure as PDF and PNG, with the script that draws it, under `runs/<date>-<name>/figures/`. In the analysis, one row per observation, including surprises and failures; the evidence is a figure, a table, a run, or a paper from the post-experiment search.*

*Agent (after runs): publication style. Figures: drawn by a script from the result files, never by hand; axes with quantity and unit; mean ± std as error bars or shaded bands; one colorblind-safe color per run across all figures; no 3D, pie charts, or titles inside the plot. Tables: units and ↑ or ↓ in the header; the best result in bold, the second best underlined; the same decimals within a column. Captions: numbered, stating what is shown, the number of seeds, and the takeaway; below a figure, above a table.*

**Table 1.** *…*

| Run | Primary metric | vs baseline |
|---|---|---|
| baseline | *…* | *—* |
| treatment | *…* | *…* |

**Figure 1.** *…*

| Observation | Explanation | Evidence |
|---|---|---|
| *…* | *…* | *…* |

*Agent (after runs): mark each check ✔ or ✘, with the reason for every ✘. Human (review): the code-review check passes only after a human has reviewed the AI-generated code.*

| Check | Pass |
|---|---|
| Evaluation code and data version match the baseline | *✔ / ✘* |
| All runs finished as the approved plan says | *✔ / ✘* |
| AI-generated code reviewed by a human | *✔ / ✘* |

## 6. Conclusion

*Agent (after runs), then Human (review): answer whether the success criteria were met with yes or no and the deciding numbers; if they were, draft a finding page that @mentions this experiment in its Related property. Update Used in the idea's Budget, and stop once a limit or a stop condition is reached. For reproduction, write one command that reruns the whole comparison from a clean checkout.*

| Item | Content |
|---|---|
| Criteria met | *…* |
| Next step | *…* |
| Reproduce | *…* |
