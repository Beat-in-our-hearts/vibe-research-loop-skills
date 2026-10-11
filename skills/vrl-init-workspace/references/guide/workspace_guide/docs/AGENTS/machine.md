# Machine

| Item | Value |
|---|---|
| Name | <short name for commit messages, logs, and reports> |
| GPUs | <count × model (memory each)>; experiments use <GPU ids, such as 0,1,2,3> |
| CPU and memory | <real limits, and the command that reads them> |
| Outputs storage | <path, filesystem, quota, and the command that measures its usage> |
| System disk | <size, and what must never be written there> |
| Scheduler | <none, or the scheduler, its partition and limits; jobs then launch through it by hand> |
| tmux session | <the session for long-running commands, such as `vrl`, and the exact command that starts it unless it already runs, to run again after a reboot; or none, to launch with nohup> |
| VRL scripts | <absolute path of the vrl-init-workspace skill's `scripts/` folder on the machine the agent runs on> |
| Network | <internet access, any proxy (set in `.env`), and where to download if there is none> |
| Rules on this machine | <anything allowed or forbidden only here> |

- This file describes this machine only, and wins where another rule file differs; measure current usage live every time.
- If the hardware no longer matches it, tell the user.
