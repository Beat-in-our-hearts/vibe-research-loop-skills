# Remote

**This machine computes on a remote host over SSH.** Agents are launched on the local machine, at the workspace root, which keeps the rules, the plans, and all code. The local machine runs no code: the remote host runs it all, from mirrors of the local checkouts that only `vrl_ssh.sh sync` writes, and keeps every result. In the other rule files, "this machine" means the remote host wherever code runs or results are kept.

| Item | Value |
|---|---|
| Local machine | <short name, and what it is: e.g. a laptop, 4 cores, no GPU> |
| Remote host | `ssh <alias>`: the `Host <alias>` entry in the local `~/.ssh/config`, which holds the host name, user, port, and any jump host. `vrl_ssh.sh` reads the alias from this line, so keep both code spans on it |
| Remote workspace | `<absolute path on the remote host>` |
| Check limit | `<check limit>` seconds: the local time limit of the connection check |
| Command limit | `<command limit>` seconds: the local time limit of a remote command; with the 5 seconds of grace a time limit adds, it stays below the agent's own time limit for a shell call |

## Where files live

| Local machine: the workspace root | Remote host: the remote workspace |
|---|---|
| The workspace repository: `AGENTS.md`, `.gitignore`, `docs/`, and `tests/`. The code folder, `worktrees/`, and `ref_repos/`, as git checkouts. `.env`, holding only `TZ`. `logs/`, for the night watch's logs only. `tmp/`, for drafts and fetched files. Harness config such as `.claude/` | A mirror of the workspace repository and of each checkout, at the same paths. `.env`, with every variable the tools need. `.cache/`, `data/`, `logs/`, `runs/`, `tmp/`, and the environments |

- A relative path names the same file on both sides: `main_repo/train.py` is edited here and runs there, while `logs/…` and `runs/…` exist only there. Write absolute remote paths, `<remote workspace>/<path>`, in configs, launch commands, and Notion.
- Edit files only here. A mirror holds exactly the last commit synced to it, checked out with no branch: never edit it, commit in it, or run git commands that change it.
- Results stay on the remote host. Read them there, as "Connection" shows. Bring nothing back but a figure to upload or a lock file to commit, with `vrl_ssh.sh fetch`, which copies it into `tmp/fetched/`; delete the copy once you have used it.
- Write plotting and other analysis scripts on the remote host, next to the figures they draw or under `tmp/`, through `vrl_ssh.sh run`, as in `cat > runs/<…>/figures/<name>.py <<'EOF'`. They are the only files written there by hand.
- The machine profile and this file describe one machine and stay out of the workspace repository, so no sync copies them.

## Where commands run

| Local machine | Remote host, through `vrl_ssh.sh` |
|---|---|
| Reading and editing files; git in the local repositories; `vrl_ssh.sh` and `check_update.sh`; `ntn` or `lark-cli`; `gh`; web requests; text tools such as `grep`, `sed`, or `jq` | Everything that runs code: Python, installs, environments, tests, linters, builds, smoke runs, training, evaluation, metrics, plotting, downloads, `hf`, and the VRL scripts `launch_run.sh`, `resources.sh`, and `gpu_hours.py` |

- Run no code on the local machine, not even for a quick check: no `python`, `pip`, `uv`, `conda`, `pytest`, linter, type checker, notebook, `make`, or script of a checkout, and create no environment or lock file here. To check code, commit it, sync it, and check it on the remote host. `launch_run.sh`, `resources.sh`, and `gpu_hours.py` refuse to run here.
- Install no git hook here, such as with `pre-commit install`: a hook runs code at every commit, and remote mode commits before every sync.
- If the remote host is unreachable, and the steps under "Connection" do not bring it back, stop and report. Never fall back to the local machine.

## Sync

Code reaches the remote host only as commits, through `vrl_ssh.sh sync`.

- Before a remote command uses changed code, a changed plan, or a changed test, commit the change, as the git rules allow, and sync each checkout it touches, with `.` for the workspace repository. Under the manual commit level, ask the user to commit, or to let you commit, before each sync. Name a worktree's own checkout, such as the code folder, before the worktree, in the same call or an earlier one.
- The sync prints each checkout's pin, `code=<checkout>@<commit> diff=clean`: the pin to write into a plan block. For `.`, it also prints `sha256 <plan file> <hash>` for each plan file that changed: the hash to record at approval. Take pins and plan hashes only from these lines.
- A mirror holds one commit at a time, and a sync refuses to change a mirror while a run that uses it is still going. Give each experiment whose code differs from that of a running or waiting experiment a worktree of its own.
- A sync also refuses, and changes nothing, when the mirror holds changes no sync made, such as files a run wrote into its checkout, or an edit made on the remote host. Show the user what it lists; never delete, move, or check out files in a mirror unless they ask. A run writes only to `$VRL_OUTPUTS`, `logs/`, or `tmp/`; Python caches go to the `PYTHONPYCACHEPREFIX` that `.env` sets, or are ignored in `.gitignore`.
- A free-form launch whose command uses a checkout passes `--code <checkout>`, never `none`, so that a sync can tell the checkout is in use.
- Build environments on the remote host without changing a tracked file, such as with `uv sync --locked`. A lock file changes on the remote host only, in a copy of the project's files under `tmp/`: fetch the new lock file, show the user the change, then commit it here and sync.
- Run the first sync of a large repository with `--limit 0`, as a background call.

## Connection

One SSH master carries the whole session: every command and every copy. Reach the remote host only through `vrl_ssh.sh`, one of the VRL scripts on the local machine; never run `ssh`, `scp`, `rsync`, or `pkill` by hand. It names the host by its alias, sends no command without the master, so that nothing logs in by itself, keeps host-key checking on, and ends every call with a line `__EXIT <code>`. Read `vrl_ssh.sh --help` once per session for its exit codes.

| Task | Command, from the workspace root |
|---|---|
| Check the connection, before the first remote command of a task and whenever one fails or hangs | `vrl_ssh.sh check <alias> --limit <check limit>` |
| Start or repair the master, when the check fails | `vrl_ssh.sh connect <alias> --limit <check limit>` |
| Copy committed checkouts to their mirrors | `vrl_ssh.sh sync <alias> --workspace <remote workspace> --limit <command limit> -- <checkout>...` |
| Run a command in the remote workspace, with its `.env` | `vrl_ssh.sh run <alias> --workspace <remote workspace> --limit <command limit> -- '<command>'` |
| Run a VRL script on the remote host | `vrl_ssh.sh script <alias> --workspace <remote workspace> --limit <command limit> -- <launch_run.sh, resources.sh, or gpu_hours.py> <its options>` |
| See how each run of a plan stands, with the end of its log | `vrl_ssh.sh script <alias> --workspace <remote workspace> --limit <command limit> -- launch_run.sh --plan docs/plans/<plan file> --status` |
| Read the end of a log or a text result, or list a folder, under `logs/`, `runs/`, or `tmp/` | `vrl_ssh.sh read <alias> --workspace <remote workspace> --limit <command limit> [--lines <n>] -- <path>` |
| Copy figures, or a lock file, into `tmp/fetched/` | `vrl_ssh.sh fetch <alias> --workspace <remote workspace> --limit <command limit> -- <path>...` |

- The command after `run` is one string, sent as it is to a remote bash: it needs no quoting of its own, may span several lines, and gets no input, so pass the non-interactive option of anything that would ask, such as `-y`. Anything that may take longer than the command limit starts with `launch_run.sh` in the remote tmux session, which returns at once with the log; check on it later with short commands. For example, in the free form: `vrl_ssh.sh script <alias> --workspace <remote workspace> -- launch_run.sh --purpose '<...>' --log logs/<date>-<task>.log --code <checkout> --no-gpu --machine <name> --tmux <the machine's tmux session> -- '<command>'`.
- Keep the command limit plus 5 seconds below the agent's own time limit for a shell call, such as 2 minutes by default in Claude Code. A command that surely needs longer, but not long enough for the tmux session, may get a longer `--limit` for that call alone, still 5 seconds short of the agent's own.
- Run every `vrl_ssh.sh` call as a background call of the agent's shell tool where it has one, such as `run_in_background` in Claude Code, and read its output right after starting it: a shell tool can miss that a command has exited, and a background call never blocks the session.
  - The `__EXIT` line means the call finished, with its exit code: go on.
  - Without that line, the call is still running or the tool lost it: tell the user you are waiting for it and end the turn, instead of polling; read the output again when its completion notice arrives or the user writes.
  - If the line is there but the tool still lists the call as running, go on, and stop that call, such as with `TaskStop` in Claude Code.
- Read an exit code by its source. For `run` and `script`, it is the remote command's own unless the line above `__EXIT` starts with `vrl_ssh:`; the codes below are `vrl_ssh.sh`'s own.
  - 3 from `connect`: the login needs a password, a passphrase, or a second factor. Ask the user to run the command it prints in their own terminal, and wait.
  - 3 from `sync`, `read`, or `fetch`: refused, with the reason, and nothing changed. Act on the reason; never work around it.
  - 4 from `sync` or `fetch`: a copy or a remote step failed. Try again once the cause is fixed.
  - 5: the host key could not be verified, new or changed. Stop and report.
  - 6 or 7: no master is up, or it hangs. Run `connect` once; if that fails, stop and report.
  - 1 or 255 from `check` or `connect`: the remote host does not answer. Stop and report.
  - 98: the remote workspace has no `.env`. Stop and report; `--no-env` is only for setup, before `.env` exists.
  - 124: a time limit cut the call. A command it started may still run: read its log before you try again.
- Change the alias's entry in `~/.ssh/config` only when the user asks. Never print, copy, or upload keys, tokens, or passwords.
- Stop only processes you started.

## Git

- The workspace root is the workspace repository, holding `AGENTS.md`, `docs/`, and `tests/`; the code folder, `worktrees/`, and `ref_repos/` sit in it as checkouts of their own repositories. Every commit, push, and pull happens here, under the git rules. The remote host holds only mirrors, with no remote, no branch, and no commit of their own.
- A run starts only from a commit, since a sync copies nothing else: no run ever needs a saved diff.

## Notion

- Run `ntn` here, with `docs/notion/ids.md` and the `TZ` of the local `.env`.
- <Only if the local machine has no OS keychain:> `ntn` keeps its login in a file: run it with `NOTION_KEYRING=0`, which the user's shell profile exports.
- Draw figures on the remote host, fetch each one, upload it from `tmp/fetched/` with `ntn files create --filename <name>.png --content-type image/png < tmp/fetched/<path>.png`, then delete the copy.
