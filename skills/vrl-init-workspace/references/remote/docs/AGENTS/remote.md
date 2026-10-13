# Remote

**This machine computes on a remote host over SSH.** You work on the local machine, at the workspace root; the remote host runs all code and keeps every result. Elsewhere in the rules, "this machine" means the remote host wherever code runs or results are kept.

| Item | Value |
|---|---|
| Local machine | <short name, and what it is, such as a laptop> |
| Remote host | `ssh <alias>`: the `Host <alias>` entry in the local `~/.ssh/config` |
| Remote workspace | `<absolute path on the remote host>` |
| Check limit | `<check limit>` seconds, for `check` and `connect` |
| Command limit | `<command limit>` seconds, for every other call |

## Where files live

| Local: the workspace root | Remote: the remote workspace |
|---|---|
| The workspace repository, the code folder, `worktrees/`, `ref_repos/`; `.env` with only `TZ`; `logs/` for the night watch; `tmp/` for drafts and fetched files | Their mirrors, at the same paths; `.env` with every variable; `.cache/`, `data/`, `logs/`, `runs/`, `tmp/`, environments |

- Write absolute remote paths, `<remote workspace>/<path>`, in configs and Notion.
- Edit files only here, except the analysis scripts below. Never change a mirror's files without the user's approval; "Sync" says how.
- Results stay on the remote host. Fetch only a figure to upload or a lock file to commit, and delete the copy once used.
- Write plotting and analysis scripts on the remote host, beside their figures or under `tmp/`, through `run -`:

  ```
  vrl_ssh.sh run <alias> --workspace <remote workspace> --limit <command limit> -- - <<'VRL'
  cat > <path>.py <<'EOF'
  <the script>
  EOF
  VRL
  ```

## Where commands run

- Here, run only file reads and edits, git, `vrl_ssh.sh`, `check_update.sh`, `ntn` or `lark-cli`, `gh`, web requests, and text tools such as `grep` and `jq`. Run everything else on the remote host, data downloads and `hf` included. To check code, even quickly, commit, sync, and check it there.
- Install no git hook or filter driver here, such as with `pre-commit install`.

## Sync

Code reaches the remote host only as commits, through `vrl_ssh.sh sync`.

- Before a remote command uses changed code, plans, or tests, commit them as the git rules allow and sync each checkout they touch: `.` for the workspace repository, a worktree after its own checkout.
- Take pins and plan hashes only from a sync's output, which prints them even when nothing changed.
- A mirror holds one commit. An experiment whose code differs from a running or waiting one's needs its own worktree, with the user's consent. Before a sync, check that no approved experiment waits to launch a run pinned to the mirror's current commit; `sync … --commit <commit> -- <checkout>` restores a waiting run's commit.
- Discard a mirror change the user approved with `run`: delete the untracked file, or `git -C <checkout> checkout -- <path>`. To keep it, read it with `git -C <checkout> diff`, redo it here, commit, and discard it there.
- A run writes only to `$VRL_OUTPUTS`, `logs/`, or `tmp/`. Sync a checkout a run uses without naming it, such as a reference repository, only while no such run is going.
- Build environments without changing a tracked file, such as with `uv sync --locked`. Change a lock file in a copy under the remote `tmp/`, then fetch it, show the user, and commit it here.

## Connection

Reach the remote host only through `vrl_ssh.sh`, never `ssh`, `scp`, or `rsync`. Below, `…` stands for `--workspace <remote workspace> --limit <command limit>`.

| `vrl_ssh.sh` call | Use |
|---|---|
| `check <alias> --limit <check limit>` | Before a task's first remote command, and when one fails or hangs |
| `connect <alias> --limit <check limit>` | Start or repair the master when `check` fails |
| `sync <alias> … -- <checkout>...` | Copy commits to the mirrors; `--limit 0` for a first large sync |
| `run <alias> … -- '<command>'` | Run a command there, with no input: pass `-y` or the like |
| `script <alias> … -- <script> <options>` | Run a VRL script there |
| `read <alias> … [--lines <n>] -- <path>` | Read the end of a text file, or list a folder |
| `fetch <alias> … -- <path>...` | Copy figures or a lock file into `tmp/fetched/` |

- Start anything that may outlast the command limit in the remote tmux session: `script <alias> … -- launch_run.sh --purpose '<…>' --log logs/<date>-<task>.log --code <checkout> --no-gpu --machine <name> --tmux <session> -- '<command>'`. Pass `--code none` only for a command that uses no checkout.
- Run every `vrl_ssh.sh` call in the background where you can, and read its output at once. A call is done at its last line, `__EXIT <code>`; stop it if the tool still lists it as running. Without that line, tell the user you are waiting and end the turn.
- When `__EXIT` is not 0, do what the `vrl_ssh:` or script lines above it say, and stop and report when they say so. Never work around a refusal.
  - A login that needs the user: ask them to run the printed command in their own terminal, and wait.
  - If the host does not answer, never fall back to running code here.
  - After 124, the command may still be running: read its log before you try again.
- Change the alias's entry in `~/.ssh/config` only when the user asks. Never print, copy, or upload keys, tokens, or passwords. Stop only processes you started.

## Git

- Commit, push, and pull only here, never in a mirror.
- A run starts only from a commit, never from a saved diff.

## Notion

- Run `ntn` with the `TZ` of the local `.env`.
- <Only if the local machine has no OS keychain:> run `ntn` with `NOTION_KEYRING=0`, which the user's shell profile exports.
