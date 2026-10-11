# Remote

**This machine computes on a remote host over SSH.** Agents run on the local machine, at the workspace root, which runs no code; the remote host runs it all, from mirrors that only `vrl_ssh.sh sync` writes, and keeps every result. In the other rule files, "this machine" means the remote host wherever code runs or results are kept.

| Item | Value |
|---|---|
| Local machine | <short name, and what it is: e.g. a laptop, 4 cores, no GPU> |
| Remote host | `ssh <alias>`: the `Host <alias>` entry in the local `~/.ssh/config`. `vrl_ssh.sh` reads the alias from this line, so keep both code spans on it |
| Remote workspace | `<absolute path on the remote host>` |
| Check limit | `<check limit>` seconds: the time limit of `check` and `connect` |
| Command limit | `<command limit>` seconds: the time limit of every other call, at least 5 seconds below the agent's own time limit for a shell call, such as 2 minutes by default in Claude Code |

## Where files live

| Local machine: the workspace root | Remote host: the remote workspace |
|---|---|
| The workspace repository: `AGENTS.md`, `.gitignore`, `docs/`, and `tests/`. The code folder, `worktrees/`, and `ref_repos/`, as git checkouts. `.env`, holding only `TZ`. `logs/`, for the night watch's logs only. `tmp/`, for drafts and fetched files. Harness config such as `.claude/` | A mirror of the workspace repository and of each checkout, at the same paths. `.env`, with every variable the tools need. `.cache/`, `data/`, `logs/`, `runs/`, `tmp/`, and the environments |

- A relative path names the same file on both sides, but `logs/…` and `runs/…` exist only on the remote host. Write absolute remote paths, `<remote workspace>/<path>`, in configs and Notion, and paths relative to the workspace root to the VRL scripts, such as `--code main_repo` and `--log logs/…`.
- Edit files only here. Never edit a mirror, commit in it, or change it with git, except the `git checkout -- <path>` that discards a change the user approved, as "Sync" says.
- Results stay on the remote host: read them there. Fetch nothing but a figure to upload or a lock file to commit, and delete the copy in `tmp/fetched/` once used.
- Write plotting and other analysis scripts on the remote host, next to their figures or under `tmp/`: they are the only files written there by hand. Send each through `run` with `-`, which reads the command from standard input, so its quotes and `$` signs arrive unchanged:

  ```
  vrl_ssh.sh run <alias> --workspace <remote workspace> -- - <<'VRL'
  cat > runs/<…>/figures/<name>.py <<'EOF'
  <the script>
  EOF
  VRL
  ```

- This file and the machine profile describe one machine and stay out of the workspace repository.

## Where commands run

| Local machine | Remote host, through `vrl_ssh.sh` |
|---|---|
| Reading and editing files; git in the local repositories; `vrl_ssh.sh` and `check_update.sh`; `ntn` or `lark-cli`; `gh`; web requests; text tools such as `grep`, `sed`, or `jq` | Everything that runs code: `python`, `pip`, `uv`, `conda`, `pytest`, linters and type checkers, notebooks, `make`, scripts of a checkout, environments, builds, smoke runs, training, evaluation, metrics, plotting, downloads, `hf`, and the VRL scripts `launch_run.sh`, `resources.sh`, and `gpu_hours.py` |

- Run no code here, not even a quick check, and create no environment or lock file here: to check code, commit it, sync it, and check it there. Read JSON with `jq` or a CLI's own `--jq`.
- Install no git hook or filter driver here, such as with `pre-commit install` or `nbstripout --install`: it would run code at every commit.
- If the remote host stays unreachable after the steps under "Connection", stop and report. Never fall back to the local machine.

## Sync

Code reaches the remote host only as commits, through `vrl_ssh.sh sync`.

- Before a remote command uses changed code, plans, or tests, commit the change as the git rules allow (under the manual commit level, ask the user to commit, or to let you), and sync each checkout it touches: `.` for the workspace repository, and a worktree's own checkout, such as the code folder, before the worktree, in the same call or an earlier one.
- Take pins and plan hashes only from a sync's output: each checkout's pin for a plan block, `code=<checkout>@<commit> diff=clean`, printed even when nothing changed, and for `.` a line `sha256 <plan file> <hash>` for every plan file. Record your plan file's hash at approval.
- A mirror holds one commit at a time, and a sync refuses to change it while a run uses it. Give each experiment whose code differs from that of a running or waiting one a worktree of its own, with the user's consent. Before you sync a checkout, check that no approved experiment still waits to launch a run pinned to its mirror's commit. If a sync moved a mirror off the commit a waiting run is pinned to, the launch refuses that run: copy the pinned commit back with `vrl_ssh.sh sync … --commit <commit> -- <checkout>`, which needs no new approval while the plan and its pin are unchanged.
- A sync also refuses, changing nothing, when the mirror holds changes no sync made, such as files a run wrote or an edit on the remote host. Show the user the list, and never delete, move, or check out files in a mirror unless they ask. Then discard what they approve with `vrl_ssh.sh run`: delete an untracked file, or restore a tracked one with `git -C <checkout> checkout -- <path>`. To keep a change, read it there with `git -C <checkout> diff`, make it here, commit it, then discard it in the mirror.
- A run writes only to `$VRL_OUTPUTS`, `logs/`, or `tmp/`; Python caches go to the `PYTHONPYCACHEPREFIX` that `.env` sets, or are ignored in `.gitignore`. A free-form launch whose command uses a checkout passes `--code <checkout>`, never `none`, with its log under `logs/`, so that a sync sees the checkout in use. A run protects only the checkout its header names: sync another checkout it uses, such as a reference repository on its path, only while no such run is going.
- A sync refuses a checkout with a submodule or Git LFS files. Tell the user, who decides, for example, to commit a submodule's files on a local branch, or to download large files on the remote host under `data/`.
- Build environments without changing a tracked file, such as with `uv sync --locked`. Change a lock file only in a copy of the project's files under the remote `tmp/`: fetch it, show the user the change, then commit it here and sync.
- Run the first sync of a large repository with `--limit 0`.

## Connection

One SSH master carries the whole session. Reach the remote host only through `vrl_ssh.sh`, one of the VRL scripts here; never run `ssh`, `scp`, `rsync`, or `pkill` by hand. Its exit codes are listed below; read `vrl_ssh.sh --help` only for an option this file does not give.

| Task | Command, from the workspace root |
|---|---|
| Check the connection, before the first remote command of a task and whenever one fails or hangs | `vrl_ssh.sh check <alias> --limit <check limit>` |
| Start or repair the master, when the check fails | `vrl_ssh.sh connect <alias> --limit <check limit>` |
| Copy committed checkouts to their mirrors | `vrl_ssh.sh sync <alias> --workspace <remote workspace> --limit <command limit> -- <checkout>...` |
| Run a command in the remote workspace, with its `.env` | `vrl_ssh.sh run <alias> --workspace <remote workspace> --limit <command limit> -- '<command>'` |
| Run a VRL script there | `vrl_ssh.sh script <alias> --workspace <remote workspace> --limit <command limit> -- <launch_run.sh, resources.sh, or gpu_hours.py> <its options>` |
| See how each run of a plan stands, with the end of its log | `vrl_ssh.sh script <alias> --workspace <remote workspace> --limit <command limit> -- launch_run.sh --plan docs/plans/<plan file> --status` |
| Read the end of a log or a text result, or list a folder, under `logs/`, `runs/`, or `tmp/` | `vrl_ssh.sh read <alias> --workspace <remote workspace> --limit <command limit> [--lines <n>] -- <path>` |
| Copy figures, or a lock file, into `tmp/fetched/` | `vrl_ssh.sh fetch <alias> --workspace <remote workspace> --limit <command limit> -- <path>...` |

- The command after `run` is one string, sent as it is to a remote bash: it needs no quoting of its own, may span several lines, and gets no input, so pass the non-interactive option of anything that would ask, such as `-y`.
- Start anything that may outlast the command limit with `launch_run.sh` in the remote tmux session, which returns at once, and check on it later with short commands. The free form: `vrl_ssh.sh script <alias> --workspace <remote workspace> -- launch_run.sh --purpose '<...>' --log logs/<date>-<task>.log --code <checkout> --no-gpu --machine <name> --tmux <the machine's tmux session> -- '<command>'`. A command that surely needs longer, but not long enough for the tmux session, may get a longer `--limit` for that call alone, still at least 5 seconds below the agent's own.
- Run every `vrl_ssh.sh` call in the background where the shell tool can, such as with `run_in_background` in Claude Code, and read its output right after starting it. Every call ends with a line `__EXIT <code>`.
  - With that line, the call is done: go on. If the tool still lists it as running, stop it, such as with `TaskStop` in Claude Code.
  - Without it, tell the user you are waiting for the call and end the turn instead of polling; read the output again when its completion notice arrives or the user writes.
- For `run` and `script`, the exit code is the remote command's own unless the line above `__EXIT` starts with `vrl_ssh:`. The codes of `vrl_ssh.sh` itself:
  - 1 or 255 from `check` or `connect`: the remote host does not answer. Stop and report.
  - 3 from `connect`: the login needs a password, a passphrase, or a second factor. Ask the user to run the printed command in their own terminal, and wait.
  - 3 from `sync`, `read`, or `fetch`: refused, with the reason, and nothing changed for that path; the paths before it in the same call are done. Act on the reason; never work around it.
  - 4 from `sync` or `fetch`: a copy or a remote step failed. Try again once the cause is fixed.
  - 5: the host key, new or changed, could not be verified. Stop and report.
  - 6 or 7: no master is up, or it hangs. Run `connect` once; if that fails, stop and report.
  - 98: the remote workspace has no `.env`. Stop and report; `--no-env` is only for setup.
  - 124: a time limit cut the call. A command it started may still run: read its log before you try again.
- Change the alias's entry in `~/.ssh/config` only when the user asks. Never print, copy, or upload keys, tokens, or passwords. Stop only processes you started.

## Git

- Every commit, push, and pull happens here, under the git rules. A mirror has no remote, no branch, and no commit of its own.
- A run starts only from a commit: no run ever needs a saved diff.

## Notion

- Run `ntn` with the `TZ` of the local `.env`.
- <Only if the local machine has no OS keychain:> `ntn` keeps its login in a file: run it with `NOTION_KEYRING=0`, which the user's shell profile exports.
- Upload a figure from its fetched copy with `ntn files create --filename <name>.png --content-type image/png < tmp/fetched/<path>.png`.
