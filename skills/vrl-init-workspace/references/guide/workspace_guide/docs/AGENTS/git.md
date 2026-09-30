# Git

**Git level for `main_repo` and its worktrees: manual commit.** Change it only when the user asks.

| Level | Commits | Pushes |
|---|---|---|
| Manual commit | Only when the user asks | Only when the user asks |
| Auto commit | On your own, whenever a change works and before every run you launch, so that each run maps to a commit | Only when the user asks |
| Auto push | As in auto commit | After every commit, to the same branch on the remote |

In every repository:

- Stage the files you changed by path; never `git add -A` or `git add .`. Leave files you did not create alone, and mention them in your report.
- Never commit data, checkpoints, logs, caches, or credentials.
- Never force-push, rewrite pushed history, or run destructive commands such as `reset --hard`, `clean`, or a forced checkout, unless the user asks.
- When you launch a run from uncommitted changes, save `git diff` in its output folder.

## Workspace repository

The workspace root is a git repository of its own, shared by every machine on one branch, `main`. `.gitignore` decides what it tracks, and machine-specific files stay out. It always pulls and pushes on its own, whatever the level above; without a remote, it only commits:

- Pull with `git pull --rebase` before you edit a tracked file; if a pull changes a rule file, read it again.
- After each change to a tracked file, commit it with a message that starts with this machine's name, and push.
- Edit a plan only on the machine that runs its experiment.
- If a pull fails or conflicts, or a push is rejected, stop and report.

## Worktrees

Work on another branch in its own worktree under `worktrees/`; never switch branches in a checkout where a job is running.

| Task | Command, run from the workspace root |
|---|---|
| List worktrees | `git -C main_repo worktree list` |
| New branch | `git -C main_repo worktree add -b <branch> ../worktrees/<branch>` |
| Branch that exists on the remote | `git -C main_repo fetch --prune`, then `git -C main_repo worktree add --track -b <branch> ../worktrees/<branch> origin/<branch>` |
| Remove | `git -C main_repo worktree remove ../worktrees/<branch>` |

- Create a branch or worktree only when the user asks or an approved experiment plan calls for one.
- Remove a worktree only when the user asks, and never one with uncommitted changes.
