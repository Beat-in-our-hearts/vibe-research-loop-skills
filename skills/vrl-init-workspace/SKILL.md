---
name: vrl-init-workspace
description: Initialize a vibe-research-loop workspace in the current directory, or add this machine to one - the workspace, the memory store (Notion, or Feishu) with its CLI and pages, and optionally a Hugging Face bucket - in local or remote (SSH) mode. Can also redo a single part.
disable-model-invocation: true
---

# Initialize a workspace

[references/guide/](references/guide/) is the bundled English guide: never clone the guide; `<guide>` in its prompts means that folder. Read its [README.md](references/guide/README.md) first. In remote mode, also read [remote_prompts.md](references/remote/remote_prompts.md) and [docs/AGENTS/remote.md](references/remote/docs/AGENTS/remote.md) in [references/remote/](references/remote/), and follow the latter once the connection is up. To keep the research memory in Feishu (飞书, the China edition) instead of Notion, read [feishu_prompts.md](references/feishu/feishu_prompts.md) and [docs/AGENTS/feishu.md](references/feishu/docs/AGENTS/feishu.md) in [references/feishu/](references/feishu/).

At the start, run `bash <this skill's folder>/scripts/check_update.sh`. If it reports a newer release, tell the user, with the update command it prints, and ask whether to update before setting up; never update the skills unless the user asks.

1. **Machine.** Decide the case and the mode; ask the user if either is unclear:

   | Situation | Case |
   |---|---|
   | The current directory is empty | First machine |
   | The workspace repository is cloned here, or the user gives its URL | Another machine, after cloning the repository here if needed |

   | Situation | Mode |
   |---|---|
   | Jobs run on this machine | Local |
   | Jobs run on another host over SSH, for example when this machine has no GPU or the user names an HPC or remote server | Remote |

2. **Questions.** Ask everything the parts need in one message, in the user's language, and wait for the answers:

   | Case | Questions |
   |---|---|
   | First machine | The settings in step 1 of "Set up a workspace", and in remote mode those in step 1 of "Set up a remote workspace"; the code repository URL, if any; the project's name and research question; Notion or Feishu; whether to keep datasets, runs, and logs in a Hugging Face bucket |
   | Another machine | The workspace repository URL, unless it is cloned here, and in remote mode what "Add a remote machine" asks for; the code repository URL, if any |

   Use these answers when a prompt asks for them. Ask later only what depends on what you find, such as confirming the machine profile, reusing a Notion page or Feishu node, or the steps that need the Notion app.
3. **Tools.** Install and log in to the CLIs below with [scripts/setup_clis.sh](scripts/setup_clis.sh) `<check|install|login> --only <tools> [--workspace <dir>]`, and use it wherever a prompt says to install or log in to `uv`, `ntn`, `lark-cli`, `gh`, or `hf`, or to ask the user to. It needs no sudo and installs into `~/.local/bin`, beside any copy it shows as `elsewhere`, such as a Homebrew one. The memory store's CLI is `ntn` for Notion, `lark-cli` for Feishu.

   | Mode | Where | Tools |
   |---|---|---|
   | Local | This machine | `uv`, the memory store's CLI, `gh`, and `hf` if the user wants the bucket |
   | Remote | This machine: always pass `--only` with these tools, since the script refuses `uv` and `hf` here only once `docs/AGENTS/remote.md` exists | The memory store's CLI, `gh` |
   | Remote | The remote host, once the remote workspace's `.env` exists, in the background through the master: `scripts/vrl_ssh.sh script <alias> --workspace <remote workspace> --limit 0 -- setup_clis.sh <command> --only <tools> --workspace <remote workspace>` | `uv`, and `hf` if the user wants the bucket |

   - Run `check` first and show the user its table; `install` what is missing only after they agree.
   - Run each `login` in the background, as it waits for the user's approval: the memory store's CLI and `gh` right after installing them, `hf` in the Hugging Face part. Pass on the URL and one-time code it prints at once, as `hf`'s code expires in 5 minutes, for the user to open in any browser and check the code. Never ask for a token or pass one to a command.
   - Pass `--workspace` to the local `hf` login too; the script refuses it until the workspace's `.env`, which sets `XDG_CACHE_HOME`, exists.
   - Finish with `check`, and carry its notes, such as a `PATH` line or `NOTION_KEYRING=0` for the shell profile, into the report.
4. **Parts.** Do these parts in order, each by its prompt. If the user names some parts, do only those; otherwise skip a part only if the user says it is done.

   | Part | First machine | Another machine |
   |---|---|---|
   | Workspace | "Set up a workspace" in [workspace_prompts.md](references/guide/workspace_guide/workspace_prompts.md); in remote mode, "Set up a remote workspace" in [remote_prompts.md](references/remote/remote_prompts.md) | "Add a machine" in the same file; in remote mode, "Add a remote machine" |
   | Memory store | "Set up Notion" in [notion_prompts.md](references/guide/notion_guide/notion_prompts.md), or with Feishu "Set up Feishu" in [feishu_prompts.md](references/feishu/feishu_prompts.md) | "Add a machine" in the same file |
   | Hugging Face | If wanted, "Set up Hugging Face" in [hf_prompts.md](references/guide/hf_guide/hf_prompts.md) | "Add a machine" in the same file, if the workspace has `docs/AGENTS/hf.md` |

   In remote mode, follow "Notion and Hugging Face in remote mode" in [remote_prompts.md](references/remote/remote_prompts.md) alongside those prompts; `ntn` and `lark-cli` use the local IDs file, `docs/notion/ids.md` or `docs/feishu/ids.md`, and the `TZ` of the local `.env`.
5. **Notion IDs.** With Feishu, skip this step. After "Set up Notion", write `docs/notion/ids.md` with the header `| Object | Title in Notion | Page ID | Database ID | Data source ID |` and one row each: the project page and the Literature Library with their page IDs; Ideas, Experiments, Findings, and Papers with their database and data source IDs; `—` in the cells that do not apply. Commit it as the workspace's git rules say.
6. **Report.** In place of the prompts' own reports, show one table of the tools and the parts: what was installed or created, skipped, or left for the user, such as an unapproved login, the script's notes, or the steps that need the Notion app. Then show the README's "After setup" table without its row on reading the guide in the home directory. In remote mode, add that the local machine runs no code and that the SSH master must be up before a session starts, started by `bash <VRL scripts>/vrl_ssh.sh connect <alias>` with its path filled in.
