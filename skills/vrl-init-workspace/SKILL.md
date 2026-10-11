---
name: vrl-init-workspace
description: Initialize a vibe-research-loop workspace in the current directory, or add this machine to one - the workspace, the memory store (Notion, or Feishu) with its CLI and pages, and optionally a Hugging Face bucket - in local or remote (SSH) mode. Can also redo a single part.
disable-model-invocation: true
---

# Initialize a workspace

`<guide>` in a prompt means the bundled `references/guide/`, never a clone. Read its `README.md` first; in remote mode, also `remote_prompts.md` and `docs/AGENTS/remote.md` in `references/remote/`, and follow the latter once connected; with Feishu, `feishu_prompts.md` and `docs/AGENTS/feishu.md` in `references/feishu/`.

First run `bash <this skill's folder>/scripts/check_update.sh`; if it reports a newer release, ask the user whether to update first, and update only if they say so.

1. **Machine.** Decide the case and the mode; ask the user if either is unclear:

   | Situation | Case |
   |---|---|
   | The current directory is empty | First machine |
   | The workspace repository is here, or the user gives its URL | Another machine; clone it here if needed |

   | Situation | Mode |
   |---|---|
   | Jobs run on this machine | Local |
   | Jobs run on another host over SSH, as when this machine has no GPU | Remote |

2. **Questions.** Ask everything the parts need in one message, in the user's language, and wait for the answers:

   | Case | Questions |
   |---|---|
   | First machine | The settings in step 1 of "Set up a workspace", and in remote mode of "Set up a remote workspace"; the code repository URL, if any; the project's name and research question; Notion or Feishu; whether to keep datasets, runs, and logs in a Hugging Face bucket |
   | Another machine | The workspace repository URL, unless cloned here, and in remote mode what "Add a remote machine" asks for; the code repository URL, if any |

   Ask later only what depends on what you find.
3. **Tools.** Install and log in to `uv`, `ntn` (Notion), `lark-cli` (Feishu), `gh`, and `hf` only with `scripts/setup_clis.sh <check|install|login> --only <tools> [--workspace <dir>]`, also where a prompt asks the user to:

   | Where | Tools |
   |---|---|
   | Local mode | `uv`, the memory store's CLI, `gh`, and `hf` if the bucket is wanted |
   | Remote mode, this machine | The memory store's CLI, `gh` |
   | Remote host, once its workspace `<rw>` has a `.env`, in the background: `scripts/vrl_ssh.sh script <alias> --workspace <rw> --limit 0 -- setup_clis.sh <command> --only <tools> --workspace <rw>` | `uv`, and `hf` if the bucket is wanted |

   - Run `check` first and show the user its table; `install` what is missing only after they agree.
   - Run each `login` in the background: the memory store's CLI and `gh` right after installing them, `hf` in the Hugging Face part. Pass on its URL and code at once. Never ask for a token or pass one to a command.
   - Finish with `check`, and carry its notes into the report.
4. **Parts.** Do these parts in order, each by its prompt: only those the user names, if any, and skip one only if the user says it is done.

   | Part | First machine | Another machine |
   |---|---|---|
   | Workspace | "Set up a workspace" in [workspace_prompts.md](references/guide/workspace_guide/workspace_prompts.md); in remote mode, "Set up a remote workspace" in [remote_prompts.md](references/remote/remote_prompts.md) | "Add a machine" in the same file; in remote mode, "Add a remote machine" |
   | Memory store | "Set up Notion" in [notion_prompts.md](references/guide/notion_guide/notion_prompts.md), or "Set up Feishu" in [feishu_prompts.md](references/feishu/feishu_prompts.md) | "Add a machine" in the same file |
   | Hugging Face | If wanted, "Set up Hugging Face" in [hf_prompts.md](references/guide/hf_guide/hf_prompts.md) | "Add a machine" in the same file, if the workspace has `docs/AGENTS/hf.md` |

   In remote mode, also follow "Notion and Hugging Face in remote mode" in `remote_prompts.md`.
5. **Notion IDs.** After "Set up Notion", write `docs/notion/ids.md` with the header `| Object | Title in Notion | Page ID | Database ID | Data source ID |`: a row each for the project page and the Literature Library, with page IDs, and for Ideas, Experiments, Findings, and Papers, with database and data source IDs; `—` in the other cells. Commit it by the git rules.
6. **Report.** In place of the prompts' own reports, show one table of the tools and the parts: installed or created, skipped, or left for the user. Then show the README's "After setup" table without its row on reading the guide in the home directory. In remote mode, add that the local machine runs no code, and that the SSH master must be up before each session, started by `bash <VRL scripts>/vrl_ssh.sh connect <alias>`, path filled in.
