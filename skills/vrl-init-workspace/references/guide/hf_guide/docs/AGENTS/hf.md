# Hugging Face

**Bucket for this workspace: `hf://buckets/<namespace>/<bucket>`.** It is private and shared by every machine; change it only when the user asks.

| In the workspace | In the bucket | What goes up |
|---|---|---|
| `data/<dataset>-<version>/` | `data/<dataset>-<version>.tar.zst` and its `.sha256` | Each dataset version once, as one archive with its checksum |
| `runs/<date>-<name>/<run>/` | The same path | Metrics, config snapshots, figures, and the final and best checkpoints |
| `runs/findings/<date>-<id>/` | The same path | A finding's figures and plotting scripts |
| `logs/` | The same path | Every log |

- Load `.env` in every `hf` command, or `hf` runs logged out.
- Move a folder with `hf sync` and a single file with `hf cp`, in both directions. Never remove anything from the bucket (`hf buckets rm`, `hf sync --delete`, `hf buckets delete`): it keeps no history. Never mount it with `hf-mount`.
- At every progress check of a running job, upload its log and metrics; when the job ends, upload its run folder.
- Never upload intermediate checkpoints; leave them out of a run folder's sync with `--exclude`.
- Pack a folder of many small files into one archive before uploading it.
- Download by path, only what the task needs. Check a dataset archive against its `.sha256`, extract it to local disk, and point `data/` at the copy; never train from the bucket directly.
- Log in to `hf` only with `setup_clis.sh login --only hf` from the VRL scripts, in the background, and in remote mode through `vrl_ssh.sh script` with `--limit 0`; pass the user the URL and code it prints at once, as the code expires in 5 minutes. Never ask for the token, print it, or pass it to a command.
- If a transfer fails, retry once, then report.
