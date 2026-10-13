# Morning report

Show the user this report, and append it to the window's log:

- each run launched, finished, or restarted overnight, with its experiment, GPU, and outcome or progress;
- GPU use, by `gpu_hours.py --json --since '<window start>' --until '<window end>'` on `logs/`, why each GPU of machine.md short of the window's hours idled, from the log, and hours it could not count;
- runs still going, with ETA, for the user to take over with vrl-run-experiment;
- what waits for the user, and what they must decide: skipped experiments, runs stopped for a fix, approvals, experiments to analyze.
