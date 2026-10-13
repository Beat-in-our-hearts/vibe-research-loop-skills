# Git

**Git level for `main_repo` and its worktrees: manual commit.** Commit and push only when the user asks.

In every repository:

- Stage files by path, never with `git add -A` or `git add .`. Never commit data, checkpoints, logs, caches, or credentials. Leave files you did not create alone, and mention them in your report.
- Never force-push, rewrite pushed history, run `reset --hard` or `clean`, or force a checkout, unless the user asks.

## Workspace repository

The workspace root is a repository of its own, on branch `main`, shared by every machine. Whatever the git level, commit and push it on your own; without a remote, only commit.

- Run `git pull --rebase` before you edit a tracked file; if a pull changes a rule file, read it again.
- Commit each change to a tracked file, with a message that starts with this machine's name, and push.
- Edit a plan only on the machine that runs its experiment.
- If a pull or push fails or conflicts, stop and report.

## Worktrees

Work on another branch only in its own worktree, never by switching a checkout a job uses, in `worktrees/<folder>`, the branch name with `/` replaced by `-`. Create a branch or worktree only when the user asks or an approved plan calls for one. Remove one only when the user asks, never with uncommitted changes. From the workspace root:

- New branch: `git -C main_repo worktree add -b <branch> ../worktrees/<folder>`
- Remove: `git -C main_repo worktree remove ../worktrees/<folder>`
