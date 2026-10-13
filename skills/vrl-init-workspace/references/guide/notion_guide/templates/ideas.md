# Ideas template

| | |
|---|---|
| Database | Ideas |
| Default properties | Status = Backlog · Human Approved = unchecked |
| Callout | 💡 icon, blue background |

---

> Capture one idea so a human can judge its feasibility before anything is built. Every section follows from the line of thought, and none repeats it.

<aside>
💡 **Line of thought**

- **You decide:** whether the idea may be built: tick Human Approved, and set the limits in section 3. *Then, in a few words, the full test's single-GPU hours against the proposed compute limit.*
- **Goal:** *one sentence: what this idea is for.*
- **Observations:** *one sentence: what prompted it; its numbers and sources go in section 1.*
- **Hypothesis:** *the guess, stated so that it can be falsified, and why it would explain the observations.*
- **Test:** *one sentence: the smallest test that can tell, and how it grows if the first results are promising.*
- **Decision:** *one sentence: what each outcome leads to.*
- **Changed:** *what is new since the user's last review, or "first review".*
</aside>

## 1. Evidence and assumptions

*One row per assumption the hypothesis rests on, in the order of the line of thought. Evidence: the fact with its numbers, then its source: a finding, a paper, an earlier experiment, or the user's words; @mention the Notion pages among them, and add them to Related. Breaks if: the result that would prove the assumption wrong. Below the table, explain the mechanism in at most three sentences, adding a formula only if it makes the argument sharper. When a source compares several settings, give them in a small table with a bold caption, e.g. **Table 1.**, rather than in one cell.*

| Assumption | Evidence | Breaks if |
|---|---|---|
| *…* | *…* | *…* |

## 2. Planned test

*The test a human approves; every experiment follows it or lists its deviations. Use exactly the settings the user named, such as the model, its size, and the data; check them against measured sources, and ask before changing one. Success criteria: the pass/fail threshold, fixed before anything runs, e.g. "+1% over the baseline, mean of 3 seeds"; define every metric in one plain sentence where it first appears, with the values a healthy run and a failed run show when they are known.*

**Success criteria:** *…*

**Groups.** *Every group the test compares, the baseline first and any control included. Setting: for the baseline, what it is; for every other group, only what it changes. Training: whether it trains, and for the baseline what is reused and what is rerun. Evaluation: how it is evaluated. Why: for a control only, the other explanation it rules out.*

| Group | Setting | Training | Evaluation | Seeds | Why |
|---|---|---|---|---|---|
| *…* | *…* | *…* | *…* | *…* | *…* |

## 3. Stages and budget

*One row per stage, from the smallest test that can show whether the idea is promising to the full test; each experiment runs one stage, or the part of it that fits the budget left. What it tests: its groups and seeds in a few words. Single GPU and This machine: its time on one GPU and on the GPUs of the current machine in `docs/AGENTS/machine.md`, saying how many. Go on when: the condition the next stage needs. Basis: in one sentence, what the times rest on, such as a log or an earlier report, or that they are a guess. Then propose each limit in the Limit column; the user sets it there.*

| Stage | What it tests | Single GPU | This machine | Go on when |
|---|---|---|---|---|
| *…* | *…* | *…* | *…* | *…* |

**Basis:** *…*

| Item | Limit |
|---|---|
| Experiments | *…* |
| Compute (single-GPU hours) | *…* |
| Deadline | *…* |
