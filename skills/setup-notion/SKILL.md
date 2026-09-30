---
name: setup-notion
description: Set up the Notion side of the vibe research loop, meaning the Literature Library, the project page, its databases, and their templates, or connect this machine to it, by following the Notion prompts of the vibe-research-loop guide.
disable-model-invocation: true
---

# Set up Notion

1. **Guide.** Find the vibe-research-loop guide in the home directory: `~/vibe-research-loop`, or `~/vibe-research-loop-zh` for the Chinese edition. If there is neither, ask the user to clone it there, and stop.
2. **Prompt.** Follow the prompt in `notion_guide/notion_prompts.md` that fits, and `notion_guide/operations.md` throughout:

   | Situation | Prompt |
   |---|---|
   | The first machine | Set up Notion (配置 Notion in the Chinese edition) |
   | Another machine of a workspace whose Notion is set up | Add a machine (添加机器) |

3. **IDs.** After "Set up Notion", write `docs/notion/ids.md` in the workspace: a table with one row each for the project page, Ideas, Experiments, Findings, and Papers, giving its title and its page, database, and data source IDs. The research skills read it. Commit it as the workspace's git rules say; if the current directory is not a workspace, give the user the table instead.
