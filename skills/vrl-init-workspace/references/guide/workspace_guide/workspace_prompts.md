# Workspace prompts

Prompts for AI coding agents in a workspace, one per section. When the user asks for a section's task, follow its steps in order.

## Set up a workspace

The workspace is the directory you were launched from; `<guide>` is the root of this repository. Never overwrite an existing file: if one is already there, show the user the difference and ask.

1. **Preferences.** Ask the user for the settings below, or for rules of their own, and wait for the answer.

   | Setting | Default | Covers |
   |---|---|---|
   | Reply language | Simplified Chinese | Every message to the user |
   | Working language | English | Reasoning and planning, and every file you write, the rule files included |
   | Code folder | `main_repo` | The folder the project's code repository is cloned into, for example named after the repository |
   | Git level for the code | Manual commit | Whether you commit and push code on your own: manual commit, auto commit, or auto push |
   | Workspace remote | None | A private remote for the workspace repository, needed to share it with other machines |
   | Time zone | UTC | Every time agents write, in logs, reports, and Notion; an IANA name of the form `Area/City` |

2. **Workspace.** Create the folders in the tree of `<guide>/workspace_guide/docs/AGENTS/file_structure.md`, except those named with a `<placeholder>`. Make the workspace root a git repository on branch `main` with this `.gitignore`, and add the remote if the user gave one:

   ```gitignore
   /*
   !/.gitignore
   !/AGENTS.md
   !/docs/
   !/tests/
   /docs/AGENTS/machine.md
   __pycache__/
   .pytest_cache/
   ```

3. **Rule files.** Write the workspace's `AGENTS.md`, `.env`, and `docs/AGENTS/` from the template in `<guide>/workspace_guide/`, and revise them yourself to fit step 1:
   - write them in the working language, translating the template where needed, and keep every file name and path unchanged, except that `main_repo` becomes the code folder's name everywhere;
   - make `docs/AGENTS/language_rules.md` state the two languages, or the user's own rules, `docs/AGENTS/git.md` the git level, and `docs/AGENTS/environment.md` the time zone;
   - in `.env`, replace `/path/to/workspace` with the workspace's absolute path and `Area/City` with the time zone;
   - keep the meaning of every other rule, one topic per file, and no file in `docs/AGENTS/` mentioning another;
   - keep `AGENTS.md` listing every file in `docs/AGENTS/`, each as an `@` import with the task that needs it.
4. **This machine.** Probe the machine: the GPUs with `nvidia-smi`, the CPU and memory limits (a container's, if any), the storage and its quota (if any), the scheduler (if any), and the network. Fill in `docs/AGENTS/machine.md`, with the short hostname as the name unless the user gives one, and ask the user to confirm it.
5. **Code repository.** Ask the user for the URL of the project's code repository and clone it into the code folder; if there is none yet, leave the folder empty.
6. **Check.** Look for a `CLAUDE.md` in the workspace or any directory above it, other than `~/.claude/CLAUDE.md`. If there is one, Claude Code reads it instead of `AGENTS.md`, so tell the user to add the line `@AGENTS.md` to it. Also look for an `AGENTS.md` in any directory above the workspace: an agent may load it too, so show the user every rule in it that disagrees with the workspace's.
7. **Commit.** Commit the workspace repository, and push it if it has a remote.
8. **Report.** Show the user the folder tree, the settings now in force, and what you changed from the template. Tell them to start a new session from the workspace root so that `AGENTS.md` loads, and that an agent can redo steps 1 and 3 of this prompt, read from `<guide>`, to change a setting later; renaming the code folder also means stopping the jobs that run from it, moving it, and running `git -C <new name> worktree repair`.

## Add a machine

Use this on another machine after the workspace repository has been cloned into the directory you were launched from; `<guide>` is the root of this repository.

1. **Folders.** Create the folders of the tree that the clone lacks, except those named with a `<placeholder>`.
2. **This machine.** Write this machine's `.env` from `<guide>/workspace_guide/.env` with the workspace's absolute path and the time zone in `docs/AGENTS/environment.md`. Probe the machine as in step 4 of "Set up a workspace", fill in `docs/AGENTS/machine.md` from `<guide>/workspace_guide/docs/AGENTS/machine.md` in the working language, and ask the user to confirm it.
3. **Code repository.** Ask the user for the URL of the project's code repository, and clone it into the code folder named in `docs/AGENTS/file_structure.md`.
4. **Check and report.** Do steps 6 and 8 of "Set up a workspace".
