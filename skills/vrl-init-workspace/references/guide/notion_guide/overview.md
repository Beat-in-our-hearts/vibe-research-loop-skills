# Notion system overview

Notion is the knowledge memory of the research loop. Each research project is one Notion page with three linked databases; a separate Literature Library is shared by every project. This document describes the layout to reproduce in your own Notion workspace.

## Map

| Object | Location | Role | Defined in |
|---|---|---|---|
| Project page | Notion workspace top level, one per research project | One research project | [Project page](#project-page) below |
| Ideas | inline on the project page | Testable hypotheses | [`databases.md`](databases.md#ideas) · [`templates/ideas.md`](templates/ideas.md) |
| Experiments | inline on the project page | Controlled experiments | [`databases.md`](databases.md#experiments) · [`templates/experiments.md`](templates/experiments.md) |
| Findings | inline on the project page | Verified conclusions | [`databases.md`](databases.md#findings) · [`templates/findings.md`](templates/findings.md) |
| Literature Library | Notion workspace top level, shared by all projects | Curated papers | [Literature Library](#literature-library) below |
| Papers | inline on the Literature Library page | One row per paper | [`databases.md`](databases.md#papers-literature-library) · [`templates/papers.md`](templates/papers.md) |

Page, database, and template IDs differ in every Notion workspace, so none are recorded here. Agents find them by title with `POST v1/search` (see [`operations.md`](operations.md)). If you want to pin your own IDs, keep them outside this repository, for example in a document under `docs/` of your own agent workspace, built from [`workspace_guide/`](../workspace_guide/).

## Project page

A project page has three sections, top to bottom.

| Section | Contents |
|---|---|
| Research Core | The single research question and its framing, plus the Direction Log |
| Research Loop Overview | The loop diagram and its legend (source: [`research-loop.md`](research-loop.md)) |
| Knowledge Base | The Ideas, Experiments, and Findings databases |

Each project has exactly one research question, so the Research Core is a page section rather than a database.

| Research Core field | What goes there |
|---|---|
| Research question | One sentence: the question this project answers |
| Motivation | Why the question matters |
| Scope | What is in, and what is explicitly out |
| Answered when | The evidence that would settle the question |
| Current direction | The approach currently being pursued |
| Direction Log | Dated entries: `date — change — @finding`, added only after a human confirms the finding (the outer loop) |

## References

Pages reference each other by @mentioning them, mostly in the Related property; a mention shows the page's title and leaves a backlink on the mentioned page. The only database relation links each experiment to its idea (see [`databases.md`](databases.md)), so the library stays independent of every project. Every entry also has an ID, a short readable abbreviation such as `lr-warmup` (rules in [`databases.md`](databases.md#ids)), used in folder names and plain-text notes; its Created property dates it.

## Human-In-Loop

AI agents draft and run; humans decide at these points. Agents never set these values themselves.

| Step | Where | Meaning |
|---|---|---|
| Human Approved | Ideas | Feasibility reviewed; the idea may be implemented. Not a verdict: findings can still reject it. |
| Budget | Ideas | The limits at which the agent must stop iterating on an idea and report. |
| Human Approved | Experiments | The plan in sections 1–3 is approved, including any deviation from the idea's Planned test; runs start only after that. |
| Code review | Experiments, Results and analysis | A human reviewed the AI-generated code before the results count. |
| Confirmed / Overturned | Findings | The claim counts as knowledge, or a later finding replaced it. |
| Human Approved | Papers | The paper passed the admission rules and stays in the library. |
| Direction change | Project page | Decided by confirming a finding that calls for a change of direction; only then does the agent add the Direction Log entry. |

## Literature Library

Shared by all projects and independent of every project's knowledge memory: projects call it, and it never writes into them.

| Admission rule | Detail |
|---|---|
| Cap | At most 3 new papers per search run; zero is a valid result |
| Bar | Directly relevant to an active research question, and offers a method, result, or evidence we would use or must compare against |
| No duplicates | Check the Link (and title) before adding |
| One sentence | Every paper page opens with a one-sentence summary |
| Review | AI-added papers stay unapproved until a human ticks Human Approved or deletes them |

| Trigger | What happens |
|---|---|
| Daily search | A scheduled run scans arXiv, Semantic Scholar, and Hugging Face Daily Papers for the topics of active projects |
| Post-experiment search | When an experiment finishes, the agent looks for work that explains, supports, or contradicts the result. The analysis goes into the project's own pages; only papers that pass the admission rules are added to the library |

## Where things are stored

| Store | Holds |
|---|---|
| Notion | The index and the conclusions: ideas, experiment reports, findings, curated papers |
| Git: the code repository | Code and configs; each experiment records the commit it was launched from |
| Git: the workspace repository | Agent rules, plan files, and test code, shared by every machine (see [`workspace_guide/`](../workspace_guide/)) |
| Google Drive, optional | Datasets as versioned archives with checksums, and every machine's `runs/` and `logs/` under the same paths as in the workspace, without intermediate checkpoints (see [`gdrive_guide/`](../gdrive_guide/)) |
| Each machine only | `.env`, the machine profile, caches, scratch files, and intermediate checkpoints |

## Setting it up

An agent can do all of this by following [`notion_prompts.md`](notion_prompts.md); only the steps that need the Notion app are left to you.

| Step | What to do |
|---|---|
| 1. Connect | Install the `ntn` CLI and log in to your own Notion workspace |
| 2. Literature Library | Create a top-level page with the admission rules above and an inline Papers database ([`databases.md`](databases.md#papers-literature-library)) |
| 3. Project page | Create a top-level page with the three sections above: the Research Core, the loop diagram from [`research-loop.md`](research-loop.md), and the Knowledge Base |
| 4. Databases | Create Ideas, Experiments, and Findings inline on the project page, with the properties, relations, and views in [`databases.md`](databases.md) |
| 5. Templates | In each database, create an empty template in the Notion app (New ▾ → + New template), then fill its body from [`templates/`](templates/) |
| 6. Research Core | Write your research question and its framing |

For every further project, duplicate the project page: its inline databases, views, and templates come with it.

## Reviewing a page

A human reviews a page an agent wrote by coloring its text or its background: red for what they think is wrong, orange for what they did not understand, and purple for what they cannot accept. Before every write, the agent reads the colors of every rich-text item, table cells included: it fixes red, explains orange in plainer words and rewrites it so that it no longer needs the explanation, and proposes an alternative for purple and waits for the decision. Rewritten text loses its mark; a mark not yet resolved stays. Other colors carry no meaning.
