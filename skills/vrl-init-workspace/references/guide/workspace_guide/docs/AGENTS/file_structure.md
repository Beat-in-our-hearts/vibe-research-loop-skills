# File structure

```
workspace/
  AGENTS.md  # the user's strict rules, if any, and the rule index
  .gitignore
  .env
  .cache/
  main_repo/  # project code
  worktrees/
    <branch>/
  ref_repos/  # reference repositories
    <repo>/
  data/  # symlinks to datasets and pretrained weights
    <dataset>-<version>/
  docs/
    AGENTS/  # rule files
    plans/
      <date>-<name>.md  # experiment plan
  logs/
    <date>-<name>/
      <run>.log  # one per run of an experiment
    <date>-<task>.log  # other long commands, such as data processing
  runs/
    <date>-<name>/
      <run>/  # checkpoints, metrics.csv, config snapshots
      figures/  # result figures (PDF and PNG) with their plotting scripts
    findings/<date>-<id>/  # a finding's figures, plotting scripts, and raw measurement results
  tests/
    <repo>/  # the repository under test
      <topic>/  # what is tested
  tmp/  # one-off scripts and drafts
    tests/<repo>/<topic>/  # test outputs
```

`<date>-<name>` is the Created date and ID of the experiment's Notion page, such as `2026-09-30-lr-warmup-ablation`, shared by its plan, logs, and outputs; `<date>-<id>` is the same for a finding. Other logs use `<date>-<task>`: the day the command ran and a short task name.

## Folder rules

| Folder | Rules |
|---|---|
| Root | Only what the tree lists, plus harness config such as `.claude/`; anything else needs the user's approval. Change root files only when the user asks. Create each folder of the tree when first needed. |
| `main_repo/` | Project code only, never plans, logs, outputs, tests, or harness files. Point every output path at `runs/`, including the default folders of tools such as wandb and hydra. |
| `worktrees/` | One checkout of `main_repo` per branch, named after the branch with any `/` replaced by `-`; the `main_repo/` rules apply. |
| `ref_repos/` | One folder per repository, named as upstream; record its URL and commit in the Code row of every experiment that uses it. Change it only on a local branch, and never push. |
| `data/` | Read-only. Save processed data as a new version. |
| `docs/` | Markdown only. Change `AGENTS/` only when the user asks. Put other documents in subfolders by topic. A plan, one per experiment, holds each run's config file and launch command, pinned to its checkout's commit and diff; once approved, any change to the plan or the code needs a new approval. |
| `logs/` | One log per long-running command, named as in the tree. |
| `runs/` | Never overwrite or delete a finished run; give a rerun a new run name. |
| `tests/` | Test code only: its outputs go to `tmp/tests/`, its logs to `logs/`, and an output kept as evidence is a run, in `runs/`. Write a test only when the user asks, or to pin down a bug in shared code such as data processing, losses, or metrics; otherwise verify with a short smoke run (a few steps on a small subset), logged in `logs/`. Add tests to `main_repo`'s own suite only when the user asks. |
| `tmp/` | Anything here may be deleted at any time, so nothing in Notion or elsewhere may point to it. |
| `.cache/` | Tool caches only: never results, data, or anything that cannot be downloaded again. |
