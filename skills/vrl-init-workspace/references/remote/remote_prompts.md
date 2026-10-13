# Remote prompts

Prompts for a workspace that computes on a remote host over SSH. The agent runs on the local machine, at the workspace root, which keeps the rules, the plans, and all code, and runs none of it. The remote host runs every command that runs code, from mirrors of the local checkouts that `vrl_ssh.sh sync` writes, and keeps every result. `<guide>` is the bundled guide, `<remote>` the directory of this file, and [`docs/AGENTS/remote.md`](docs/AGENTS/remote.md) the rule file these prompts write. Never overwrite an existing file, locally or remotely: if one is already there, show the user the difference and ask.

## Set up a remote workspace

Follow "Set up a workspace" in `<guide>/workspace_guide/workspace_prompts.md`, with these changes to its steps.

1. **Preferences.** Ask for these settings too, together with that step's, and tell the user that remote mode copies only commits to the remote host: under the manual commit level, they commit, or let you commit, before each sync.

   | Setting | Default | Covers |
   |---|---|---|
   | SSH alias | — | A `Host` entry in the local `~/.ssh/config` that reaches the remote host, used as `ssh <alias>`; if the user has none, step 2 adds one. The user sets up the login and keys themselves |
   | Remote workspace | — | The absolute path on the remote host that holds the mirrors of the code and every result; it must exist, and serve this local machine only |
   | tmux session | `vrl` | The remote tmux session for long-running commands |
   | Existing host rules | None | Rule files that already describe this host or this user's habits, such as an older `AGENTS.md`, to carry over |

2. **Connection.** If the user has no alias yet, ask for the host name, user, port, and any jump host, show them the entry below, and with their approval append it to the local `~/.ssh/config`, creating the file with mode 600 if it does not exist. Never change an entry that is already there. Check with `vrl_ssh.sh resolve <alias>`, from the `scripts/` folder of the vrl-init-workspace skill, that the alias resolves to the host name, user, and port; it does not connect.

   ```
   Host <alias>
       HostName <host>
       User <user>
       Port <port>
       # ProxyJump <jump host>, only if the host is reached through one
   ```

   Before creating anything, start or reuse the SSH master with `vrl_ssh.sh connect <alias>`, as `<remote>/docs/AGENTS/remote.md` says, and check in one `vrl_ssh.sh run <alias> --workspace / --no-env` call: `hostname`; `whoami`; that the remote workspace exists, is writable, and lists nothing the user did not expect; and that `git` and `tmux` are on the remote host. Check that `git` and `jq` are on the local machine, which reads JSON with `jq`, never Python. If anything is missing, ask the user; never install on either side without their approval. From the seconds that `vrl_ssh.sh check <alias>` prints for its round trip, set the time limits of `docs/AGENTS/remote.md`: the check limit at five times that time, and at least 15 seconds; and the command limit at 60 seconds, kept at least 5 seconds below the agent's own time limit for a shell call. Tell the user the two values, which they may change.
   - If the remote host reaches some services only through a proxy, such as GitHub or model hubs, ask the user for its settings, and write them as lines such as `https_proxy=<...>` into the remote workspace's `.env` in step 4: every VRL script loads that file, every run too, and `vrl_ssh.sh` whenever it is given `--workspace`. Record the proxy in `docs/AGENTS/machine.md` in step 5.
3. **Folders.** In place of step 2 of the guide's prompt:
   - Here, at the workspace root, create the folders of the tree in `<guide>/workspace_guide/docs/AGENTS/file_structure.md` that hold rules, plans, tests, code, or drafts: `docs/AGENTS/`, `docs/plans/`, `tests/`, `worktrees/`, `ref_repos/`, `logs/`, and `tmp/`, never `.cache/`, `data/`, or `runs/`. Make the workspace root a git repository on branch `main` with this `.gitignore`, and add the remote if the user gave one:

     ```gitignore
     /*
     !/.gitignore
     !/AGENTS.md
     !/docs/
     !/tests/
     /docs/AGENTS/machine.md
     /docs/AGENTS/remote.md
     __pycache__/
     .pytest_cache/
     .DS_Store
     ```

   - On the remote host, with `vrl_ssh.sh run <alias> --workspace <remote workspace> --no-env`, create `.cache/`, `data/`, `logs/`, `runs/`, and `tmp/`. Create no repository there: `vrl_ssh.sh sync` makes the mirrors.
4. **Rule files.** Do step 3 of the guide's prompt here, writing `AGENTS.md`, `docs/AGENTS/`, and a local `.env` that holds only the `TZ` line. Write the remote workspace's `.env` from `<guide>/workspace_guide/.env` on the remote host, with `vrl_ssh.sh run <alias> --workspace <remote workspace> --no-env` and a heredoc, with the remote workspace's absolute path in place of `/path/to/workspace`, the time zone of the local `.env` in place of `Area/City`, any proxy from step 2, and the line `PYTHONPYCACHEPREFIX=<remote workspace>/.cache/pycache`, which keeps Python caches out of the mirrors. Then:
   - write `docs/AGENTS/remote.md` from `<remote>/docs/AGENTS/remote.md` in the working language, with every setting filled in, the time limits from step 2 included, and add its row to the index in `AGENTS.md`, right after the language rules:

     ```
     | @docs/AGENTS/remote.md | Anything, on a machine that has this file: it says where each file lives and where each command runs |
     ```

   - read the existing host rules, if any: carry their facts about the remote host, such as quotas, cgroup limits, the system disk, cache traps, and GPU assignment, into `docs/AGENTS/machine.md` in the next step; carry the user's own working rules, such as code editing rules, into `AGENTS.md` as their strict rules; and show the user what you carried over and what you left out, such as paths of another workspace or a rule the guide already covers;
   - set up the remote host's CLIs as the skill's Tools step says.
5. **This machine.** Do step 4 of the guide's prompt on the remote host, through the SSH master: run `resources.sh` there as `vrl_ssh.sh script <alias> --workspace <remote workspace> -- resources.sh`, and the other probes with `vrl_ssh.sh run`. The VRL scripts row names the `scripts/` folder on the local machine, where `vrl_ssh.sh` runs. The tmux session row names the remote session and the command that starts it unless it already runs, written as the whole local line, `bash <VRL scripts>/vrl_ssh.sh run <alias> --workspace <remote workspace> --limit <command limit> -- 'tmux has-session -t vrl 2>/dev/null || tmux new-session -d -s vrl -c <remote workspace>'`; start it with that line. Write the quota command in the same form, `bash <VRL scripts>/vrl_ssh.sh run <alias> --workspace <remote workspace> --limit <command limit> -- '<quota command>'`, so that both run exactly as written. Measure the real limits, not host-wide numbers: the container's cgroup limits for CPU and memory, the quota of the filesystem that holds the remote workspace, and the free space of the system disk. Container hostnames change when the host is reprovisioned, so ask the user for a short name.
6. **Code repository.** Do step 5 of the guide's prompt here. If it cloned a repository, check that no git hook or filter driver is active in the clone: `git config core.hooksPath` is unset, `.git/hooks/` holds only `*.sample` files, and `git config --get-regexp '^filter\.'` prints nothing. If one is, tell the user, since it runs code here at every commit. Then sync the code folder: `vrl_ssh.sh sync <alias> --workspace <remote workspace> --limit 0 -- <code folder>`, in the background. If the code folder stays empty, make it a repository of its own with `git init -b main <code folder>`, and tell the user that its code reaches the remote host only from its first commit, made by them or by you as the git level allows; sync it then.
7. **Check.** Do step 6 of the guide's prompt.
8. **Commit.** Do step 7 of the guide's prompt, then sync the workspace repository: `vrl_ssh.sh sync <alias> --workspace <remote workspace> -- .`.
9. **Report.** Do step 8 of the guide's prompt, showing the local tree and the remote folders, and add the command that reconnects after a reboot, with the VRL scripts path filled in: `bash <VRL scripts>/vrl_ssh.sh connect <alias>`, from the workspace root.

## Notion and Hugging Face in remote mode

Use this with "Set up Notion" or "Set up Feishu", and "Set up Hugging Face", or their "Add a machine" sections, on a remote-mode machine.

- **Notion.** `ntn` runs on the local machine. If that machine has no OS keychain, as on a headless server, `ntn` stores its token in a file instead: the skill's `scripts/setup_clis.sh` detects this and logs in with `NOTION_KEYRING=0`. Ask the user to export `NOTION_KEYRING=0` in their shell profile, run `ntn` with it from then on, and record this under Notion in `docs/AGENTS/remote.md`.
- **Feishu.** `lark-cli` runs on the local machine too. Without an OS keychain it keeps its login in encrypted files under `~/.local/share`, so it needs no setting.
- **Hugging Face.** Run every `hf` command on the remote host, which has no browser, with the remote workspace's `.env` loaded. Install and log in to `hf` there with the skill's `scripts/setup_clis.sh`, run as `vrl_ssh.sh script <alias> --workspace <remote workspace> --limit 0 -- setup_clis.sh login --only hf --workspace <remote workspace>` in the background, so that it loads that `.env`; the login prints a URL and a code, which the user opens on any machine with a browser.

## Add a remote machine

Use this when a new local machine joins a workspace that is already set up, with a remote workspace of its own: on another remote host, or in another folder of the same one. Two local machines never share one remote workspace, since its mirrors hold what one machine synced. Ask the user only for the settings in the table of step 1 of "Set up a remote workspace", other than Existing host rules, and for the URLs of the workspace and code repositories; the cloned rules already hold the guide's settings.

1. **Repositories.** Clone the workspace repository into the directory you were launched from, and the code repository, if there is one, into the code folder named in `docs/AGENTS/file_structure.md`, and check its git hooks as in step 6 of "Set up a remote workspace". A workspace first set up in local mode lacks two lines: if `.gitignore` does not ignore `/docs/AGENTS/remote.md`, or `AGENTS.md` has no row for it, add each as in steps 3 and 4 of "Set up a remote workspace", commit, and push. Never commit `docs/AGENTS/remote.md` itself. Create the local folders of its step 3 that the clones lack, and write the local `.env`, holding only the time zone in `docs/AGENTS/environment.md` as its `TZ` line.
2. **Connection.** Do step 2 of "Set up a remote workspace".
3. **Remote host.** Create the remote folders as in step 3 of "Set up a remote workspace"; if the remote workspace has no `.env` yet, write it as in its step 4; and set up the remote host's CLIs as the skill's Tools step says.
4. **Rule files.** Write `docs/AGENTS/remote.md` as in step 4 of "Set up a remote workspace", without its index row, which `AGENTS.md` has by now, and fill in `docs/AGENTS/machine.md` as in its step 5.
5. **Sync.** Sync the workspace repository, and the code folder if it has a commit: `vrl_ssh.sh sync <alias> --workspace <remote workspace> --limit 0 -- . <code folder>`, in the background.
6. **Check and report.** Do steps 7 and 9 of "Set up a remote workspace".
