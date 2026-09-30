# Drive

**Drive folder for this workspace: `<rclone remote>:<folder>`.** Every machine uses the same remote name. Change the folder only when the user asks.

| In the workspace | On Drive | What goes up |
|---|---|---|
| `data/<dataset>-<version>/` | `data/<dataset>-<version>.tar.zst` and its `.sha256` | Each dataset version once, as one archive with its checksum |
| `runs/<date>-<name>/<run>/` | The same path | Metrics, config snapshots, figures, and the final and best checkpoints |
| `runs/findings/<date>-<id>/` | The same path | A finding's figures and plotting scripts |
| `logs/` | The same path | Every log |

- Move files only with `rclone copy`, in both directions. Never use `rclone sync` or any command that deletes on Drive, because other machines upload there too, and never mount Drive with `rclone mount`: it is slow and often unavailable in containers.
- At every progress check of a running job, upload its log and metrics; when the job ends, upload its run folder.
- Never upload intermediate checkpoints: Drive takes at most 750 GB a day per account.
- Pack a folder of many small files into one archive before uploading it; Drive handles small files slowly.
- Download by path, only what the task needs. Check a dataset archive against its `.sha256`, extract it to local disk, and point `data/` at the copy; never train from Drive directly.
- Leave the rclone login on each machine to the user; never handle its token.
- If a transfer fails, retry once, then report.
