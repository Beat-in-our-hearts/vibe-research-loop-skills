# Environment

`.env` at the workspace root sets every environment variable this machine needs, one `NAME=value` per line, as few as possible; it is never committed and never holds tokens, keys, or passwords:

| Variable | Value |
|---|---|
| `XDG_CACHE_HOME` | `<absolute path of the workspace>/.cache`, where most tools keep their caches |
| `TZ` | `Area/City`: every machine writes times in this time zone, the same as Notion |

- Write each value as a literal, an absolute path or a plain value, never built from another variable (`HF_HOME=$XDG_CACHE_HOME/huggingface`) or a relative path.
- Load `.env` in every command you launch, with `set -a; . <absolute path of the workspace>/.env; set +a`; never rely on `.bashrc`. The VRL scripts load it themselves, skipping names that change what runs, such as `HOME`, `PATH`, or `LD_PRELOAD`; keep those out of it.
- Add a variable only for a tool that ignores `XDG_CACHE_HOME`, such as `TRITON_CACHE_DIR` or `CUDA_CACHE_PATH`, pointing inside `.cache/`, and only when the user agrees.
- Keep every cache in `.cache/`, never in a default home folder such as `~/.cache`, `~/.triton`, or `~/.nv`. If `.cache/` outgrows its disk, make it a symlink to a larger disk.
- A folder named like `$...`, or a stray `cache/`, in the workspace means a variable was set wrongly: report it, and do not delete it.
