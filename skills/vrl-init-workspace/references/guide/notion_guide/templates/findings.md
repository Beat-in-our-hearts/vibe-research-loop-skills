# Findings template

| | |
|---|---|
| Database | Findings |
| Default properties | Status = Under Review |
| Callout | 📋 icon, gray background |

---

> A finding reads like the experiments section of an academic paper: rigorous, rich in figures and tables, and complete on its own, so that a reader follows the claim without opening an experiment page; it restates the setup and the numbers its claim needs. Most findings are negative results: record a failure as carefully as a success.

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

*At least one table and two figures, in the style of `<kit>/references/figures.md`, of the kinds the data calls for: learning curves, bars with error bars, ablation or sensitivity plots, heatmaps, or qualitative examples; add more for ablations and secondary metrics. Draw each with a script from the result files, and save it as PDF and PNG with its script under `runs/findings/<date>-<id>/`, where `<date>` is this page's Created date and `<id>` its ID; an experiment's figure may be used as it is when it already meets that style. After each table or figure, one paragraph of analysis that cites it by number: what it shows, what it means for the claim, and how it compares with the expectation. Report mean ± std over seeds or repeats, and the difference from the baseline with its p-value from Table 1.*

**Table 1.** *…*

| Setting | Result (mean ± std) | vs baseline | p |
|---|---|---|---|
| *…* | *…* | *…* | *…* |

**Figure 1.** *…*

**Figure 2.** *…*

## 3. Discussion

*Every explanation other than the claim that the evidence has not ruled out, such as seed noise, unequal tuning, data leakage, or a bug, each with what would rule it out; failures, surprises, and negative results, stated as plainly as successes; how the result compares with published work, @mentioning the paper pages; and the limits of the claim: the settings, scales, and data it was not tested on.*
