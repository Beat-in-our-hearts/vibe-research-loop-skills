---
name: init-workspace
description: Initialize a vibe-research-loop workspace in the current directory, or add this machine to an existing one, by following the setup prompts of the vibe-research-loop guide in order - the workspace itself, the Notion CLI and the project's Notion pages, and optionally Google Drive. Can also redo a single part.
disable-model-invocation: true
---

# Initialize a workspace

1. **Guide.** Find the vibe-research-loop guide in the home directory: `~/vibe-research-loop`, or `~/vibe-research-loop-zh` for the Chinese edition. If there is neither, ask the user to clone it there, and stop. Read its `README.md`; `<guide>` in its prompts means this directory.
2. **Machine.** Decide which case applies, and ask the user if it is unclear:

   | Situation | Case |
   |---|---|
   | The current directory is empty | First machine |
   | The workspace repository is cloned here, or the user gives its URL | Another machine, after cloning the repository here if needed |

3. **Parts.** Do the parts below in order, each by following its prompt. If the user names only some parts, do only those; otherwise skip a part only if the user says it is done.

   | Part | First machine | Another machine |
   |---|---|---|
   | Workspace | "Set up a workspace" in `workspace_guide/workspace_prompts.md` | "Add a machine" in the same file |
   | Notion | "Set up Notion" in `notion_guide/notion_prompts.md`, following `notion_guide/operations.md` throughout | "Add a machine" in the same file |
   | Google Drive | Ask the user whether to use it; if so, "Set up Google Drive" in `gdrive_guide/gdrive_prompts.md` | "Add a machine" in the same file, if the workspace has `docs/AGENTS/drive.md` |

   The Chinese edition names these sections 搭建工作区, 配置 Notion, 配置 Google Drive, and 添加机器.
4. **Notion IDs.** After "Set up Notion", write `docs/notion/ids.md` in the workspace: a table with one row each for the project page, Ideas, Experiments, Findings, and Papers, giving its title and its page, database, and data source IDs. The research skills read it. Commit it as the workspace's git rules say.
5. **Report.** Show the user one table of the parts: what was created, what was skipped, and what is left for them, such as logging in to `ntn` or rclone, or the steps that need the Notion app. Then show the README's "After setup" table.
