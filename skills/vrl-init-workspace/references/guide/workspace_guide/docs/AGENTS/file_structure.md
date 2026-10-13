# File structure

```
workspace/
  AGENTS.md
  .gitignore
  .env
  .cache/  # tool caches, nothing that cannot be downloaded again
  main_repo/  # project code
  worktrees/<branch>/
  ref_repos/<repo>/  # reference repositories
  data/<dataset>-<version>/  # symlinks to datasets and weights
  docs/
    AGENTS/  # rule files
    plans/<date>-<name>.md
  logs/
    <date>-<name>/<run>.log
    <date>-<task>.log  # any other long command
  runs/
    <date>-<name>/
      <run>/  # checkpoints, metrics.csv, config snapshots
      figures/  # with their plotting scripts
    findings/<date>-<id>/
  tests/<repo>/<topic>/
  tmp/  # one-off scripts and drafts
    tests/<repo>/<topic>/  # test outputs
```

`<date>-<name>`: the Created date (`YYYY-MM-DD`) and ID of the experiment's Notion page; `<date>-<id>`: the same for a finding; `<date>-<task>`: the day the command ran and a short task name.

## Folder rules

| Folder | Rules |
|---|---|
| Root | Only the tree's entries and harness config such as `.claude/`; anything else, or a change to a root file, needs the user's approval. |
| `main_repo/` | Project code only. Send every output, a tool's default folder such as wandb's included, to `runs/`. |
| `ref_repos/` | Named as upstream. Record its URL and commit in the Code row of each experiment that uses it. Change it only on a local branch; never push. |
| `data/` | Read-only. Save processed data as a new version. |
| `docs/` | Markdown only, other documents in subfolders by topic. Change `AGENTS/` only when the user asks. Once a plan is approved, a change to it or its code needs a new approval. |
| `runs/` | Never overwrite or delete a finished run. |
| `tests/` | Test code only; evidence to keep goes to `runs/`. Write a test, here or in `main_repo`'s suite, only when the user asks, or here to pin down a bug in shared code such as losses or metrics; else verify with a short smoke run. |
| `tmp/` | May be deleted at any time: never point to it from Notion or elsewhere. |
