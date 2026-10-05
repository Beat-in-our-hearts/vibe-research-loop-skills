# Ideas template

| | |
|---|---|
| Database | Ideas |
| Template | Create an empty template in the database in the Notion app (New ▾ → + New template), then fill its body with the content below |
| Default properties | Status = Backlog · Human Approved = unchecked |

Everything below the line is the template body exactly as it appears in Notion. Text in *italics* is gray in Notion: those lines are instructions. The `<aside>` block is a callout with the 💡 icon and a blue background. Each starts with who acts and when — Agent (on creation), Agent (during runs), Agent (after runs), Agent (after review), or Human (review) — and says where the content comes from. This file is the source of truth; the rules for syncing it to Notion are in [`../operations.md`](../operations.md).

---

> Capture one idea so a human can judge its feasibility before anything is built; a human ticks Human Approved after the review. Set a short, unique ID, e.g. `lr-warmup`, write the hypothesis as the page title, and write the line of thought before anything else: every section below follows from it.

<aside>
💡 **Line of thought**

*Agent (on creation): five steps of reasoning, in plain words and in this order, written before the sections. Goal: what this idea is for. Observations: what was seen, with its numbers and sources, that prompted it. Hypothesis: the guess, and why it would explain the observations. Test: the smallest test that can tell. Decision: what result supports or rejects the guess, and what comes next either way.*

- **Goal:** *…*
- **Observations:** *…*
- **Hypothesis:** *…*
- **Test:** *…*
- **Decision:** *…*
</aside>

## 1. Motivation

*Agent (on creation): the evidence behind the line of thought, one row per source, in its order. Take sources from the Findings database, the Literature Library, earlier experiments, or the user's own words, and @mention the Notion pages among them in the Related property. In What it shows, give the fact with its numbers, then → what it means for the hypothesis. When a source compares several settings, put them in a small table below with a bold caption, e.g. **Table 1.**, rather than in one long cell.*

| Source | What it shows |
|---|---|
| *…* | *…* |

## 2. Feasibility analysis

*Agent (on creation): one row per key assumption, with why we believe it and what would break it. Below the table, explain the mechanism in plain words; add a formula only after the words, and only if it makes the argument sharper.*

| Assumption | Why we believe it | What would break it |
|---|---|---|
| *…* | *…* | *…* |

## 3. Planned test

*Agent (on creation): the plan a human approves; experiments must follow it or record their deviations. Use exactly the settings the user named, such as the model, its size, and the data; check them against measured sources, and ask before changing one. Baseline says what is reused and what is rerun. Success criteria is the pass/fail threshold and must be written before anything runs, e.g. "+1% over the baseline, mean of 3 seeds"; define every metric in one plain sentence where it first appears, with the values a healthy run and a failed run show when they are known.*

| Item | Plan |
|---|---|
| Baseline | *…* |
| Change from the baseline | *…* |
| Success criteria | *…* |

**Groups.** *Agent (on creation): every group the test compares, the baseline and any control included: what it changes, whether it needs training, how it is evaluated, and its seeds. Below the table, say why each control is there.*

| Group | Setting | Training | Evaluation | Seeds |
|---|---|---|---|---|
| *…* | *…* | *…* | *…* | *…* |

## 4. Budget

*Agent (on creation) proposes limits from the estimate below; Human (review) sets them. Agent (after runs): update Used after every experiment. Once any limit is reached, the success criteria are met, or several experiments in a row bring no improvement, stop iterating on this idea, draft the corresponding finding, and report to a human.*

| Item | Limit | Used |
|---|---|---|
| Experiments | *…* | *0* |
| Compute | *…* | *0* |
| Deadline | *…* | *—* |

**Estimate.** *Agent (on creation): one row per group, then a Total row. Single GPU: the time to train and evaluate the group, all its seeds included, on one GPU; the Total is their sum, the compute to weigh against the Compute limit. This machine: the wall-clock time with the runs spread over the GPUs of the current machine in `docs/AGENTS/machine.md`, saying how many. Basis: in a few words, the measured number each time comes from, such as a log or an earlier report, or that nothing comparable was measured and the time is a guess. Setup, smoke runs, and the detailed estimate belong to the experiment.*

| Item | Single GPU | This machine | Basis |
|---|---|---|---|
| *…* | *…* | *…* | *…* |
