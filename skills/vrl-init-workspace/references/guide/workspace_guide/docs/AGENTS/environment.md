# Environment

`.env` at the workspace root sets every environment variable this machine needs, one `NAME=value` per line, as few as possible; it is never committed:

| Variable | Value | Why |
|---|---|---|
| `XDG_CACHE_HOME` | `<absolute path of the workspace>/.cache` | pip, uv, Hugging Face, torch, and most other tools keep their caches under it |
| `TZ` | `Asia/Dubai` | Every machine writes times in UAE time, the same as Notion |

- Write every value as a literal: an absolute path or a plain value. Never build one from another variable (`export X=$X/...`, `HF_HOME=$XDG_CACHE_HOME/huggingface`) or from a relative path; both leave stray folders behind.
- Load `.env` in every command you launch: `set -a; . <absolute path of the workspace>/.env; set +a`. Never rely on `.bashrc`: commands run through `tmux new-window '<cmd>'`, `ssh host '<cmd>'`, or a job scheduler may not read it.
- Add a variable only for a tool that ignores `XDG_CACHE_HOME`, such as `TRITON_CACHE_DIR` for Triton or `CUDA_CACHE_PATH` for the CUDA kernel cache; point it inside `.cache/`, and add it only when the user agrees.
- Never put tokens, keys, or passwords in `.env`.
- Never let caches write to the home directory or the system disk. If `.cache/` outgrows its disk, make it a symlink to a larger disk instead of moving caches elsewhere.
- If a folder named like `$...`, or a stray `cache/`, appears in the workspace, a variable was set wrongly: report it, and do not delete it.
