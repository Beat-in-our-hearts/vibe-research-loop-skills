# Log template

A log must make sense on its own. Launch every long-running command with `launch_run.sh`, one of the VRL scripts: training, evaluation, smoke runs, data processing, and setup that takes minutes. It writes the header before the command starts, puts stdout and stderr in the log, and appends the footer when the command and every process it started have ended:

```
# command:   <the exact command>
# plan:      <plan file> (sha256 <hash>), run <run>      only for a run of an approved plan
# purpose:   <date>-<name> / <run>: one line on what this command does
# code:      <checkout> (<branch>) @ <commit> (clean or dirty)
# outputs:   <output paths, e.g. runs/<date>-<name>/<run>/>
# resources: <machine>, GPU <ids> (<model>), Python env <name>      or: <machine>, no GPU, ...
# run-id:    <12 hex characters, new for each start>
# session:   <session>:<window>, PID <n>      or: PID <n>
# started:   <YYYY-MM-DD HH:MM:SS ±HH:MM>
# ---------- stdout + stderr ----------
<the command's output, unchanged>
# ---------- end <run-id> ----------
# finished:  <YYYY-MM-DD HH:MM:SS ±HH:MM> (<duration>), exit code <n>
```

- A run of an approved plan starts only in the plan form, `--plan <plan file> --run <run> --plan-sha256 <hash>`: the command, its GPU count, and its checkout's commit and diff come from the plan, and its log and outputs are `logs/<date>-<name>/<run>.log` and `runs/<date>-<name>/<run>/`. Anything else starts in the free form, `--purpose '<...>' --log <log> --code <checkout> -- '<command>'`.
- The command runs from the workspace root, whatever its checkout, so it enters the checkout itself, as in `cd main_repo && ...`. It gets the variables of `.env`, read as literal `NAME=value` lines and never run; only the GPUs given with `--gpus`, numbered as `nvidia-smi` numbers them, so it never sets `CUDA_VISIBLE_DEVICES` itself; and its outputs folder as `VRL_OUTPUTS`.
- `code` names the checkout the command uses: `main_repo`, a worktree, or a reference repository. When it is dirty, the diff that rebuilds it is saved in the outputs folder as `git_diff.patch`, or `git_diff-<time>.patch` if an earlier diff differs.
- A run is alive while one of its processes writes its log. `session` is where it lives: check or attach to it there. Stop it with `kill <PID>` or by closing its tmux window, which ends every process of the run and still writes the footer.
- `launch_run.sh` never starts a second copy of a live run, and starts a run whose log has ended only when asked: `--restart` for one that crashed or failed, once its cause is fixed, which first closes a crashed run with a footer at the log's last write, exit code unknown; `--resume` to continue one that finished with exit code 0. Otherwise, give a rerun a new run name.
- It refuses a command that seems to hold a secret, and runs nothing on a machine with a job scheduler: there, launch through the scheduler, and write this header and footer by hand, with the scheduler's job ID as the session.
- Turn off progress bars or slow their refresh, so that they do not flood the log.
- Read a log's header with `head` and its end with `tail` before reading the rest. A log without a footer belongs to a command that is still running, if a process still writes it, or was killed.
