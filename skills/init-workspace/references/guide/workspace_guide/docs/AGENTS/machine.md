# Machine

| Item | Value |
|---|---|
| Name | <short name, used in commit messages, logs, and reports> |
| GPUs | <count × model (memory each)>; experiments use <GPU ids> |
| CPU and memory | <real limits, and the command that reads them> |
| Outputs storage | <path and filesystem, quota, and the command that measures its usage> |
| System disk | <size, and what must never be written there> |
| Scheduler | <none, or the scheduler with its partition and limits> |
| Network | <internet access, and where to download if this machine has none> |
| Rules on this machine | <anything allowed or forbidden only here> |

- This file describes this machine only; measure current usage live every time.
- Where this file and another rule file differ, this file wins.
- Change it only when the user asks; if the hardware no longer matches it, tell the user.
