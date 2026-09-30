---
name: setup-workspace
description: Set up a vibe-research-loop agent workspace in the current directory, or add this machine to an existing one, by following the workspace prompts of the vibe-research-loop guide.
disable-model-invocation: true
---

# Set up a workspace

1. **Guide.** Find the vibe-research-loop guide in the home directory: `~/vibe-research-loop`, or `~/vibe-research-loop-zh` for the Chinese edition. If there is neither, ask the user to clone it there, and stop.
2. **Prompt.** Read the guide's `README.md`, then pick the prompt in `workspace_guide/workspace_prompts.md`:

   | Situation | Prompt |
   |---|---|
   | A new workspace, in an empty directory | Set up a workspace (搭建工作区 in the Chinese edition) |
   | Another machine: the workspace repository is cloned here, or the user gives its URL | Add a machine (添加机器), after cloning the repository here if needed |

3. **Setup.** Follow the prompt's steps in order, with `<guide>` meaning the guide's directory. Then show the user the README's "After setup" table.
4. **Next.** Ask the user whether to set up Notion now with setup-notion, and Google Drive with setup-gdrive if they want it.
