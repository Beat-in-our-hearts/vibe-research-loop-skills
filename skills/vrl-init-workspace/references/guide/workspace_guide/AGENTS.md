# AGENTS.md

Rules for agents in this workspace, the directory you are launched from. This file wins over the rule files below.

## Rule files

- At each session's start, run `git pull --rebase` in the workspace root if it has a remote, then read every file below. Reread a file before its row's task once its text has left your context, as after compaction. Only Claude Code loads `@` imports itself.
- If `docs/AGENTS/machine.md` is missing, stop and ask the user to set up this machine.

| File | Needed before |
|---|---|
| @docs/AGENTS/language_rules.md | Anything |
| @docs/AGENTS/machine.md | Launching a job or checking resources |
| @docs/AGENTS/file_structure.md | Creating, moving, or deleting a file |
| @docs/AGENTS/environment.md | Setting an environment variable or installing a tool |
| @docs/AGENTS/git.md | Any git command |
| @docs/AGENTS/log_template.md | Launching a long-running command or reading a log |
| @docs/AGENTS/tracking_training.md | Starting a long task or reporting its progress |
