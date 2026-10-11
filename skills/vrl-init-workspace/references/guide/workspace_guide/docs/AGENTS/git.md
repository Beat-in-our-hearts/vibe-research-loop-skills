# Git

**Git level for `main_repo` and its worktrees: manual commit.**

| Level | Commits | Pushes |
|---|---|---|
| Manual commit | Only when the user asks | Only when the user asks |
| Auto commit | On your own, whenever a change works and before every run you launch | Only when the user asks |
| Auto push | As in auto commit | After every commit, to the same branch on the remote |

In every repository:

- Stage the files you changed by path, never with `git add -A` or `git add .`, and never commit data, checkpoints, logs, caches, or credentials. Leave files you did not create alone, and mention them in your report.
- Never force-push, rewrite pushed history, or run destructive commands such as `reset --hard`, `clean`, or a forced checkout, unless the user asks.
- A run may start from uncommitted changes: `launch_run.sh` saves the checkout's diff as `git_diff.patch`, or `git_diff-<time>.patch` if an earlier start's diff differs, in the run's outputs folder, which a free-form launch must name with `--outputs`.

## Workspace repository

The workspace root is a git repository of its own, shared by every machine on branch `main`; `.gitignore` decides what it tracks and keeps machine-specific files out. Whatever the level above, it pulls and pushes on its own; without a remote, it only commits:

- Pull with `git pull --rebase` before you edit a tracked file; if a pull changes a rule file, read it again.
- Commit each change to a tracked file with a message that starts with this machine's name, and push.
- Edit a plan only on the machine that runs its experiment.
- If a pull fails or conflicts, or a push is rejected, stop and report.

## Worktrees

Work on another branch in its own worktree under `worktrees/`; never switch branches in a checkout where a job is running. Create a branch or worktree only when the user asks or an approved experiment plan calls for one. Remove a worktree only when the user asks, and never one with uncommitted changes. From the workspace root:

- List: `git -C main_repo worktree list`
- New branch: `git -C main_repo worktree add -b <branch> ../worktrees/<branch>`
- Branch that exists on the remote: `git -C main_repo fetch --prune`, then `git -C main_repo worktree add --track -b <branch> ../worktrees/<branch> origin/<branch>`
- Remove: `git -C main_repo worktree remove ../worktrees/<branch>`
