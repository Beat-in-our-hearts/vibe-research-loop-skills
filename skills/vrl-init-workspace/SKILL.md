---
name: vrl-init-workspace
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

2. **Questions.** Ask the user everything the parts need in one message, in the language they write in, and wait for the answers:

   | Case | Questions |
   |---|---|
   | First machine | The settings in step 1 of "Set up a workspace"; the URL of the project's code repository, if there is one; the project's name and research question; whether to use Google Drive |
   | Another machine | The URL of the workspace repository, if it is not cloned here yet; the URL of the project's code repository, if there is one |

   When a prompt says to ask for one of these, use the answer you already have. Ask later only for what depends on what you find, such as confirming the machine profile, reusing an existing Notion page, or the steps that need the Notion app.
3. **Parts.** Do the parts below in order, each by following its prompt. If the user names only some parts, do only those; otherwise skip a part only if the user says it is done.

   | Part | First machine | Another machine |
   |---|---|---|
   | Workspace | "Set up a workspace" in [workspace_prompts.md](references/guide/workspace_guide/workspace_prompts.md) | "Add a machine" in the same file |
   | Notion | "Set up Notion" in [notion_prompts.md](references/guide/notion_guide/notion_prompts.md) | "Add a machine" in the same file |
   | Google Drive | If the user wants it, "Set up Google Drive" in [gdrive_prompts.md](references/guide/gdrive_guide/gdrive_prompts.md) | "Add a machine" in the same file, if the workspace has `docs/AGENTS/drive.md` |

4. **Notion IDs.** After "Set up Notion", write `docs/notion/ids.md` in the workspace with the header `| Object | Title in Notion | Page ID | Database ID | Data source ID |`: one row each for the project page and the Literature Library, with their page IDs, and for Ideas, Experiments, Findings, and Papers, with their database and data source IDs; put `—` in the cells that do not apply. The research skills read it. Commit it as the workspace's git rules say.
5. **Report.** Show the user one table of the parts, in place of the prompts' own reports: what was created, what was skipped, and what is left for them, such as logging in to `ntn` or rclone, or the steps that need the Notion app. Then show the README's "After setup" table, leaving out its row on reading the guide in the home directory, which does not apply here.
