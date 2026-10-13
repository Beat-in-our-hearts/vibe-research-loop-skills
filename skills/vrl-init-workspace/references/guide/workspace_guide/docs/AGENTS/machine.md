# Machine

| Item | Value |
|---|---|
| Name | <short name for commits, logs, and reports> |
| GPUs | <count × model (memory)>; experiments use <GPU ids, such as 0-3> |
| CPU and memory | <real limits, and the command that reads them> |
| Outputs storage | <path, filesystem, quota, and the command that measures its usage> |
| System disk | <size, and what must never go there> |
| Scheduler | <none, or the scheduler, partition, limits, and how to submit a job> |
| tmux session | <name, and the command that starts it if it is not running; or none> |
| VRL scripts | <absolute path of the vrl-init-workspace skill's `scripts/` folder> |
| Network | <internet access, any proxy, and where to download if offline> |
| Rules on this machine | <anything allowed or forbidden only here> |

- This file wins over the other rule files. Measure current usage live.
- If the hardware no longer matches this file, tell the user.
