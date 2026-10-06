# Papers template

| | |
|---|---|
| Database | Papers (Literature Library) |
| Default properties | Human Approved = unchecked |

Everything below the line is the body of every new page in the database: the agent that creates a page writes it in, with the default properties above, so the database needs no template in Notion. The opening quote is for that agent, who follows it and leaves it out of the page. Text in *italics* is gray italic text in Notion: those lines are instructions. Each starts with who acts and when — Agent (on creation), Agent (during runs), Agent (after runs), Agent (after review), or Human (review) — and says where the content comes from.

---

> Admission bar: a paper enters only if it is directly relevant to an active research question and offers a method, result, or evidence we would use or must compare against. Better none than a poor one. A human ticks Human Approved after the review and deletes papers that fail it. Start by setting a short, unique ID, usually the method name and year, e.g. `openvla-2024`.

## 1. One-sentence summary

*Agent (on creation): one sentence on the problem, the method, and the result; projects read it first. Write only from what was actually read, and say whether that was the abstract or the full text.*

| Item | Content |
|---|---|
| Summary | *…* |
| Read level | *…* |

## 2. Motivation and contribution

*Agent (on creation): the problem, why it matters, where existing methods fall short, and the main contributions, one per line.*

| Item | Content |
|---|---|
| Motivation | *…* |
| Contribution | *…* |

## 3. Method and formulas

*Agent (on creation): the core idea and the key components of the method; where it can be expressed as formulas, write the key equations below the table and define every symbol.*

| Component | Role |
|---|---|
| *…* | *…* |

## 4. Key results

*Agent (on creation): only the results that matter: datasets, baselines, the key numbers, and the ablation findings. Show them in figures and tables, never in text alone: Table 1 plus at least one figure, either the paper's own figure cropped from the PDF, with its original number in the caption, or a chart redrawn from numbers in the paper. Every number cites where it appears in the paper (section, table, or figure); never write a number that was not read in the paper itself.*

*Agent (on creation): publication style. Redrawn figures: axes with quantity and unit; one colorblind-safe color per method; no 3D, pie charts, or titles inside the plot. Tables: units and ↑ or ↓ in the header; the best result in bold, the second best underlined; the same decimals within a column. Captions: numbered, stating what is shown, where it comes from in the paper, and the takeaway; below a figure, above a table.*

**Table 1.** *…*

| Setting | Result | Where in the paper |
|---|---|---|
| *…* | *…* | *…* |

**Figure 1.** *…*

## 5. Strengths and weaknesses

*Agent (on creation): the strengths and the limitations of the method, including whether the comparison is fair, whether the conclusions generalize, and how hard it is to reproduce (code and data released or not).*

| Aspect | Content |
|---|---|
| Strengths | *…* |
| Weaknesses | *…* |

## 6. Takeaways

*Agent (on creation): what this means for our research: what to reuse, compare against, or rule out; @mention the idea or finding pages it bears on, in any project. For a paper found by a post-experiment search, also @mention the experiment that triggered it.*

| Takeaway | Related pages |
|---|---|
| *…* | *…* |
