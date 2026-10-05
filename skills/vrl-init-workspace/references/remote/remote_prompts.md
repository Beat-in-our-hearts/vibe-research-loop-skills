# Remote prompts

Prompts for a workspace that computes on a remote host over SSH: the agent runs on the local machine, in the launch directory, which keeps only the rules (`AGENTS.md` and `docs/AGENTS/`); every other file and every command lives on the remote host. `<guide>` is the bundled guide, `<remote>` the directory of this file, and [`docs/AGENTS/remote.md`](docs/AGENTS/remote.md) the rule file these prompts write. Never overwrite an existing file, locally or remotely: if one is already there, show the user the difference and ask.

## Set up a remote workspace

Follow "Set up a workspace" in `<guide>/workspace_guide/workspace_prompts.md`, with these changes to its steps.

1. **Preferences.** Ask for these settings too, together with that step's:

   | Setting | Default | Covers |
   |---|---|---|
   | SSH target | — | `ssh -p <port> <user>@<host>`; the user sets up the login and keys themselves |
   | Remote workspace | — | The absolute path on the remote host that holds every file but the rules; it must exist |
   | Mount | `hpc_workspace` | The folder in the launch directory where the remote workspace is mounted with SSHFS |
   | tmux session | `vrl` | The remote tmux session for long-running commands |
   | Rules remote | None | A private remote for the rules repository, besides the workspace remote |
   | Existing host rules | None | Rule files that already describe this host or this user's habits, such as an older `AGENTS.md`, to carry over |

2. **Connection.** Before creating anything, start or reuse the SSH master as in `<remote>/docs/AGENTS/remote.md`, and check in one call: `hostname`; `whoami`; that the remote workspace exists, is writable, and lists nothing the user did not expect; that `git` and `tmux` are on the remote host; and whether git has a user name and email there. Check that `sshfs` is on the local machine. If anything is missing, ask the user; never install on either side without their approval. If git has no identity on the remote host, ask the user which name and email to commit under, and set them in the workspace repository only.
   - If the remote host reaches some services only through a proxy, such as GitHub or model hubs, ask the user how to turn it on, record it in `docs/AGENTS/machine.md` in step 5, and start the tmux session from a shell where it is on, so that every window inherits it.
3. **Folders.** In place of step 2 of the guide's prompt:
   - On the remote host, create the folders of the tree in `<guide>/workspace_guide/docs/AGENTS/file_structure.md` other than `docs/AGENTS/` and those named with a `<placeholder>`, and make the remote workspace a git repository on branch `main` with this `.gitignore`, adding the workspace remote if the user gave one:

     ```gitignore
     /*
     !/.gitignore
     !/docs/
     !/tests/
     __pycache__/
     .pytest_cache/
     ```

   - Locally, create `docs/AGENTS/` and the mount folder in the launch directory, and make it a git repository on branch `main` with this `.gitignore`, adding the rules remote if the user gave one:

     ```gitignore
     /*
     !/.gitignore
     !/AGENTS.md
     !/docs/
     /docs/AGENTS/machine.md
     /docs/AGENTS/remote.md
     ```

   - Mount the remote workspace with the `sshfs` command in `<remote>/docs/AGENTS/remote.md`, and check that a file written through the mount appears on the remote host; then delete that file.
4. **Rule files.** Do step 3 of the guide's prompt, writing `AGENTS.md` and `docs/AGENTS/` in the launch directory and `.env` in the remote workspace, with the remote workspace's absolute path in place of `/path/to/workspace`. Then:
   - write `docs/AGENTS/remote.md` from `<remote>/docs/AGENTS/remote.md` in the working language, with every setting filled in, and add its row to the index in `AGENTS.md`, right after the language rules:

     ```
     | @docs/AGENTS/remote.md | Anything, on a machine that has this file: it says where each file lives and where each command runs |
     ```

   - read the existing host rules, if any: carry their facts about the remote host, such as quotas, cgroup limits, the system disk, cache traps, and GPU assignment, into `docs/AGENTS/machine.md` in the next step; carry the user's own working rules, such as code editing rules, into `AGENTS.md` as their strict rules; and show the user what you carried over and what you left out, such as paths of another workspace or a rule the guide already covers.
5. **This machine.** Do step 4 of the guide's prompt on the remote host, through the SSH master. Measure the real limits, not host-wide numbers: the container's cgroup limits for CPU and memory, the quota of the filesystem that holds the remote workspace, and the free space of the system disk. Container hostnames change when the host is reprovisioned, so ask the user for a short name.
6. **Code repository.** Do step 5 of the guide's prompt on the remote host.
7. **Check.** Do step 6 of the guide's prompt in the launch directory.
8. **Commit.** Commit the rules repository locally, and the workspace repository on the remote host; push each that has a remote. The workspace repository pushes from the remote host, which needs its own access to that remote: if it has none, log in to `gh` there with the skill's `scripts/setup_clis.sh` (`login --only gh`), which also lets git use that login; never handle the user's token.
9. **Report.** Do step 8 of the guide's prompt, showing both trees, and add the `sshfs` command to remount after a reboot.

## Notion and Hugging Face in remote mode

Use this with "Set up Notion" and "Set up Hugging Face" of the guide, or their "Add a machine" sections, on a remote-mode machine.

- **Notion.** `ntn` runs on the local machine. If that machine has no OS keychain, as on a headless server, `ntn` stores its token in a file instead: the skill's `scripts/setup_clis.sh` detects this and logs in with `NOTION_KEYRING=0`. Ask the user to export `NOTION_KEYRING=0` in their shell profile, run `ntn` with it from then on, and record this under Notion in `docs/AGENTS/remote.md`.
- **Hugging Face.** Run every `hf` command on the remote host, which has no browser, with the remote workspace's `.env` loaded. Install and log in to `hf` there with the skill's `scripts/setup_clis.sh`, through the SSH master, with `--workspace` set to the remote workspace so that it loads that `.env`; the login prints a URL and a code, which the user opens on any machine with a browser.

## Add a remote machine

Use this when another launch directory, or another remote host, joins a workspace that is already set up. Ask the user for the settings in step 1 of "Set up a remote workspace" other than Existing host rules, and for the URLs of the rules and workspace repositories.

1. **Connection.** Do step 2 of "Set up a remote workspace".
2. **Repositories.** Clone the rules repository into the launch directory, and, on the remote host, the workspace repository into the remote workspace. Create the folders the clones lack, as in step 3 of "Set up a remote workspace", and mount the remote workspace.
3. **This machine.** Write the remote workspace's `.env` as in "Add a machine" in `<guide>/workspace_guide/workspace_prompts.md`, then `docs/AGENTS/remote.md` as in step 4 of "Set up a remote workspace", and fill in `docs/AGENTS/machine.md` as in its step 5.
4. **Code repository.** Clone it on the remote host into the code folder named in `docs/AGENTS/file_structure.md`.
5. **Check and report.** Do steps 7 and 9 of "Set up a remote workspace".
