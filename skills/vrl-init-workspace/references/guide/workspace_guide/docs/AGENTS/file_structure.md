# File structure

```
workspace/                       # the directory agents are launched from
├── AGENTS.md                    # entry point: the user's strict rules, if any, and the rule index
├── .gitignore                   # what the workspace repository tracks
├── .env                         # this machine's environment variables, as few as possible
├── .cache/                      # caches of all tools
├── main_repo/                   # the main code repository (git): project code only
├── worktrees/                   # other branches of main_repo, checked out side by side
│   └── <branch>/
├── ref_repos/                   # reference repositories, e.g. code for reproducing papers
│   └── <repo>/
├── data/                        # read-only symlinks to datasets and pretrained weights
│   └── <dataset>-<version>/
├── docs/                        # Markdown documents
│   ├── AGENTS/                  # basic rules for agents, one topic per file
│   └── plans/
│       └── <date>-<name>.md     # experiment plan; the Notion Plan file row points here
├── logs/                        # logs of long-running commands
│   ├── <date>-<name>/
│   │   └── <run>.log            # one log per run of an experiment
│   └── <date>-<task>.log        # other long commands: data processing, evaluation, setup
├── runs/                        # training outputs
│   ├── <date>-<name>/
│   │   ├── <run>/               # checkpoints, metrics.csv, config snapshots
│   │   └── figures/             # result figures (PDF and PNG) with their plotting scripts
│   └── findings/<date>-<id>/    # a finding's figures with their plotting scripts
├── tests/                       # test code, only when needed
│   └── <repo>/                  # named after the repository under test
│       └── <topic>/             # grouped by what is tested
└── tmp/                         # one-off scripts and drafts
    └── tests/<repo>/<topic>/    # outputs of tests, rebuilt by rerunning them
```

`<date>-<name>` is the Created date and the ID of the experiment's Notion page, e.g. `2026-09-30-lr-warmup-ablation`; the plan, logs, and outputs of one experiment share it. `<date>-<id>` does the same for a finding's page. Other logs use `<date>-<task>`: the day the command ran and a short task name.

## Folder rules

| Folder | Rules |
|---|---|
| Root | Only what the tree lists, plus harness config such as `.claude/`; anything else needs the user's approval. The root is itself a git repository, and `.gitignore` decides what it tracks. Change the root files only when the user asks. Create a folder from the tree when it is first needed. |
| `main_repo/` | Project code only: never plans, logs, outputs, tests, or harness files. Point every output path at `runs/`, including the default folders of tools such as wandb and hydra. |
| `worktrees/` | One checkout of `main_repo` per branch, named after the branch with any `/` replaced by `-`. The `main_repo/` rules apply. |
| `ref_repos/` | One folder per repository, named as upstream. Record its URL and commit in the Code row of every experiment that uses it. Change it only on a local branch, and never push. |
| `data/` | Read-only. Save processed data as a new version. |
| `docs/` | Markdown only. Change `AGENTS/` only when the user asks. Keep one plan per experiment in `plans/`, consistent with sections 1–3 of its Notion page; put other documents in subfolders by topic. |
| `logs/` | One log per long-running command, named as in the tree. |
| `runs/` | Never overwrite or delete a finished run; give a rerun a new run name. |
| `tests/` | Test code only: a test writes its outputs to `tmp/tests/<repo>/<topic>/` and its log to `logs/`; an output kept as evidence is a run and belongs in `runs/`. Write no tests by default: verify with a short smoke run (a few steps on a small subset), logged in `logs/`. Write a test only when the user asks, or to pin down a bug in shared code such as data processing, losses, or metrics. Add tests to `main_repo`'s own suite only when the user asks. |
| `tmp/` | Anything here may be deleted at any time, so nothing in Notion or elsewhere may point to it. |
| `.cache/` | Tool caches only: never results, data, or anything that cannot be downloaded again. |
