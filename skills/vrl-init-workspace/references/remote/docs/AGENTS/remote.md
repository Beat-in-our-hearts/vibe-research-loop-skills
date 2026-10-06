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
| Check limit | `<check limit>` seconds: the local time limit of the connection check |
| Command limit | `<command limit>` seconds: the local time limit of a remote command; with the 5 seconds of grace that `-k 5` adds, it stays below the agent's own time limit for a shell call |
| Remote step limit | `<remote step limit>` seconds: the remote `timeout` of one step, the command limit minus 10 |

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

- Give every `ssh` call a local time limit from the table: the check limit for the check below, and the command limit for a command. A command through a half-dead master waits on the dead connection, and neither `ConnectTimeout` nor `BatchMode` applies to a channel in an existing connection. On macOS, use `gtimeout` from Homebrew's `coreutils`; where neither exists, the master's heartbeats still end the call within about a minute.
- Keep the command limit plus 5 seconds below the agent's own time limit for a shell call, such as 2 minutes by default in Claude Code: `-k 5` ends a call that ignores the first signal 5 seconds later, and past the agent's limit, the agent moves the call to the background or gives up on it instead of stopping it. A command that surely needs longer than the command limit, but not long enough for the tmux session, may get a longer limit for that call alone, still 5 seconds short of the agent's own; anything longer runs in the tmux session.
- Check the connection with a round trip before the first remote command of a task, and whenever a command fails or does not return. `ssh -O check` is not enough: it only sees that the local master process exists, not that the remote host answers.

  ```bash
  timeout -k 5 <check limit> ssh -n -o BatchMode=yes -o ConnectTimeout=10 -S /tmp/vrl-ssh-%C -p <port> <user>@<host> true
  ```

- If the check fails, close the dead master, then start a new one:
  1. Ask the master to exit: `timeout -k 5 <check limit> ssh -S /tmp/vrl-ssh-%C -O exit -p <port> <user>@<host>`.
  2. If it does not exit, end its process and delete its socket, the one process you may stop without having started it. Anchor the `pkill` pattern at both ends, as below: `pkill -f` matches whole command lines, and the shell that runs `pkill` holds the pattern in its own, so an unanchored pattern ends that shell too. Escape the dots of an IP address in `<host>` as `\.`. A socket left behind makes the new master skip multiplexing without failing; `ssh -G` prints the socket's real path without connecting:

     ```bash
     pkill -f -- '^ssh -MNf .*-p <port> <user>@<host>$'
     rm -f "$(ssh -G -o ControlPath=/tmp/vrl-ssh-%C -p <port> <user>@<host> | awk '/^controlpath /{print $2}')"
     ```

  3. Start the new master. Its heartbeats make it exit within about 45 seconds of the connection dying, instead of hanging on. If logging in asks for a password, a passphrase, or a second factor, ask the user to run this command in their own terminal, and wait.

     ```bash
     ssh -MNf -o ControlMaster=yes -o ControlPersist=4h -o ControlPath=/tmp/vrl-ssh-%C -o ServerAliveInterval=15 -o ServerAliveCountMax=3 -o ConnectTimeout=10 -p <port> <user>@<host>
     ```

- Run every remote command through the master, grouping related checks into one call:

  ```bash
  timeout -k 5 <command limit> ssh -n -o BatchMode=yes -o ConnectTimeout=10 -S /tmp/vrl-ssh-%C -p <port> <user>@<host> 'cd <remote workspace> && set -a && . <remote workspace>/.env && set +a && timeout <remote step limit> <command>'
  ```

  - The local `timeout` ends the call when the connection is dead, `-n` gives the command no input, `BatchMode=yes` makes ssh fail at once instead of logging in again or asking for a password when the master is gone, and `timeout <remote step limit>` ends a step that hangs on the remote host, early enough to return its output before the local limit cuts the call. In `a && b`, it covers only `a`: put it in front of each step that could hang, such as a download or a git command that talks to a server.
  - Never run a command that waits for input: pass its non-interactive option, such as `-y` or `git commit -m`. Only a script piped into `bash -s`, such as the setup script, goes without `-n`, since it needs the input, and gets the time limit its task needs instead of the command limit.
  - For a command too long or too nested to quote, write it as a script under `tmp/` through the mount, and run it with `timeout <remote step limit> bash <remote workspace>/tmp/<script>`.
- Run every `ssh` call, the check included, as a background call of the agent's shell tool where it has one, such as `run_in_background` in Claude Code, and end it with a local exit marker after the closing quote: `…'; echo "__EXIT $?"`. A shell tool can miss that a command has exited and keep the call open long after it finished, which no time limit on the command prevents; a background call returns at once, so a call the tool never releases cannot block the session. Read the call's output right after starting it:
  - The `__EXIT` line means the command finished, and gives its exit code, 124 when a `timeout` cut it: go on.
  - Without that line, the command is still running or the tool lost it: tell the user you are waiting for it and end the turn, instead of polling; read the output again when its completion notice arrives or the user writes.
  - If the line is there but the tool still lists the call as running, go on, and stop that call, such as with `TaskStop` in Claude Code.

  Run local commands in the foreground as usual.
- Start anything that may take longer than the command limit detached, in its own window of the tmux session `<session>` on the remote host, and return at once with the window name and the log path; check on it later with short commands. Keep every local shell call within the command limit, and never hold one open to wait.
- Before reading or writing through the mount, run the round trip above and check that `mount` lists `<launch directory>/<mount>`. Neither touches the mount, while reading a mount whose connection is dead can hang, the file tools included. While the connection is down, touch nothing under the mount; repair the connection first.
- If the mount is missing, or still fails once the connection is back, mount it again through the master, but only when the user asks. Unmount a stale one first, with `fusermount -u <launch directory>/<mount>` on Linux or `umount <launch directory>/<mount>` on macOS. The heartbeat options below matter only when sshfs falls back to a connection of its own because the master is gone; while the master is up, its own heartbeats cover the mount:

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
