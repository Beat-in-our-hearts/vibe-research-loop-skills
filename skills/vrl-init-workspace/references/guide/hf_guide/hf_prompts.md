# Hugging Face prompts

Prompts, one per section, for AI coding agents that keep a workspace's datasets, runs, and logs in a Hugging Face Storage Bucket with the `hf` CLI. The bucket is optional: skip this guide if the workspace does not use it. When the user asks for a section's task, follow its steps in order; `<guide>` is the root of this repository.

## Set up Hugging Face

Use this once per workspace, after "Set up a workspace".

1. **Bucket.** Ask the user for the workspace's bucket as `<namespace>/<bucket>`, the namespace being their user name or an organization they belong to, and wait for the answer.
2. **hf CLI.** Check that `hf buckets --help` works; if not, ask the user to install or update the `hf` CLI (huggingface_hub 1.5 or later), for example with `curl -LsSf https://hf.co/cli/install.sh | bash`. Ask the user to log in on this machine themselves with `hf auth login`, since the login holds their token, in a shell that has loaded `.env` as `docs/AGENTS/environment.md` says: `XDG_CACHE_HOME` decides where `hf` keeps the login. Then, with `.env` loaded, check that `hf auth whoami` works, and look up the bucket with `hf buckets info <namespace>/<bucket>`: if it does not exist, create it with `hf buckets create <namespace>/<bucket> --private`; if it is public, ask the user before going on.
3. **Rule file.** Write `docs/AGENTS/hf.md` from `<guide>/hf_guide/docs/AGENTS/hf.md`, in the working language and with the bucket from step 1. Add its row to the index in `AGENTS.md`, after the git row:

   ```
   | @docs/AGENTS/hf.md | Checking a running job, or moving files to or from the Hugging Face bucket |
   ```

4. **Commit and report.** Commit and push the workspace repository, and tell the user what is set up.

## Add a machine

Use this on another machine of a workspace that uses a Hugging Face bucket, after "Add a machine" in the workspace prompts: do step 2 of "Set up Hugging Face". The rule file and its index row come with the workspace repository.
