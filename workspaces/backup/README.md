# backup

Private B2 bucket for the offsite Hyper Backup copy of `docs`, `vault-personal`, `vault-work`, `git` and Vault's raft snapshots (`/volume1/hcv-data/data/snapshots`). Photos go to Amazon Photos; replaceable media isn't backed up offsite.

- Lifecycle: keep only the latest version of each file (hidden versions deleted after 1 day). Hyper Backup keeps its own version history inside its backup set.
- Encryption: SSE-B2 at rest, plus Hyper Backup client-side encryption.

HCP Terraform workspace `shed-backup`: agent execution (pool `shed`), manual apply, working directory `workspaces/backup`, trigger pattern `workspaces/backup/**/*`. Sensitive environment variables `B2_APPLICATION_KEY_ID` and `B2_APPLICATION_KEY` (1Password "Backblaze B2 - terraform").

The Hyper Backup application key is created in the B2 web UI, limited to this bucket, and is not managed here.
