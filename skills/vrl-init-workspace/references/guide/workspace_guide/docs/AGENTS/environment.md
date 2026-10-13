# Environment

`.env` at the workspace root sets every environment variable this machine needs, one `NAME=value` per line. Never commit it, and never put a token, key, or password in it.

| Variable | Value |
|---|---|
| `XDG_CACHE_HOME` | `<absolute path of the workspace>/.cache` |
| `TZ` | `Area/City`, the time zone of every time agents write |

- Write each value as a literal, never with `$VAR` or a relative path.
- Load `.env` in every command you launch, with `set -a; . <absolute path of the workspace>/.env; set +a`; never rely on `.bashrc`.
- Keep every cache in `.cache/`, never in `~/.cache`, `~/.triton`, or `~/.nv`.
- Add a variable only with the user's consent, such as a cache path inside `.cache/` for a tool that ignores `XDG_CACHE_HOME`.
- A folder named like `$...`, or a stray `cache/`, in the workspace means a variable was set wrongly: report it; never delete it.
