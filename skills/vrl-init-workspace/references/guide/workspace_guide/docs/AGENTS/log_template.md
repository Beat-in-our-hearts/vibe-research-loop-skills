# Log template

Launch every long-running command with `launch_run.sh`, one of the VRL scripts: training, evaluation, smoke runs, data processing, and setup that takes minutes. Its log must make sense on its own: this header, the command's stdout and stderr, and a footer once every process of the command has ended:

```
# command:   <the exact command>
# plan:      <plan file> (sha256 <hash>), run <run>      (plan form only)
# purpose:   <date>-<name> / <run>: <what it does, in one line>
# code:      <checkout> (<branch>) @ <commit> (clean or dirty)
# outputs:   <output paths>
# resources: <machine>, GPU <ids> (<model>), Python env <name>      or: <machine>, no GPU, ...
# run-id:    <12 hex characters, new for each start>
# session:   <session>:<window>, PID <n>      or: PID <n>
# started:   <YYYY-MM-DD HH:MM:SS ±HH:MM>
# ---------- stdout + stderr ----------
<output>
# ---------- end <run-id> ----------
# finished:  <YYYY-MM-DD HH:MM:SS ±HH:MM> (<duration>), exit code <n>
```

- A run of an approved plan starts only in the plan form, `--plan <plan file> --run <run> --plan-sha256 <hash>`, which takes the command, its GPU count, and its checkout's commit and diff from the plan, and writes its log and outputs to `logs/<date>-<name>/<run>.log` and `runs/<date>-<name>/<run>/`. Anything else starts in the free form, `--purpose '<...>' --log <log> --code <checkout> -- '<command>'`, where `<checkout>` is `main_repo`, a worktree, or a reference repository.
- The command runs from the workspace root, so it enters its checkout itself, as in `cd main_repo && ...`. It gets the variables of `.env`, its outputs folder as `VRL_OUTPUTS`, and only the GPUs given with `--gpus`, numbered as in `nvidia-smi`, so it never sets `CUDA_VISIBLE_DEVICES`.
- A run is alive while one of its processes writes its log; a log without a footer is still running, or was killed. Find a run in its `session`. Stop it with `kill <PID>` or by closing its tmux window, which ends all its processes and still writes the footer.
- `launch_run.sh` never starts a second copy of a live run, nor a run whose log has ended unless asked: `--restart` for one that crashed or failed, once the cause is fixed, which first closes a crashed run with a footer at its last write, exit code unknown; `--resume` to continue one that finished with exit code 0.
- It refuses a command that seems to hold a secret, and runs nothing on a machine with a job scheduler: there, launch through the scheduler and write this header and footer by hand, with the job ID as the session.
- Turn off progress bars, or slow their refresh, so they do not flood the log.
- Read a log's header with `head` and its end with `tail` before the rest.
