---
name: vrl-init-workspace
description: Initialize a vibe-research-loop workspace in the current directory, or add this machine to an existing one, by following the bundled guide's setup prompts in order - the workspace, the Notion CLI and the project's Notion pages, and optionally a Hugging Face bucket. Supports a remote mode, in which this machine keeps only the rules and computes on a remote host over SSH. Can also redo a single part.
disable-model-invocation: true
---

# Initialize a workspace

[references/guide/](references/guide/) holds the English edition of the vibe-research-loop guide, so the guide never needs to be cloned; `<guide>` in its prompts means that folder. Read its [README.md](references/guide/README.md) first.

[references/remote/](references/remote/) adds a remote mode, which the guide lacks: the agent runs on the local machine and computes on a remote host over SSH; the launch directory keeps only `AGENTS.md` and `docs/AGENTS/`, and every other file lives in a remote workspace, mounted in the launch directory with SSHFS. `<remote>` in its prompts means that folder. In remote mode, also read [remote_prompts.md](references/remote/remote_prompts.md) and [docs/AGENTS/remote.md](references/remote/docs/AGENTS/remote.md), and follow the latter once the connection is up.

At the start, run `bash <this skill's folder>/scripts/check_update.sh`. If it reports a newer release, tell the user, with the update command it prints, and ask whether to update before setting up; never update the skills unless the user asks.

1. **Machine.** Decide which case and which mode apply, and ask the user if either is unclear:

   | Situation | Case |
   |---|---|
   | The current directory is empty | First machine |
   | The workspace repository, or in remote mode the rules repository, is cloned here, or the user gives its URL | Another machine, after cloning the repository here if needed |

   | Situation | Mode |
   |---|---|
   | Jobs run on this machine | Local |
   | Jobs run on another host reached over SSH, for example because this machine has no GPU, or the user names an HPC or a remote server | Remote |

2. **Questions.** Ask the user everything the parts need in one message, in the language they write in, and wait for the answers:

   | Case | Questions |
   |---|---|
   | First machine | The settings in step 1 of "Set up a workspace", and in remote mode those in step 1 of "Set up a remote workspace"; the URL of the project's code repository, if there is one; the project's name and research question; whether to keep datasets, runs, and logs in a Hugging Face bucket |
   | Another machine | The URL of the workspace repository, if it is not cloned here yet, and in remote mode what "Add a remote machine" asks for; the URL of the project's code repository, if there is one |

   When a prompt asks for one of these, use the answer you have. Ask later only for what depends on what you find, such as confirming the machine profile, reusing an existing Notion page, or the steps that need the Notion app.
3. **Tools.** Install and log in to the CLIs with [scripts/setup_clis.sh](scripts/setup_clis.sh): it needs no sudo and puts everything in the user's home directory, every command in `~/.local/bin`, on macOS and Linux alike. A tool found only elsewhere, such as a Homebrew or apt copy, shows as `elsewhere`: `install` adds a copy in `~/.local/bin` and leaves the other alone. Run it as `setup_clis.sh <check|install|login> --only <tools> [--workspace <dir>]`. Wherever a prompt says to install or log in to `uv`, `ntn`, `gh`, or `hf`, or to ask the user to, use the script instead.

   | Mode | Where | Tools |
   |---|---|---|
   | Local | This machine | `uv`, `ntn`, `gh`, and `hf` if the user wants the bucket |
   | Remote | This machine | `ntn`, `gh` |
   | Remote | The remote host, once the SSH master is up: right after the Connection step of "Set up a remote workspace" or "Add a remote machine", run through the master as `ssh -o BatchMode=yes -o ConnectTimeout=10 -S /tmp/vrl-ssh-%C -p <port> <user>@<host> 'bash -s -- <command> --only <tools>' < scripts/setup_clis.sh` | `uv`, `gh`, and `hf` if the user wants the bucket |

   - Run `check` first and show the user its table; run `install` for what is missing only after they agree.
   - Run `login` in the background, since `gh` and `hf` wait until the user approves. Without a terminal, each login prints a URL and a one-time code: pass them to the user at once, as `hf`'s code expires in 5 minutes, and tell them to open the URL in any browser and check the code. Never ask for a token or pass one to a command.
   - Log in to `ntn` and `gh` right after installing them, and to `hf` in the Hugging Face part, once the workspace's `.env` exists. Pass `--workspace` only to that `hf` login, with the workspace, in remote mode the remote one, since its `XDG_CACHE_HOME` decides where `hf` keeps the login; before `.env` exists, the script refuses the `hf` login.
   - Finish with `check`, and carry its notes, such as a `PATH` line or `NOTION_KEYRING=0` for the shell profile, into the report.
4. **Parts.** Do the parts below in order, each by following its prompt. If the user names only some parts, do only those; otherwise skip a part only if the user says it is done.

   | Part | First machine | Another machine |
   |---|---|---|
   | Workspace | "Set up a workspace" in [workspace_prompts.md](references/guide/workspace_guide/workspace_prompts.md); in remote mode, "Set up a remote workspace" in [remote_prompts.md](references/remote/remote_prompts.md) | "Add a machine" in the same file; in remote mode, "Add a remote machine" |
   | Notion | "Set up Notion" in [notion_prompts.md](references/guide/notion_guide/notion_prompts.md) | "Add a machine" in the same file |
   | Hugging Face | If the user wants it, "Set up Hugging Face" in [hf_prompts.md](references/guide/hf_guide/hf_prompts.md) | "Add a machine" in the same file, if the workspace has `docs/AGENTS/hf.md` |

   In remote mode, `ntn` runs on the local machine and `hf` on the remote host; `.env` and `docs/notion/ids.md` are in the remote workspace, reached through the mount. Follow "Notion and Hugging Face in remote mode" in [remote_prompts.md](references/remote/remote_prompts.md) alongside the Notion and Hugging Face prompts.
5. **Notion IDs.** After "Set up Notion", write `docs/notion/ids.md` in the workspace with the header `| Object | Title in Notion | Page ID | Database ID | Data source ID |`: one row each for the project page and the Literature Library, with their page IDs, and for Ideas, Experiments, Findings, and Papers, with their database and data source IDs; put `—` in the cells that do not apply. The research skills read it. Commit it as the workspace's git rules say.
6. **Report.** Show the user one table of the tools and the parts, in place of the prompts' own reports: what was installed or created, what was skipped, and what is left for them, such as a login they have not approved yet, the script's notes, or the steps that need the Notion app. Then show the README's "After setup" table, leaving out its row on reading the guide in the home directory. In remote mode, also say that the mount must be up before a session starts, and give the command that remounts it.
