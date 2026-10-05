# Hugging Face

**Bucket for this workspace: `hf://buckets/<namespace>/<bucket>`.** It is private, and every machine uses the same one. Change it only when the user asks.

| In the workspace | In the bucket | What goes up |
|---|---|---|
| `data/<dataset>-<version>/` | `data/<dataset>-<version>.tar.zst` and its `.sha256` | Each dataset version once, as one archive with its checksum |
| `runs/<date>-<name>/<run>/` | The same path | Metrics, config snapshots, figures, and the final and best checkpoints |
| `runs/findings/<date>-<id>/` | The same path | A finding's figures and plotting scripts |
| `logs/` | The same path | Every log |

- Load `.env` in every `hf` command: `XDG_CACHE_HOME` decides where `hf` keeps its login, so without it `hf` runs logged out.
- Move a folder with `hf sync` and a single file with `hf cp`, in both directions. Never remove anything from the bucket, with `hf buckets rm`, `hf sync --delete`, or `hf buckets delete`, because other machines upload there too and the bucket keeps no history: a deleted file is gone for good. Never mount the bucket with `hf-mount`: FUSE and NFS are often unavailable in containers, and every read would go over the network.
- At every progress check of a running job, upload its log and metrics; when the job ends, upload its run folder.
- Never upload intermediate checkpoints, and leave them out of a run folder's sync with `--exclude`: private storage counts against the account's quota and is billed above it.
- Pack a folder of many small files into one archive before uploading it; every file costs requests against the Hub's rate limits.
- Download by path, only what the task needs. Check a dataset archive against its `.sha256`, extract it to local disk, and point `data/` at the copy; never train from the bucket directly.
- Leave the `hf` login on each machine to the user; never handle its token.
- If a transfer fails, retry once, then report.
