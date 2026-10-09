# Machine

| Item | Value |
|---|---|
| Name | <short name, used in commit messages, logs, and reports> |
| GPUs | <count × model (memory each)>; experiments use <GPU ids, such as 0,1,2,3> |
| CPU and memory | <real limits, and the command that reads them> |
| Outputs storage | <path and filesystem, quota, and the command that measures its usage> |
| System disk | <size, and what must never be written there> |
| Scheduler | <none, or the scheduler with its partition and limits; with one, jobs are launched through it by hand, since the vrl scripts refuse to> |
| tmux session | <the session long-running commands start in, such as `vrl`, started from a shell with this machine's settings, such as a proxy; or none, to launch with nohup> |
| VRL scripts | <the absolute path of the `scripts/` folder of the vrl-init-workspace skill on this machine, which holds `vrl_ssh.sh`, `launch_run.sh`, `resources.sh`, and `gpu_hours.py`> |
| Network | <internet access, and where to download if this machine has none> |
| Rules on this machine | <anything allowed or forbidden only here> |

- This file describes this machine only; measure current usage live every time.
- Where this file and another rule file differ, this file wins.
- Change it only when the user asks; if the hardware no longer matches it, tell the user.
