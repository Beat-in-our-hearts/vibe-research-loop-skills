# Log template

Launch every command that may run for minutes, smoke runs, data processing, and setup steps included, from the workspace root, through `vrl_ssh.sh script` in remote mode, with `bash <VRL scripts>/launch_run.sh --machine <name> --tmux <session>` (`--nohup` without a tmux session), `--gpus <ids>` or `--no-gpu`, and:

- for a run of an approved plan, only `--plan <plan file> --run <run> --plan-sha256 <hash>`;
- for anything else, `--purpose '<one line>' --log <log> --code <checkout or none> [--outputs <folder>] -- '<command>'`.

The command starts in the workspace root, so it enters its checkout itself, as in `cd main_repo && ...`, and writes its outputs to `$VRL_OUTPUTS`. Turn off or slow down its progress bars.

- Read a log's header with `head` and its end with `tail` first. A log without a footer is still running, or was killed.
- Stop a run with `kill <PID>` from its header's session line, or by closing its tmux window.
- Start an ended run again only with `--restart`, once the cause of its crash or failure is fixed, or with `--resume`, to continue one that ended with exit code 0.
