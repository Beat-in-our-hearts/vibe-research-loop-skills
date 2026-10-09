# Remote

**This machine computes on a remote host over SSH.** Agents are launched on the local machine, in the launch directory, which holds only the rules; every other file of the workspace lives on the remote host, and every workspace command runs there, apart from the few that the table under "Where commands run" keeps local. In the other rule files, "this machine" means the remote host.

| Item | Value |
|---|---|
| Local machine | <short name, and what it can run: e.g. 2 cores, 4 GB, no GPU> |
| Remote host | `ssh <alias>`: the `Host <alias>` entry in the local `~/.ssh/config`, which holds the host name, user, port, and any jump host. `vrl_ssh.sh` reads the alias from this line, so keep both code spans on it |
| Remote workspace | `<absolute path on the remote host>` |
| Mount | `<launch directory>/<mount>`, an SSHFS view of the remote workspace |
| tmux session | `<session>` on the remote host |
| Check limit | `<check limit>` seconds: the local time limit of the connection check |
| Command limit | `<command limit>` seconds: the local time limit of a remote command; with the 5 seconds of grace a time limit adds, it stays below the agent's own time limit for a shell call |

## Where files live

| Launch directory (local) | Remote workspace |
|---|---|
| `AGENTS.md`, `.gitignore`, `docs/AGENTS/`, harness config such as `.claude/`, and the mount folder | Everything else in the folder tree: `.env`, `.cache/`, the code folder, `worktrees/`, `ref_repos/`, `data/`, `docs/` except `docs/AGENTS/`, `logs/`, `runs/`, `tests/`, `tmp/` |

- A workspace path in a rule file, a skill, or Notion, such as `docs/plans/…`, `logs/…`, or `runs/…`, is relative to the remote workspace; only `AGENTS.md` and `docs/AGENTS/` are relative to the launch directory.
- Locally, reach a remote path as `<mount>/<path>`; on the remote host, as `<remote workspace>/<path>`. Write absolute remote paths in logs, configs, launch commands, and Notion, never mount paths.
- Every write through the mount is an immediate remote write; there is no local copy to sync. Never copy the remote workspace, or part of it, to the local machine.
- Create nothing else in the launch directory.

## Where commands run

| Local machine | Remote host, through SSH |
|---|---|
| Reading and editing files, remote ones through the mount; `vrl_ssh.sh`; `ntn` or `lark-cli`; web requests such as paper searches; git of the launch directory | Everything else: git of the remote workspace and its repositories, Python, installs, smoke runs, training, evaluation, metrics, plotting, downloads, `hf`, and resource checks |

- Never run a project command locally, and never point a local command at the mount to run it (`python <mount>/…`, `git -C <mount>/…`, `pip`, `chmod`, …).
- If the remote host or the mount is unreachable, stale, or read-only, and the steps under "Connection" do not bring it back, stop and report. Never fall back to the local machine, never create a local stand-in for the mount, and remount only when the user asks.

## Connection

One SSH master carries the whole session: every command and the mount. Reach the remote host only through `vrl_ssh.sh`, one of the vrl scripts on the local machine; never run `ssh`, `pkill`, or `sshfs` by hand. It names the host by its alias, sends no command without the master, so that nothing logs in by itself, keeps host-key checking on, and ends every call with a line `__EXIT <code>`. Read `vrl_ssh.sh --help` once per session for its exit codes.

| Task | Command, from the launch directory |
|---|---|
| Check the connection, before the first remote command of a task and whenever one fails or hangs | `vrl_ssh.sh check <alias> --limit <check limit> --mount <mount>` |
| Start or repair the master, when the check fails | `vrl_ssh.sh connect <alias> --limit <check limit>` |
| Run a command in the remote workspace, with its `.env` | `vrl_ssh.sh run <alias> --workspace <remote workspace> --limit <command limit> -- '<command>'` |
| Run a vrl script on the remote host | `vrl_ssh.sh script <alias> --workspace <remote workspace> --limit <command limit> -- <launch_run.sh, resources.sh, or gpu_hours.py> <its options>` |
| Mount the remote workspace again, only when the user asks | `vrl_ssh.sh mount <alias> --workspace <remote workspace> --mount <mount>` |

- The command after `run` is one string, sent as it is to a remote bash: it needs no quoting of its own, may span several lines, and gets no input, so pass the non-interactive option of anything that would ask, such as `-y` or `git commit -m`. Anything that may take longer than the command limit runs with `launch_run.sh --tmux <session>`, which returns at once with the log; check on it later with short commands.
- Keep the command limit plus 5 seconds below the agent's own time limit for a shell call, such as 2 minutes by default in Claude Code. A command that surely needs longer, but not long enough for the tmux session, may get a longer `--limit` for that call alone, still 5 seconds short of the agent's own.
- Run every `vrl_ssh.sh` call as a background call of the agent's shell tool where it has one, such as `run_in_background` in Claude Code, and read its output right after starting it: a shell tool can miss that a command has exited, and a background call never blocks the session.
  - The `__EXIT` line means the call finished, with its exit code: go on.
  - Without that line, the call is still running or the tool lost it: tell the user you are waiting for it and end the turn, instead of polling; read the output again when its completion notice arrives or the user writes.
  - If the line is there but the tool still lists the call as running, go on, and stop that call, such as with `TaskStop` in Claude Code.
- On exit code 3 of `connect`, the login needs a password, a passphrase, or a second factor: ask the user to run the command it prints in their own terminal, and wait. On 5, the host key changed: stop and report. On 1, 124, or 255, the remote host does not answer: stop and report.
- Before reading or writing through the mount, check the connection with `--mount`, which never touches the mount itself: reading a mount whose connection is dead can hang, the file tools included. While the check fails, touch nothing under the mount; repair the connection first.
- Change the alias's entry in `~/.ssh/config` only when the user asks. Never print, copy, or upload keys, tokens, or passwords.
- Stop only processes you started.

## Git

- The launch directory is the rules repository, holding `AGENTS.md` and `docs/AGENTS/`; the remote workspace root is the workspace repository, holding `docs/` and `tests/`. Both follow the workspace repository rules in the git rules, each with its own remote, if any.
- `docs/AGENTS/machine.md` and this file describe one machine and stay out of the rules repository.

## Notion

- Run `ntn` locally. Take `docs/notion/ids.md` and the `TZ` of `.env` from the mount.
- <Only if the local machine has no OS keychain:> `ntn` keeps its login in a file: run it with `NOTION_KEYRING=0`, which the user's shell profile exports.
- Draw figures on the remote host; upload each from the mount: `ntn files create --filename <name>.png --content-type image/png < <mount>/<path>.png`.
