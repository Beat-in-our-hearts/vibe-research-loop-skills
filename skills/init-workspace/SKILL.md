---
name: init-workspace
description: Initialize a vibe-research-loop workspace in the current directory, or add this machine to an existing one, by following the setup prompts of the bundled vibe-research-loop guide in order - the workspace itself, the Notion CLI and the project's Notion pages, and optionally Google Drive. Can also redo a single part.
disable-model-invocation: true
---

# Initialize a workspace

This skill carries the English edition of the vibe-research-loop guide in [references/guide/](references/guide/), so the guide never needs to be cloned; `<guide>` in its prompts means that folder. Read its [README.md](references/guide/README.md) first.

1. **Machine.** Decide which case applies, and ask the user if it is unclear:

   | Situation | Case |
   |---|---|
   | The current directory is empty | First machine |
   | The workspace repository is cloned here, or the user gives its URL | Another machine, after cloning the repository here if needed |

2. **Parts.** Do the parts below in order, each by following its prompt. If the user names only some parts, do only those; otherwise skip a part only if the user says it is done.

   | Part | First machine | Another machine |
   |---|---|---|
   | Workspace | "Set up a workspace" in [workspace_prompts.md](references/guide/workspace_guide/workspace_prompts.md) | "Add a machine" in the same file |
   | Notion | "Set up Notion" in [notion_prompts.md](references/guide/notion_guide/notion_prompts.md) | "Add a machine" in the same file |
   | Google Drive | Ask the user whether to use it; if so, "Set up Google Drive" in [gdrive_prompts.md](references/guide/gdrive_guide/gdrive_prompts.md) | "Add a machine" in the same file, if the workspace has `docs/AGENTS/drive.md` |

3. **Notion IDs.** After "Set up Notion", write `docs/notion/ids.md` in the workspace: a table with one row each for the project page, Ideas, Experiments, Findings, and Papers, giving its title and its page, database, and data source IDs. The research skills read it. Commit it as the workspace's git rules say.
4. **Report.** Show the user one table of the parts: what was created, what was skipped, and what is left for them, such as logging in to `ntn` or rclone, or the steps that need the Notion app. Then show the README's "After setup" table, leaving out its row on reading the guide in the home directory, which does not apply here.
