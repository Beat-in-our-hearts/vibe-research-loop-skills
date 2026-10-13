# Experiments template

| | |
|---|---|
| Database | Experiments |
| Default properties | Status = Planned · Human Approved = unchecked |
| Callout | 📋 icon, gray background |

---

> One page = one controlled experiment: the baseline, the treatment, and any ablations, compared side by side, for one stage of the idea, or the part of it that fits the budget left. Sections 1 and 2 are the plan, for approval; sections 3 to 5 are written during and after the runs. The idea holds the hypothesis, the groups, and the success criteria: refer to them, quote only the criteria under Decided by, and never loosen them.

<aside>
📋 **Review**

*Rewrite this callout each time the page goes to the user, in at most five lines. Decide: the action, then where to look. For the plan: "Approve stage N: tick Human Approved", then what to check: the deviations by number, the data flow, and every write outside the worktree, the run folders, and the logs, which the approval also allows; and that ticking approves the launch commands in the plan file, SHA-256 `<its first 12 digits>`, so that any later change to it, the code, or a config needs a new approval. For the results: review the code under Code changes in section 2 and say so, since the code-review check in section 4 passes only then; then the next step in section 5. Key numbers: for the plan, the runs and seeds, the total wall-clock time against the budget left, and whether it was measured or estimated; for the results, whether the criteria under Decided by were met, with the deciding number. Changed: what is new since the user's last review, or "first review".*

- **Decide:** *…*
- **Key numbers:** *…*
- **Changed:** *…*
</aside>

## 1. Plan

*Stage: the idea's stage this experiment runs. Decided by: the criteria that decide this experiment, quoted word for word: the idea's success criteria for the full test, or the stage's Go on when for an earlier stage.*

| Item | Content |
|---|---|
| Stage | *…* |
| Decided by | *…* |

**Runs.** *One row per run, controls such as a check that only evaluates an existing checkpoint included. Run: its folder under `runs/<date>-<name>/`. Group: the idea's group it runs, or "new" for a run the idea lacks, which is then a deviation. Setting: for the baseline, what it is; for every other run, its value of the one thing that changes. Training: what it trains and for how many steps, or none, with the checkpoint it loads. Machine: the name in the machine's profile; runs compared with each other use the same GPU type.*

| Run | Group | Setting | Training | Seeds | Machine |
|---|---|---|---|---|---|
| baseline | *…* | *…* | *…* | *…* | *…* |
| treatment | *…* | *…* | *…* | *…* | *…* |

**Deviations.** *Numbered, one line each, with its reason: every difference from the idea's Planned test or from the stage, every part of the stage left out to fit the budget, and any time above the stage's. Write "None." when there is none. Approving the plan accepts them.*

1. *…*

**Steps.** *The steps in the order they run. The first steps prepare the code, the environments, and the data, and end with the smoke run; they run while planning. The steps after them wait for Human Approved, which also approves their writes. Go on when: the condition the next step needs; if it fails, stop and report. Time: from the basis below. Writes: what the step creates or changes besides its run folder and log, and where, such as a worktree, an environment, or data; leave the cell empty when there is nothing else.*

| Step | What it does | Go on when | Time | Writes |
|---|---|---|---|---|
| *…* | *…* | *…* | *…* | *…* |

*Basis: one line per measured number the times rest on, with its source and the hardware it was measured on, then how it scales to the current machine in `docs/AGENTS/machine.md`, what the treatment adds over the baseline, and what limits the speed, such as the GPU, data loading, or preprocessing; mark a number that nobody measured as estimated. Total: the task hours, and the wall-clock hours with the planned concurrency, e.g. three runs sharing one GPU; set Est. Hours to the latter. After the smoke run, replace the times with the measured ones and say in one line what changed.*

**Basis:** *…*

**Total:** *…*

## 2. Code and configuration

*The plan review reads it to check what the code computes, and the code review reads it with the code. Fill it from the code, the config snapshots, and the launch record, never from config names or memory. Before the smoke run, write the planned values and mark them as planned; replace them from the snapshots once it passes.*

*Model: architecture and initial weights, name plus version or hash. Data: dataset version and splits. Code: repository, branch, base commit, worktree, and entry point; the plan file `docs/plans/<date>-<name>.md`, which holds each run's config file and launch command, and, once the plan goes to approval, the plan file's SHA-256; and the launch commit once a run starts. Evaluation: metrics, the evaluation code version, locked for the whole comparison, and the statistics: how the spread over seeds is reported and the test of significance, such as mean ± std over 3 seeds and Welch's t-test. When evaluation runs in an environment rather than on a fixed test set, add an Environment row: the environment and its version, the number of evaluation episodes, and the success definition.*

| Item | Content |
|---|---|
| Model | *…* |
| Data | *…* |
| Code | *…* |
| Evaluation | *…* |

**Data per sample.** *Only when a training sample holds more than one input and its target, as in sequence models or a model with several branches; otherwise leave this part out. One row per component that reads the data, such as an encoder and an auxiliary prediction head: the inputs and targets it takes, by position relative to the current step t, e.g. tokens t−3 … t, and the next token t+1 as the target. Read them from the data-loading code, not from config names.*

| Component | Inputs | Targets |
|---|---|---|
| *…* | *…* | *…* |

**Data flow and losses.** *One training batch traced through the code, from the data loader to the total loss, for every model that differs, such as the baseline and a model with an extra branch. First a code block with the tensor shape after every step that changes it, the meaning of each axis, such as batch, time, channel, height, and width, where each component reads its input, and where gradients stop. Then one line per loss term: its formula, its weight, what it is averaged over and masked by, and how the terms add up to the total loss, including any per-sample weights, regularizers, and gradient clipping that differ between runs.*

*…*

**Code changes.** *One row per file the experiment adds or changes: its role, and the code it was adapted from (repository, commit, and file), or — if it was written from scratch.*

| File | Role | Adapted from |
|---|---|---|
| *…* | *…* | *…* |

**Hyperparameters.** *The values held equal across runs that a reviewer needs to judge the comparison, such as the learning rate, the batch size, and the training steps, and any parameter only the treatment has; the Runs table already gives what changes. Keep each name as the config writes it. Meaning: what the value does, as the code that reads it uses it rather than as its name suggests. Below the table, one line from the config snapshots: every other key is identical across runs, or the keys that differ.*

| Parameter | Meaning | Value |
|---|---|---|
| *…* | *…* | *…* |

## 3. Logs

*Overwrite the status row at every checkpoint, evaluation, and report. Under Curves, regenerate the training-loss and primary-metric curves from metrics.csv, one line per run, replacing the old figures. If the ETA drifts more than 20% from Est. Hours, update Est. Hours.*

| Runs | Latest metrics | Updated |
|---|---|---|
| *…* | *…* | *…* |

**Curves**

**Incidents.** *Leave this part out until the first incident: a divergence, NaN, plateau, or restart, one row each, with the step, what happened, and what was done.*

| Step | Incident | Action |
|---|---|---|
| *…* | *…* | *…* |

## 4. Results

*Compute from the final metrics files: mean ± std over seeds, the difference from the baseline, and its significance with the test named under Evaluation in section 2, from the per-seed values; round consistently, and investigate a result that looks too good before reporting it. Table 1 and at least one figure, such as the primary metric per run with error bars, in the style of `<kit>/references/figures.md`; save each figure as PDF and PNG, with the script that draws it, under `runs/<date>-<name>/figures/`. Observations: one row per thing worth knowing that Table 1 does not already say, surprises and failures included, each with its evidence: a figure, a run, or a paper from the post-experiment search.*

**Table 1.** *…*

| Run | Primary metric | vs baseline | p |
|---|---|---|---|
| baseline | *…* | — | — |
| treatment | *…* | *…* | *…* |

**Figure 1.** *…*

| Observation | Explanation | Evidence |
|---|---|---|
| *…* | *…* | *…* |

*Mark each check ✔ or ✘. The code-review check passes only after the user says they have reviewed the AI-generated code.*

| Check | Pass |
|---|---|
| Evaluation code and data version match the baseline | *✔ / ✘* |
| AI-generated code reviewed by a human | *✔ / ✘* |

## 5. Conclusion

*Criteria met: yes or no against Decided by in section 1, citing the Table 1 row; for an earlier stage, Decided by is its Go on when, so yes lets the next stage run and does not yet mean the idea holds. Next step: check the idea's Budget limits, then the next stage, or the part of it that fits the budget left, or stop iterating and draft the finding. Reproduce: one command that reruns the whole comparison from a clean checkout. GPU hours: one line per machine, its single-GPU hours from `gpu_hours.py` once its runs have ended, with any hours it could not count.*

| Item | Content |
|---|---|
| Criteria met | *…* |
| Next step | *…* |
| Reproduce | *…* |
| GPU hours | *…* |
