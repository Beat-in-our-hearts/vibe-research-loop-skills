# Machine

| Item | Value |
|---|---|
| Name | <short name, used in commit messages, logs, and reports> |
| GPUs | <count × model (memory each)>; experiments use <GPU ids, such as 0,1,2,3> |
| CPU and memory | <real limits, and the command that reads them> |
| Outputs storage | <path and filesystem, quota, and the command that measures its usage> |
| System disk | <size, and what must never be written there> |
| Scheduler | <none, or the scheduler with its partition and limits; with one, jobs are launched through it by hand, since `launch_run.sh` refuses to run there> |
| tmux session | <the session long-running commands start in, such as `vrl`, and the exact command that starts it unless it already runs, to run again after a reboot; or none, to launch with nohup> |
| VRL scripts | <the absolute path of the `scripts/` folder of the vrl-init-workspace skill on the machine the agent is launched on, which holds `vrl_ssh.sh`, `launch_run.sh`, `resources.sh`, and `gpu_hours.py`> |
| Network | <internet access, any proxy, whose settings are in `.env`, and where to download if this machine has none> |
| Rules on this machine | <anything allowed or forbidden only here> |

- This file describes this machine only; measure current usage live every time.
- Where this file and another rule file differ, this file wins.
- Change it only when the user asks; if the hardware no longer matches it, tell the user.
