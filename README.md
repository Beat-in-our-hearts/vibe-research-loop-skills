# vibe-research-loop-skills

Agent skills for the vibe-research-loop guide, the research workflow in which AI coding agents run the experiment loop and the user makes the decisions. Each skill is a folder under [`skills/`](skills/) with a `SKILL.md`, in the Agent Skills format that both Claude Code and Codex load.

| Skill | What it does | Invoked by |
|---|---|---|
| [`setup-workspace`](skills/setup-workspace/SKILL.md) | Sets up a workspace, or adds a machine, from the guide's workspace prompts | The user only |
| [`setup-notion`](skills/setup-notion/SKILL.md) | Sets up the Notion side, or connects a machine, from the guide's Notion prompts | The user only |
| [`setup-gdrive`](skills/setup-gdrive/SKILL.md) | Optional: keeps datasets, runs, and logs on Google Drive | The user only |
| [`propose-idea`](skills/propose-idea/SKILL.md) | Writes a testable hypothesis into Ideas, for the user to approve | The user or the agent |
| [`plan-experiment`](skills/plan-experiment/SKILL.md) | Plans the next experiment of an approved idea, for the user to approve | The user or the agent |
| [`run-experiment`](skills/run-experiment/SKILL.md) | Launches and monitors the approved runs, then closes the experiment with its outcome | The user or the agent |
| [`analyze-results`](skills/analyze-results/SKILL.md) | Fills the results and conclusion of a finished experiment | The user or the agent |
| [`write-finding`](skills/write-finding/SKILL.md) | Drafts a finding for the user to confirm, then closes the idea | The user or the agent |
| [`search-papers`](skills/search-papers/SKILL.md) | Adds at most three papers per search to the Literature Library | The user or the agent |

## Installing

Once per machine, clone this repository into your home directory, next to the guide:

```bash
git clone <repository URL> ~/vibe-research-loop-skills
```

Then link every skill into the personal skill folders of both agents. A skill folder that already exists under the same name is left alone:

```bash
for d in ~/vibe-research-loop-skills/skills/*/; do n=$(basename "$d"); for t in ~/.claude/skills ~/.agents/skills; do mkdir -p "$t"; [ -e "$t/$n" ] || ln -s "${d%/}" "$t/$n"; done; done
```

A `git pull` in `~/vibe-research-loop-skills` updates every linked skill; run the loop again only when a pull adds a skill. Start a new session if a skill does not show up.

## Using

| Agent | Invoke a skill |
|---|---|
| Claude Code | `/plan-experiment`, followed by any details |
| Codex | `$plan-experiment`, followed by any details |

The agent also picks a research skill on its own when a request matches its description; the setup skills run only when the user invokes them.

- Set up the workspace and Notion first, with `setup-workspace` and `setup-notion`. The research skills rely on the workspace's rules and on the Notion templates, whose gray instructions say what goes where.
- Start the agent from the workspace root; the research skills stop anywhere else.
- The research skills keep the IDs of the Notion project page and databases in the workspace's `docs/notion/ids.md`.

## Compatibility

| | Claude Code | Codex |
|---|---|---|
| Personal skill folder | `~/.claude/skills/` | `~/.agents/skills/` |
| Skills only the user invokes | `disable-model-invocation: true` in `SKILL.md` | `policy.allow_implicit_invocation: false` in `agents/openai.yaml` |
| `agents/openai.yaml` | Ignored | Display name, short description, default prompt, and invocation policy |

Each agent ignores the other's settings, so one folder serves both.
