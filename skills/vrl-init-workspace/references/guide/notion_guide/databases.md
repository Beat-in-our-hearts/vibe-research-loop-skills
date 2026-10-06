# Databases

Four databases: Ideas, Experiments, and Findings live on each project page; Papers lives in the shared Literature Library. Create them with the properties below; [`overview.md`](overview.md) explains how to set them up and how agents find their IDs. Properties hold only what a human needs to see, filter, group, or approve, plus what a formula computes; every other detail lives in the page body (see [`templates/`](templates/)). Every entry has a readable ID and a Created date.

## IDs

Every entry has an ID: a short abbreviation that a human can read at a glance. It is a text property, chosen by the agent when the entry is created.

| Rule | Detail |
|---|---|
| Format | Lowercase English words joined by hyphens, at most 24 characters |
| Unique | Unique within its database; if taken, add `-2`, `-3` |
| Set once | Never renamed after creation: folder names and notes refer to it |
| Examples | Idea `lr-warmup` · Experiment `lr-warmup-ablation` · Finding `warmup-gain` · Paper `openvla-2024` |

## Links between pages

| From | Property | To | How |
|---|---|---|---|
| Experiments | Idea | Ideas | One-way relation: the idea under test |
| Ideas | Related | Findings, Papers, Experiments | Text holding @mentions of the finding, paper, and earlier experiment pages the idea comes from |
| Findings | Related | Ideas, Experiments | Text holding @mentions of the idea and experiment pages behind the claim |

A Notion relation can point to only one database, so Related is a text property holding @mentions: one column can reference several databases, every mentioned page gets a backlink, and the Literature Library needs no property of its own.

## Time zone

All dates and times in Notion use the project's time zone: the one chosen when its workspace is set up, kept as `TZ` in the workspace's `.env`.

| Where | How |
|---|---|
| Date properties with a time | Agents set `time_zone` to the project's time zone |
| Times in page text | Written as `YYYY-MM-DD HH:MM`, in the project's time zone |
| Created and other automatic times | Each person sets their Notion time zone to the project's |

## Ideas

Testable hypotheses derived from the research core. A human must tick Human Approved before an idea is implemented.

| Property | Type | Values | Meaning |
|---|---|---|---|
| Name | title | | The hypothesis in short, at most 15 words, or 20 characters in Chinese; the line of thought states it in full, so that it can be falsified |
| ID | text | e.g. `lr-warmup` | Short, readable handle |
| Status | status | Backlog (to-do) · Testing (in progress) · Finish · Parked (complete) | Lifecycle, independent of approval |
| Outcome | select | Supported · Rejected | The second level of Finish, set together with it |
| Human Approved | checkbox | | Feasibility reviewed by a human; agents implement only approved ideas. It stays checked even if findings later reject the idea |
| Priority | select | High · Medium · Low | The order in which agents pick up approved ideas |
| Related | text | @mentions of finding, paper, and experiment pages | The findings, papers, and earlier experiments the idea comes from |
| Created | created time | | When the idea was written down; set by Notion |

| Status | Outcome | Set when | Set by |
|---|---|---|---|
| Backlog | | The idea is created | The agent |
| Testing | | Its first experiment is created | The agent |
| Finish | Supported or Rejected | A human confirmed the finding that resolves it | The agent |
| Parked | | The confirmed finding is inconclusive, or a human shelves the idea | The agent, or a human |

| View | Type | Shows |
|---|---|---|
| Pipeline | board, grouped by Status | Name, ID, Human Approved, Priority, Outcome |
| Ready to Implement | table, filter: Human Approved and Status = Backlog, sorted by Priority | What agents may pick up next |
| All Ideas | table, sorted by Created, newest first | All properties |

## Experiments

One row per experiment: a controlled comparison of baseline, treatment, and ablation runs. A human approves the plan before any run starts.

| Property | Type | Values | Meaning |
|---|---|---|---|
| Name | title | | The experiment in a few words, at most 15 words, or 20 characters in Chinese |
| ID | text | e.g. `lr-warmup-ablation` | Short, readable handle; also `<name>` in the output folder `runs/<date>-<name>/` |
| Idea | relation, one-way | → Ideas | The idea under test |
| Status | status | Planned (to-do) · Running (in progress) · Finish (complete) | |
| Outcome | select | Done · Failed · Invalid | The second level of Finish, set together with it |
| Human Approved | checkbox | | A human approved the plan in sections 1–3 of the page; agents start runs only after that |
| Progress | formula | text bar, e.g. `███████░░░ 70%` | Elapsed time / Est. Hours, capped at 100%; Finish shows 100%, or `stopped` if the outcome is Failed or Invalid |
| Started | date and time | | Start of the first run, set by the agent when it launches that run |
| Est. Hours | number | | Estimated wall-clock hours from the first run to the end of the plan, from the step times measured in the smoke run and the planned concurrency (the Time estimate in section 2); updated when the ETA drifts |
| Created | created time | | When the experiment was planned; also `<date>` in the output folder `runs/<date>-<name>/` |

| Status | Outcome | Set when | Set by |
|---|---|---|---|
| Planned | | The experiment is created; sections 1–3 hold the plan | The agent |
| Running | | The first run is launched, together with Started | The agent |
| Finish | Done | Every run in the approved plan finished; a result that misses the success criteria is still Done | The agent |
| Finish | Failed | The plan could not be completed: a crash, out of memory, or a divergence that could not be fixed | The agent |
| Finish | Invalid | The comparison cannot be trusted: mismatched evaluation code or data, a bug, a change to the plan without a new approval, or failed code review | The agent, or a human |

The Progress formula (Notion formula 2.0):

```text
if(prop("Outcome") == "Failed" or prop("Outcome") == "Invalid", "stopped",
  if(prop("Status") == "Finish", "██████████ 100%",
    if(empty(prop("Started")) or empty(prop("Est. Hours")), "",
      let(p, min(1, max(0, dateBetween(now(), prop("Started"), "minutes") / (prop("Est. Hours") * 60))),
        repeat("█", round(p * 10)) + repeat("░", 10 - round(p * 10)) + " " + format(round(p * 100)) + "%"))))
```

It is a text bar because the API cannot switch a number to Notion's native bar display.

| View | Type | Shows |
|---|---|---|
| All Experiments | table, sorted by Created, newest first | All properties |
| By Idea | table, grouped by Idea | Name, ID, Status, Outcome, Human Approved, Progress, Created |
| Experiment Board | board, grouped by Status | Name, ID, Idea, Human Approved, Progress, Outcome |

Ideas has no Experiments column because the relation is one-way; the By Idea view lists each idea's experiments.

## Findings

Verified conclusions. AI drafts them; a human confirms before they count as knowledge. The page title is the claim.

| Property | Type | Values | Meaning |
|---|---|---|---|
| Name | title | | The claim in short, no broader than the evidence, at most 15 words, or 20 characters in Chinese; the one-sentence conclusion states it in full |
| ID | text | e.g. `warmup-gain` | Short, readable handle |
| Status | status | Under Review (to-do) · Confirmed · Overturned (complete) | A new finding starts Under Review; only a human sets Confirmed or Overturned |
| Related | text | @mentions of idea and experiment pages | The idea it resolves and the experiments behind it |
| Created | created time | | When the finding was drafted; set by Notion |

| View | Type | Shows |
|---|---|---|
| Review Queue | board, grouped by Status | Name, ID, Related |
| All Findings | table, sorted by Created, newest first | All properties |

## Papers (Literature Library)

Curated papers shared by all projects. Quality over quantity; admission rules are in [`overview.md`](overview.md).

| Property | Type | Values | Meaning |
|---|---|---|---|
| Title | title | | The paper's title |
| ID | text | e.g. `openvla-2024` | Short, readable handle; usually the method name and year |
| Human Approved | checkbox | | A human checked the paper against the admission rules and keeps it |
| Keywords | multi-select | | Keep the list short; reuse a keyword before adding one |
| Corresponding Authors | multi-select | | One or more corresponding authors |
| Affiliations | multi-select | | The authors' institutions |
| Link | URL | | arXiv, DOI, or publisher page; used to detect duplicates |
| Created | created time | | When the paper was added; set by Notion |

| View | Type | Shows |
|---|---|---|
| Review Queue | table, filter: Human Approved unchecked, sorted by Created, newest first | Papers waiting for a human |
| Library | table, filter: Human Approved checked, sorted by Created, newest first | The curated library |
