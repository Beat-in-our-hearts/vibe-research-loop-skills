# Log template

A log must make sense on its own. Launch every long-running command with `launch_run.sh`, one of the vrl scripts: training, evaluation, smoke runs, data processing, and setup that takes minutes. It writes the header before the command starts, puts stdout and stderr in the log, and appends the footer when the command and every process it started have ended:

```
# command:   <the exact command>
# plan:      <plan file> (sha256 <hash>), run <run>      only for a run of an approved plan
# purpose:   <date>-<name> / <run>: one line on what this command does
# code:      <checkout> (<branch>) @ <commit> (clean or dirty)
# outputs:   <output paths, e.g. runs/<date>-<name>/<run>/>
# resources: <machine>, GPU <ids> (<model>), Python env <name>      or: <machine>, no GPU, ...
# run-id:    <12 hex characters, new for each start>
# session:   <tmux session:window, >PID <n>
# started:   <YYYY-MM-DD HH:MM:SS ±HH:MM>
# ---------- stdout + stderr ----------
<the command's output, unchanged>
# ---------- end <run-id> ----------
# finished:  <YYYY-MM-DD HH:MM:SS ±HH:MM> (<duration>), exit code <n>
```

- Launch a run of an approved plan only in the plan form, `--plan <plan file> --run <run> --plan-sha256 <hash>`, which takes the command from the plan; use the free form, `--purpose '<...>' -- '<command>'`, for anything else. Give `--gpus <ids>` or `--no-gpu`: the command sees only those GPUs, numbered as `nvidia-smi` numbers them, so it never sets `CUDA_VISIBLE_DEVICES` itself.
- `code` names the checkout the command ran in: `main_repo`, a worktree, or a reference repository. When it is dirty, give `--outputs`: the diff that rebuilds it is saved there as `git_diff.patch`.
- A run is alive while one of its processes writes its log. `session` is where it lives: check or attach to it there. Stop it with `kill <PID>` or by closing its tmux window, which ends every process of the run and still writes the footer.
- `launch_run.sh` never starts a second copy of a live run. To start again a run that crashed, give `--restart`: it closes the old run with a footer at the log's last write, exit code unknown, and appends a new header. To continue a run that finished, give `--resume`; otherwise, give a rerun a new run name.
- It refuses a command that seems to hold a secret, and a machine with a scheduler: there, write the header and footer by hand, in this format, with the scheduler's job ID as the session.
- Turn off progress bars or slow their refresh, so that they do not flood the log.
- Read a log's header with `head` and its end with `tail` before reading the rest. A log without a footer belongs to a command that is still running, if a process still writes it, or was killed.
