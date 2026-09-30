# Experiments template

| | |
|---|---|
| Database | Experiments |
| Template | Create an empty template in the database in the Notion app (New ▾ → + New template), then fill its body with the content below |
| Default properties | Status = Planned · Human Approved = unchecked |

Everything below the line is the template body exactly as it appears in Notion. Text in *italics* is gray in Notion: those lines are instructions. Each starts with who acts and when — Agent (on creation), Agent (during runs), Agent (after runs), Agent (after review), or Human (review) — and says where the content comes from. This file is the source of truth; the rules for syncing it to Notion are in [`../operations.md`](../operations.md).

---

> One page = one controlled experiment: the baseline, the treatment, and any ablations, compared side by side. Sections 1–3 are the plan: runs start only after a human ticks Human Approved. Start by setting a short, unique ID, e.g. `lr-warmup-ablation`; it also names the output folder.

## 1. Objective

*Agent (on creation), then Human (review): state the one question this experiment answers and what you expect to see. Copy the success criteria verbatim from the idea's Planned test; never restate or loosen them.*

| Item | Content |
|---|---|
| Idea | *…* |
| Question | *…* |
| Success criteria | *…* |

## 2. Design and plan

*Agent (on creation): give the plan file's location and name, e.g. `docs/plans/<date>-<name>.md`, and keep the design and plan on this page consistent with it. Exactly one independent variable; every other factor that could affect the result is a controlled variable and stays identical across runs. Record every difference from the idea's Planned test under Deviations, with the reason: approving the plan accepts them, and any change after approval needs a new approval. In the run table, one row per run; the run name is its folder under `runs/<date>-<name>/`, only differences from the baseline are written, and ablation runs are added as needed. Machine is the name in the machine's profile; runs compared with each other use the same GPU type.*

| Item | Content |
|---|---|
| Plan file | *…* |
| Independent variable | *…* |
| Controlled variables | *…* |
| Deviations | *…* |

| Run | Difference from baseline | Machine |
|---|---|---|
| baseline | *—* | *…* |
| treatment | *…* | *…* |

## 3. Configuration

*Agent (on creation): fill from the config snapshots and the launch record, never from memory; write the essentials only, since the snapshot files hold the full config. Model: architecture and initial weights (name plus version or hash). Data: dataset version and splits. Code: repository, branch, entry point, launch command, and commit. Evaluation: metrics, evaluation code version (locked for the whole comparison), and statistics (number of seeds, mean ± std). Files: where inputs, outputs, and logs live; outputs go to `runs/<date>-<name>/<run>/` and logs to `logs/<date>-<name>/<run>.log`, where `<date>` is the Created date and `<name>` is this experiment's ID. For embodied experiments, add an Environment row: simulator or robot, evaluation episodes, and the success definition.*

| Item | Content |
|---|---|
| Model | *…* |
| Data | *…* |
| Code | *…* |
| Evaluation | *…* |
| Files | *…* |

*Agent (on creation): fill from the config snapshots, never by hand. One row per key hyperparameter, adding rows as needed; mark Changed with ✔ only where the value differs from the baseline.*

| Parameter | Value | Baseline | Changed |
|---|---|---|---|
| *…* | *…* | *…* |  |

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
