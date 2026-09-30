# Ideas template

| | |
|---|---|
| Database | Ideas |
| Template | Create an empty template in the database in the Notion app (New ▾ → + New template), then fill its body with the content below |
| Default properties | Status = Backlog · Human Approved = unchecked |

Everything below the line is the template body exactly as it appears in Notion. Text in *italics* is gray in Notion: those lines are instructions. Each starts with who acts and when — Agent (on creation), Agent (during runs), Agent (after runs), Agent (after review), or Human (review) — and says where the content comes from. This file is the source of truth; the rules for syncing it to Notion are in [`../operations.md`](../operations.md).

---

> Capture one idea so a human can judge its feasibility before anything is built; a human ticks Human Approved after the review. Start by setting a short, unique ID, e.g. `lr-warmup`, and write the hypothesis as the page title.

## 1. Motivation

*Agent (on creation): one row per source, with the result or gap it reveals. Take sources from the Findings database or the Literature Library, and @mention them in the Related property.*

| Source | What it shows |
|---|---|
| *…* | *…* |

## 2. Feasibility analysis

*Agent (on creation): explain why the hypothesis could hold: one row per key assumption, with why we believe it and what would break it. Formalize where you can, for example a formula for the mechanism, an estimate of the effect size, or a derivation of the expected result, placed below the table; where you cannot, plain reasoning is enough.*

| Assumption | Why we believe it | What would break it |
|---|---|---|
| *…* | *…* | *…* |

## 3. Planned test

*Agent (on creation): the plan a human approves; experiments must follow it or record their deviations. Success criteria is the pass/fail threshold and must be written before anything runs, e.g. "+1% over the baseline, mean of 3 seeds".*

| Item | Plan |
|---|---|
| Baseline | *…* |
| Single change | *…* |
| Success criteria | *…* |

## 4. Budget

*Agent (on creation) proposes limits from the expected compute; Human (review) sets them. Agent (after runs): update Used after every experiment. Once any limit is reached, the success criteria are met, or several experiments in a row bring no improvement, stop iterating on this idea, draft the corresponding finding, and report to a human.*

| Item | Limit | Used |
|---|---|---|
| Experiments | *…* | *0* |
| Compute | *…* | *0* |
| Deadline | *…* | *—* |
