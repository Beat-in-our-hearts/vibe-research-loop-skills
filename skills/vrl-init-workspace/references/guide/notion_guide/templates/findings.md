# Findings template

| | |
|---|---|
| Database | Findings |
| Default properties | Status = Under Review |

Everything below the line is the body of a new page in the database. The agent that creates a page gives it the default properties above and writes each part of the body only when it fills it, at its place below, so the database needs no template in Notion. The callout comes first: it is written with the sections and rewritten in place each time the page goes to review. Text in *italics* is instructions for that agent: they stay in this file and never go into the page, and neither does the opening quote; plain text outside the italics goes into the page as it is. The `<aside>` block is a callout with the 📋 icon and a gray background.

---

> A finding reads like the experiments section of an academic paper: rigorous, rich in figures and tables, and complete on its own, so that a reader follows the claim without opening an experiment page; it restates the setup and the numbers its claim needs. Most findings are negative results: record a failure as carefully as a success. It may rest on an idea's experiments, or stand on its own, such as a performance test or a code optimization. The page title is the claim; it counts only once a human confirms it. Set a short, unique ID first, e.g. `warmup-gain`.

<aside>
📋 **Conclusion**

- **You decide:** whether the evidence below supports the claim; if it does, set Status to Confirmed.
- **Claim:** *one sentence, no broader than the evidence: supported or rejected against the criterion in section 1, or inconclusive, and the conditions under which it holds, with the confidence in brackets at the end: high when the result is significant in every setting tested, medium when in some, low when it rests on one seed or misses significance. A negative result says what it ruled out.*
- **Also:** *only if it applies, one line each: a change of direction, and an earlier finding this one replaces; otherwise leave this line out.*
- **Changed:** *what is new since the user's last review, or "first review".*
</aside>

## 1. Setup

*What a reader needs to judge the comparison, as a paper states it before its results. Experiments: @mention each, with the settings and result files it contributes. Measurements, for a result outside the research loop such as a performance test: each with the commit, the machine, and the command that produced it, against a baseline measured the same way. Criterion: the success criteria the claim is judged against, quoted from the idea, and whether each experiment met them; for a measurement, the threshold fixed before measuring, if any. Settings: the baseline and every setting compared, and the one thing each changes. Model and data: architecture, initial weights, dataset and splits. Metrics: each defined in one plain sentence, with ↑ or ↓. Statistics: seeds or repeats per setting, how the spread is reported, the test of significance, and the correction when several settings are compared. Files: where the result files and plotting scripts are. Leave out a row that does not apply. Take every number, p-values included, from the result files and the experiments' Table 1 as it is; never recompute it. Only a test that no experiment ran is computed here, by a script saved with the figures.*

| Item | Content |
|---|---|
| Experiments | *…* |
| Measurements | *…* |
| Criterion | *…* |
| Settings | *…* |
| Model and data | *…* |
| Metrics | *…* |
| Statistics | *…* |
| Files | *…* |

## 2. Results

*At least one table and two figures, of the kinds the data calls for: learning curves, bars with error bars, ablation or sensitivity plots, heatmaps, or qualitative examples; add more for ablations and secondary metrics. Draw each with a script from the result files, never by hand, and save it as PDF and PNG with its script under `runs/findings/<date>-<id>/`, where `<date>` is this page's Created date and `<id>` its ID; an experiment's figure may be used as it is when it already meets these rules. After each table or figure, one paragraph of analysis that cites it by number: what it shows, what it means for the claim, and how it compares with the expectation. Report mean ± std over seeds or repeats, and the difference from the baseline with its p-value from Table 1.*

*Publication style. Figures: axes with quantity and unit; mean ± std as error bars or shaded bands; one colorblind-safe color per setting across all figures; no 3D, pie charts, or titles inside the plot. Tables: units and ↑ or ↓ in the header; the best result in bold, the second best underlined; the same decimals within a column. Captions: numbered, stating what is shown, the number of seeds, and the takeaway; below a figure, above a table.*

**Table 1.** *…*

| Setting | Result (mean ± std) | vs baseline | p |
|---|---|---|---|
| *…* | *…* | *…* | *…* |

**Figure 1.** *…*

**Figure 2.** *…*

## 3. Discussion

*Every explanation other than the claim that the evidence has not ruled out, such as seed noise, unequal tuning, data leakage, or a bug, each with what would rule it out; failures, surprises, and negative results, stated as plainly as successes; how the result compares with published work, @mentioning the paper pages; and the limits of the claim: the settings, scales, and data it was not tested on.*
