---
name: setup-gdrive
description: Optionally keep a vibe-research-loop workspace's datasets, runs, and logs on Google Drive with rclone, or connect this machine to the workspace's Drive folder, by following the Google Drive prompts of the vibe-research-loop guide.
disable-model-invocation: true
---

# Set up Google Drive

Drive is optional: set it up only when the user wants it.

1. **Guide.** Find the vibe-research-loop guide in the home directory: `~/vibe-research-loop`, or `~/vibe-research-loop-zh` for the Chinese edition. If there is neither, ask the user to clone it there, and stop.
2. **Prompt.** Follow the prompt in `gdrive_guide/gdrive_prompts.md` that fits:

   | Situation | Prompt |
   |---|---|
   | The workspace is set up and does not use Drive yet | Set up Google Drive (配置 Google Drive in the Chinese edition) |
   | Another machine of a workspace that uses Drive | Add a machine (添加机器) |
