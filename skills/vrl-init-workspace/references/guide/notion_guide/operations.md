1. Look up `ntn` usage live instead of from memory: `ntn --help`, `ntn api ls`, and `ntn api <path> -X <method> --spec` or `--docs`.
2. Always run `ntn api ... < /dev/null`; without it the CLI waits on stdin and hangs.
3. Read before every write and read back after it; never overwrite a human's edit or make a Human-In-Loop decision.
