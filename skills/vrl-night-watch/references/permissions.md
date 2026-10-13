# Night-watch permissions

Check that the watch can run unattended. Give the user these rules for their own settings or `.claude/settings.local.json`, never a settings file the workspace repository shares, with this machine's values: `S`, the VRL scripts path, and `I`, the GPU ids, from `docs/AGENTS/machine.md`; in remote mode, `A`, the alias, `R`, the remote workspace, and `L`, the command limit, from `docs/AGENTS/remote.md`. Spell `S` out.

Allow:
- `date`, and reads of `~/.agents/skills/` and `~/.claude/skills/`;
- `bash S/check_update.sh`, and each script's `--help`;
- `bash S/resources.sh --allowed I`, `python3 S/gpu_hours.py`, and `bash S/launch_run.sh --plan docs/plans/`; in remote mode, instead, `bash S/vrl_ssh.sh check A`, `bash S/vrl_ssh.sh connect A`, the read-only `bash S/vrl_ssh.sh read A --workspace R --limit L -- `, called without `--lines`, and `bash S/vrl_ssh.sh script A --workspace R --limit L -- ` followed by `resources.sh --allowed I`, `gpu_hours.py`, or `launch_run.sh --plan docs/plans/`;
- the tmux session's start command and the quota command in `docs/AGENTS/machine.md`, exactly as written; in remote mode, each as the whole line `bash S/vrl_ssh.sh run A --workspace R --limit L -- '<command>'`, never as a `vrl_ssh.sh run` prefix;
- the memory store's page API: `ntn api v1/`, or `lark-cli base`, `lark-cli docs`, and `lark-cli wiki`;
- edits of `logs/*-night-watch.log`, which stays local in remote mode.

Deny:
- `launch_run.sh` with `--resume` or `--new-session`;
- `ntn auth`, `ntn login`, `ntn logout`, `ntn files`, `ntn workers`, and `ntn update`;
- `ntn api` with the method `DELETE`, with `in_trash` or `archived`, or with data read from a file by `@`;
- `lark-cli` with `--yes`;
- edits of `docs/`, `.env`, `.claude/`, and the code folders;
- in remote mode, `vrl_ssh.sh sync` and `fetch`, and any local `python`, `python3`, `uv`, `pip`, or `pytest`; not `vrl_ssh.sh run`, which would also refuse the two allowed lines.

In Codex, prefix rules match whole arguments and cannot deny an argument anywhere in a command: write them as `["bash", "S/launch_run.sh", "--plan"]` and so on, and tell the user that the denies hold there only as the skill's rules. The automation's sandbox also needs network access, for `ssh` and the memory store's CLI.

Tell the user what the rules leave open: they match a command's text, so a call written another way can slip past a deny; the allowed page writes can still tick Human Approved or change the Code row; and only these rules and the skill's steps keep the watch from launching a plan the user did not approve.

Then tell the user the window, the approved runs in line, and the morning report's time. If no automation or job runs the watch yet, tell them how to start it: `/loop /vrl-night-watch` with no interval in Claude Code; a Codex automation running `$vrl-night-watch` every 30 minutes in the workspace, not a worktree; or a cron job every half hour.
