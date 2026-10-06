# vibe-research-loop

A research workflow in which AI coding agents (Claude Code, Codex) run the experiment loop and humans make the decisions. Notion is the knowledge memory; this repository documents that system and holds the rules the agents follow.

| Directory | Contents |
|---|---|
| [`notion_guide/`](notion_guide/) | How the Notion workspace is organized: the databases, the page templates, how agents operate it, and the Notion setup prompt |
| [`workspace_guide/`](workspace_guide/) | The template agents build each workspace from: the setup prompts and the rule files (see [The workspace guide](#the-workspace-guide)) |
| [`hf_guide/`](hf_guide/) | Optional: keeping datasets, runs, and logs in a Hugging Face Storage Bucket with the `hf` CLI, with its setup prompts |

Changes to the Notion system start here: edit the documents, review the diff, then sync Notion to match (see [`notion_guide/operations.md`](notion_guide/operations.md)).

## Setting up

Clone this guide into your home directory, once per machine; every workspace on that machine reads it from there:

```bash
git clone <repository URL> ~/vibe-research-loop
```

Then start Codex or Claude Code in the empty directory that will be your workspace, and say:

`Read ~/vibe-research-loop/README.md and set everything up.`

On another machine of the same workspace, clone the guide there as well, start the agent in an empty directory, and say instead:

`Clone <workspace repository URL> here, read ~/vibe-research-loop/README.md, and add this machine.`

**Agents:** follow the matching prompts below in order; skip one only if the user says it is already done. In the prompts, `<guide>` is the directory of this README.

| Setup | Prompt |
|---|---|
| Workspace, first machine | "Set up a workspace" in [`workspace_guide/workspace_prompts.md`](workspace_guide/workspace_prompts.md) |
| Workspace, another machine | "Add a machine" in [`workspace_guide/workspace_prompts.md`](workspace_guide/workspace_prompts.md) |
| Notion | "Set up Notion" once, or "Add a machine" on another machine, in [`notion_guide/notion_prompts.md`](notion_guide/notion_prompts.md) |
| Hugging Face, only if the user wants it | "Set up Hugging Face", or "Add a machine" on another machine, in [`hf_guide/hf_prompts.md`](hf_guide/hf_prompts.md) |

After setup:

| Rule | Why |
|---|---|
| Start the agent from the workspace root, never from inside the code folder (`main_repo/` unless renamed at setup) | Codex reads AGENTS.md only from the git root down to the launch directory, and in workspace-write mode it writes only under the launch directory; Claude Code keeps its project config (`.claude/`) there too |
| If `runs/` or `.cache/` is a symlink to another disk, add its real path to the agent's writable directories (`writable_roots` in Codex, `--add-dir` in Claude Code) | Otherwise the sandbox blocks writes there |
| Let the agent reach the network for `git pull` and `git push` | Codex's workspace-write sandbox has no network by default: set `network_access = true` under `[sandbox_workspace_write]` in `~/.codex/config.toml`, or approve each request |
| Let the agent read the guide in your home directory | Claude Code asks before reading outside its working directory: allow it, or start with `--add-dir ~/vibe-research-loop` |

## The workspace guide

A workspace is the directory you launch Codex or Claude Code from. [`workspace_guide/`](workspace_guide/) is not a workspace itself but the template for one: an agent reads its setup prompt, asks you for a few settings, such as the languages and the git level, creates the folder tree, and writes the workspace's own rule files, revised to fit your answers.

| File | Role |
|---|---|
| [`workspace_prompts.md`](workspace_guide/workspace_prompts.md) | The setup prompts, one per section. They stay in this guide and are not copied into the workspace |
| [`AGENTS.md`](workspace_guide/AGENTS.md) | The entry point agents load at launch: any strict rules the user adds, and an index of the rule files, which agents read at the start of every session |
| [`.env`](workspace_guide/.env) | The machine's environment variables, as few as possible: where caches go and which time zone to use |
| [`docs/AGENTS/`](workspace_guide/docs/AGENTS/) | The basic rules, one topic per file, such as the folder tree ([`file_structure.md`](workspace_guide/docs/AGENTS/file_structure.md)) and the log format. Each file stands alone and never mentions another; [`machine.md`](workspace_guide/docs/AGENTS/machine.md) describes one machine |

The workspace root is itself a git repository. Every machine shares it on one branch, pulling and pushing on its own; `.env` and `docs/AGENTS/machine.md` stay on each machine.

Codex and Claude Code both read `AGENTS.md` as the project instructions, so a workspace has no `CLAUDE.md`; the personal `~/.claude/CLAUDE.md` stays and does not stop Claude Code from reading `AGENTS.md`.

In `AGENTS.md`, each rule file is written as an `@` import, which Claude Code loads at launch. Codex does not expand `@`, so `AGENTS.md` also tells agents to read every rule file at the start of each session and again after the context is compacted.
