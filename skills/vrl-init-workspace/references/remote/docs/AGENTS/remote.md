# Remote

**This machine computes on a remote host over SSH.** Agents are launched on the local machine, in the launch directory, which holds only the rules; every other file of the workspace lives on the remote host, and every workspace command runs there, apart from the few that the table under "Where commands run" keeps local. In the other rule files, "this machine" means the remote host.

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
| Reading and editing files, remote ones through the mount; `ssh`; `ntn`; web requests such as paper searches; git of the launch directory | Everything else: git of the remote workspace and its repositories, Python, installs, smoke runs, training, evaluation, metrics, plotting, downloads, `hf`, and resource checks |

- Never run a project command locally, and never point a local command at the mount to run it (`python <mount>/…`, `git -C <mount>/…`, `pip`, `chmod`, …).
- If the remote host or the mount is unreachable, stale, or read-only, and the steps under "Connection" do not bring it back, stop and report. Never fall back to the local machine, never create a local stand-in for the mount, and remount only when the user asks.

## Connection

One SSH master carries the whole session: every command and the mount. A command through it opens a channel in that one connection and does not log in again, so many short commands cost nothing extra.

- Check the connection with a round trip before the first remote command of a task, and whenever a command fails or does not return. `ssh -O check` is not enough: it only sees that the local master process exists, not that the remote host answers.

  ```bash
  ssh -n -o BatchMode=yes -o ConnectTimeout=10 -S /tmp/vrl-ssh-%C -p <port> <user>@<host> true
  ```

- If the check fails, close the dead master and start a new one. Its heartbeats make it exit within about 45 seconds of the connection dying, instead of hanging on. If logging in asks for a password, a passphrase, or a second factor, ask the user to run the start command in their own terminal, and wait.

  ```bash
  ssh -S /tmp/vrl-ssh-%C -O exit -p <port> <user>@<host>
  ssh -MNf -o ControlMaster=yes -o ControlPersist=4h -o ControlPath=/tmp/vrl-ssh-%C -o ServerAliveInterval=15 -o ServerAliveCountMax=3 -o ConnectTimeout=10 -p <port> <user>@<host>
  ```

- Run every remote command through the master, grouping related checks into one call:

  ```bash
  ssh -n -o BatchMode=yes -o ConnectTimeout=10 -S /tmp/vrl-ssh-%C -p <port> <user>@<host> 'cd <remote workspace> && set -a && . <remote workspace>/.env && set +a && timeout 50 <command>'
  ```

  - `-n` gives the command no input, `BatchMode=yes` makes ssh fail at once instead of logging in again or asking for a password when the master is gone, and `timeout 50` ends a step that hangs on the remote host. Put `timeout 50` in front of each step that could hang, such as a download or a git command that talks to a server.
  - Never run a command that waits for input: pass its non-interactive option, such as `-y` or `git commit -m`. Only a script piped into `bash -s` goes without `-n`, since it needs the input.
  - For a command too long or too nested to quote, write it as a script under `tmp/` through the mount, and run it with `timeout 50 bash <remote workspace>/tmp/<script>`.
- Start anything that may take more than a minute detached, in its own window of the tmux session `<session>` on the remote host, and return at once with the window name and the log path; check on it later with short commands. Keep every local shell call under a minute, and never hold one open to wait.
- Before reading or writing through the mount, run the round trip above and check that `mount` lists `<launch directory>/<mount>`. Neither touches the mount, while reading a mount whose connection is dead can hang, the file tools included. While the connection is down, touch nothing under the mount; repair the connection first.
- If the mount is missing, or still fails once the connection is back, mount it again through the master, but only when the user asks. Unmount a stale one first, with `fusermount -u <launch directory>/<mount>` on Linux or `umount <launch directory>/<mount>` on macOS:

  ```bash
  sshfs -p <port> -o ssh_command='ssh -S /tmp/vrl-ssh-%C -o BatchMode=yes -o ControlMaster=no' -o reconnect,ServerAliveInterval=15,ServerAliveCountMax=3,idmap=user <user>@<host>:<remote workspace> <launch directory>/<mount>
  ```

- Keep host-key checking on, and stop on a changed host key. Never print, copy, or upload keys, tokens, or passwords.
- Stop only processes you started.

## Git

- The launch directory is the rules repository, holding `AGENTS.md` and `docs/AGENTS/`; the remote workspace root is the workspace repository, holding `docs/` and `tests/`. Both follow the workspace repository rules in the git rules, each with its own remote, if any.
- `docs/AGENTS/machine.md` and this file describe one machine and stay out of the rules repository.

## Notion

- Run `ntn` locally. Take `docs/notion/ids.md` and the `TZ` of `.env` from the mount.
- <Only if the local machine has no OS keychain:> `ntn` keeps its login in a file: run it with `NOTION_KEYRING=0`, which the user's shell profile exports.
- Draw figures on the remote host; upload each from the mount: `ntn files create --filename <name>.png --content-type image/png < <mount>/<path>.png`.
