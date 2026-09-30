# Log template

A log must make sense on its own. Write the header before the command starts, redirect stdout and stderr into the log, and append the footer when the command ends:

```
# command:   <the exact command>
# purpose:   <date>-<name> / <run>: one line on what this command does
# code:      <checkout> (<branch>) @ <commit> (clean or dirty)
# outputs:   <output paths, e.g. runs/<date>-<name>/<run>/>
# resources: <machine>, GPU <ids> (<model>), Python env <name>
# session:   <tmux session:window, PID, or scheduler job ID>
# started:   <YYYY-MM-DD HH:MM:SS ±HH:MM>
# ---------- stdout + stderr ----------
<the command's output, unchanged>
# ---------- end ----------
# finished:  <YYYY-MM-DD HH:MM:SS ±HH:MM> (<duration>), exit code <n>
```

- `code` names the checkout the command ran in: `main_repo`, a worktree, or a reference repository.
- `session` is where the process lives: check or attach to it there, and never start a second copy.
- For a command running in the background, let the same shell write the footer when the command exits; never write it right after launching.
- When you resume or restart a run, append a new header and footer to the same log.
- Turn off progress bars or slow their refresh, so that they do not flood the log.
- Read a log's header with `head` and its end with `tail` before reading the rest. A log without a footer belongs to a command that is still running or was killed.
