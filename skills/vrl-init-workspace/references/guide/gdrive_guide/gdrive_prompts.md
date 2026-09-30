# Google Drive prompts

Prompts for AI coding agents that keep a workspace's datasets, runs, and logs on Google Drive, one per section. Drive is optional: skip this guide if the workspace does not use it. When the user asks for a section's task, follow its steps in order; `<guide>` is the root of this repository.

## Set up Google Drive

Use this once per workspace, after "Set up a workspace".

1. **Folder.** Ask the user for the workspace's Drive folder, as `<rclone remote>:<folder>`, and wait for the answer.
2. **rclone.** Ask the user to install rclone and set up the remote on this machine themselves, since the login holds their token. Then check that `rclone lsd <rclone remote>:` works, and create the folder with `rclone mkdir <rclone remote>:<folder>` if it does not exist.
3. **Rule file.** Write `docs/AGENTS/drive.md` from `<guide>/gdrive_guide/docs/AGENTS/drive.md`, in the working language and with the folder from step 1. Add its row to the index in `AGENTS.md`, after the git row:

   ```
   | @docs/AGENTS/drive.md | Checking a running job, or moving files to or from Google Drive |
   ```

4. **Commit and report.** Commit and push the workspace repository, and tell the user what is set up.

## Add a machine

Use this on another machine of a workspace that uses Drive, after "Add a machine" in the workspace prompts: do step 2 of "Set up Google Drive". The rule file and its index row come with the workspace repository.
