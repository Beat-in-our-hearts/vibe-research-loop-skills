# Remote

**This machine computes on a remote host over SSH.** Agents are launched on the local machine, in the launch directory, which holds only the rules; every other file and every command of the workspace lives on the remote host. In the other rule files, "this machine" means the remote host.

| Item | Value |
|---|---|
| Local machine | <short name, and what it can run: e.g. 2 cores, 4 GB, no GPU> |
| Remote host | `ssh -p <port> <user>@<host>` |
| Control socket | `/tmp/vrl-ssh-%C` |
| Remote workspace | `<absolute path on the remote host>` |
| Mount | `<launch directory>/<mount>`, an SSHFS view of the remote workspace |
| tmux session | `<session>` on the remote host |

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
| Reading and editing files, remote ones through the mount; `ssh`; `ntn`; web requests such as paper searches; git of the launch directory | Everything else: git of the remote workspace and its repositories, Python, installs, smoke runs, training, evaluation, metrics, plotting, downloads, rclone, and resource checks |

- Never run a project command locally, and never point a local command at the mount to run it (`python <mount>/…`, `git -C <mount>/…`, `pip`, `chmod`, …).
- If the remote host or the mount is unreachable, stale, or read-only, stop and report. Never fall back to the local machine, never create a local stand-in for the mount, and remount only when the user asks.

## Connection

- Use one SSH master for the whole session. Check it with `ssh -S /tmp/vrl-ssh-%C -O check -p <port> <user>@<host>`, and only if none is usable, start one:

  ```bash
  ssh -MNf -o ControlMaster=yes -o ControlPersist=4h -o ControlPath=/tmp/vrl-ssh-%C -p <port> <user>@<host>
  ```

- Run every remote command through it, grouping related checks into one call; never open a fresh connection per command:

  ```bash
  ssh -S /tmp/vrl-ssh-%C -p <port> <user>@<host> 'cd <remote workspace> && set -a && . <remote workspace>/.env && set +a && <command>'
  ```

- Start anything that may take more than a minute detached, in its own window of the tmux session `<session>` on the remote host, and return at once with the window name and the log path; check on it later with short commands. Keep every local shell call under a minute, and never hold one open to wait.
- If the mount is missing, mount it through the same master, but only when the user asks:

  ```bash
  sshfs -p <port> -o ssh_command='ssh -S /tmp/vrl-ssh-%C -o BatchMode=yes -o ControlMaster=no' -o reconnect,idmap=user <user>@<host>:<remote workspace> <launch directory>/<mount>
  ```

- Keep host-key checking on, and stop on a changed host key. Never print, copy, or upload keys, tokens, or passwords.
- Stop only processes you started.

## Git

- The launch directory is the rules repository, holding `AGENTS.md` and `docs/AGENTS/`; git runs on it locally. The remote workspace root is the workspace repository, holding `docs/` and `tests/`; git runs on it on the remote host. Both follow the workspace repository rules in the git rules, each with its own remote, if any.
- `docs/AGENTS/machine.md` and this file describe one machine and stay out of the rules repository.

## Notion

- Run `ntn` locally. Take `docs/notion/ids.md` and the `TZ` of `.env` from the mount.
- <Only if the local machine has no OS keychain:> `ntn` keeps its login in a file: run it with `NOTION_KEYRING=0`, which the user's shell profile exports.
- Draw figures on the remote host; upload each from the mount: `ntn files create --filename <name>.png --content-type image/png < <mount>/<path>.png`.
