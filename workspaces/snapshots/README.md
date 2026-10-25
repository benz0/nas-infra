# snapshots

Hourly Btrfs snapshots with advanced retention for every share agent-bot can write to.

- **Schedule:** every hour, at a staggered minute per share (`var.shares`).
- **Retention:** latest snapshot of each hour for 24 hours, each day for 30 days, each week for 12 weeks; never fewer than 5.
- **Not covered:** `docker` and `hcv-data`. Vault has its own raft snapshots.

HCP Terraform workspace `shed-snapshots`: agent execution (pool `shed`), manual apply, working directory `workspaces/snapshots`, trigger pattern `workspaces/snapshots/**/*`. Uses the same `SYNOLOGY_*` environment variables as `shed-vault`.

Requires the workspace environment variable `TFE_PARALLELISM=1` (parallel requests crossed DSM replies). To repeat every call, bump `revision`.

Manage these settings here only. The API calls are replayed blind, so Terraform won't see changes made in the Snapshot Replication UI. See the comments in `main.tf` for the API quirks.
