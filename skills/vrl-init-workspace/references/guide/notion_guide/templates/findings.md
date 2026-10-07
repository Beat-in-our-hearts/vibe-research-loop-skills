# Findings template

| | |
|---|---|
| Database | Findings |
| Default properties | Status = Under Review |

Everything below the line is the body of every new page in the database: the agent that creates a page writes it in, with the default properties above, so the database needs no template in Notion. The opening quote is for that agent, who follows it and leaves it out of the page. Text in *italics* is gray italic text in Notion: those lines are instructions. Each starts with who acts and when — Agent (on creation), Agent (during runs), Agent (after runs), Agent (after review), or Human (review) — and says where the content comes from.

---

> A finding reads like the experiments section of a paper: figures, tables, and written analysis, all three. Most findings are failures or negative results — research is countless failures and the occasional success, and every failure deserves a careful record. It may rest on an idea's experiments, or stand on its own, such as a performance test or a code optimization. The page title is the claim; AI drafts it, and it counts only once a human confirms it. Start by setting a short, unique ID, e.g. `warmup-gain`.

## 1. Evidence sources

*Agent (after runs): list what this finding rests on: the experiments, @mentioned in Related, or, for a result outside the research loop such as a performance test, each measurement with the commit, the machine, and the command that produced it; then where the result files and plotting scripts are. Write — in a row that does not apply. Take every number from these sources as it is; never recompute it.*

| Source | Location |
|---|---|
| Experiments | *…* |
| Measurements | *…* |
| Result files | *…* |
| Plotting scripts | *…* |

## 2. Results and analysis

*Agent (after runs): write this like the experiments section of a paper, rich in figures and tables and never text alone: at least one table and two figures, of the kinds the data calls for (learning curves, bars with error bars, ablation or sensitivity plots, heatmaps, qualitative examples); extend or replace the examples below. Save each figure as PDF and PNG, with its plotting script, under `runs/findings/<date>-<id>/`, where `<date>` is this page's Created date and `<id>` its ID. After each figure or table, a paragraph of analysis cites it by number: what it shows, what it means, and how it compares with the expectation. Report mean ± std over seeds and name the statistical method and its conclusion; name in the analysis any other explanation not ruled out (seed noise, unequal tuning, data leakage, a bug). Present failures, surprises, and negative results just as plainly, and @mention the paper pages when comparing with published results.*

*Agent (after runs): publication style. Figures: drawn by a script from the result files, never by hand; axes with quantity and unit; mean ± std as error bars or shaded bands; one colorblind-safe color per setting across all figures; no 3D, pie charts, or titles inside the plot. Tables: units and ↑ or ↓ in the header; the best result in bold, the second best underlined; the same decimals within a column. Captions: numbered, stating what is shown, the number of seeds, and the takeaway; below a figure, above a table.*

**Table 1.** *…*

| Setting | Result (mean ± std) | vs baseline |
|---|---|---|
| *…* | *…* | *…* |

**Figure 1.** *…*

**Figure 2.** *…*

## 3. One-sentence conclusion

*Agent (after runs): state the conclusion in one sentence — supported, rejected, or inconclusive, and the conditions under which it holds — with the confidence (high, medium, or low) in brackets at the end; a failed result states what it ruled out. If the direction should change or an earlier finding is replaced, say so after the sentence. Human (review): check the evidence sources and the numbers, then set Status to Confirmed. Agent (after review) then, if the finding resolves an idea, sets that idea's Status to Finish with Outcome Supported or Rejected, or to Parked if the conclusion is inconclusive, and adds the Direction Log entry, if any; setting an overturned finding to Overturned stays with a human.*

| Item | Content |
|---|---|
| Conclusion | *…* |
