# AGENTS.md

Rules for AI coding agents in this workspace, the directory the agent is launched from.

## Rule files

The files below hold the basic rules; this file wins over them.

- At the start of each session, run `git pull --rebase` in the workspace root if it has a remote, then read every file below; read them again whenever their full text has left your context, such as after compaction. Only Claude Code loads `@` imports by itself.
- If `docs/AGENTS/machine.md` is missing, stop and ask the user to set up this machine first.
- Before doing what a row names, make sure its file is in your context.

| File | Needed before |
|---|---|
| @docs/AGENTS/language_rules.md | Anything |
| @docs/AGENTS/machine.md | Launching a job, or checking resources |
| @docs/AGENTS/file_structure.md | Creating, moving, or deleting a file |
| @docs/AGENTS/environment.md | Setting an environment variable, or installing a tool |
| @docs/AGENTS/git.md | Running a git command |
| @docs/AGENTS/log_template.md | Launching a long-running command, or reading a log |
| @docs/AGENTS/tracking_training.md | Launching a training plan or another long task, or reporting its progress |
