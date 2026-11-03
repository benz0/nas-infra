# shed agent

A Claude Code agent that lives on shed, takes tasks from other agents through a
file inbox, and authenticates to Anthropic with Workload Identity Federation
(Vault is the OIDC issuer). No Anthropic API key exists anywhere.

```
 other agents ──► _agent/inbox/*.json
                        │
           ┌────────────▼────────────┐        ┌──────────────────────┐
           │ shed-agent (uid 1040)   │◄─ro────│ tokens (tmpfs)        │
           │ runner.mjs → claude -p  │        └──────────▲───────────┘
           └────────────┬────────────┘                   │ identity token, refreshed every 5 min
                        │                     ┌──────────┴───────────┐
           outbox/<id>.md, archive/<id>.json  │ shed-vault-agent     │──► Vault (AppRole, namespace agent)
                                              └──────────────────────┘
```

## Layout

| Path | What |
|---|---|
| `compose.yaml` | Container Manager project. Deployed to `/volume1/docker/shed-agent` (agent-bot can't read the docker share). |
| `vault-agent/` | Vault Agent sidecar: AppRole login, writes the identity token to the `tokens` tmpfs volume. Needs `shed-vault.crt` copied in before building (not committed). |
| `agent/` | Node + pinned Claude Code + `runner.mjs`, all baked into the image. |
| `tests/wif-smoke.*` | One-off end-to-end WIF test (Phase 6). |

## Task format

Drop one JSON file per task into `/volume1/vault-work/_agent/inbox/`.
**Write it under a temporary name that doesn't end in `.json` (for example
`.tmp-<id>`) and then rename it**, so the runner never reads a half-written file.

```json
{
  "id": "2026-11-03-tidy-docs-readme",
  "from": "claude-cowork",
  "created": "2026-11-03T14:00:00Z",
  "instructions": "Read /shares/docs/README.md and fix spelling mistakes. Don't change anything else.",
  "paths": ["/shares/docs/README.md"],
  "reply_to": "Ben's Cowork session, NAS agent project"
}
```

| Field | Required | Rules |
|---|---|---|
| `id` | yes | 1–64 chars, letters, digits, `.` `_` `-`; must be new (re-used ids are rejected) |
| `from` | yes | Who's asking (agent name). Self-reported until Phase 8 (IBM Verify identities). |
| `instructions` | yes | Plain language, max 20,000 chars |
| `created` | no | ISO 8601 |
| `paths` | no | Paths in scope, as the agent sees them (`/shares/<share>/...`) |
| `reply_to` | no | Free-text note on where the requester wants to hear back |

Unknown fields are rejected.

## Results

- `outbox/<id>.md`: status, duration, cost, then the agent's summary
  ("What I did", "Files created or changed", "Requests for Ben", "Problems").
- `archive/<id>.json`: the task plus a `_result` block.
  Rejected tasks land as `archive/<id>.rejected.json`; tasks cut off by a restart
  as `archive/<id>.interrupted.json` (not retried).
- `logs/agent.log`: JSON lines; also the container log in Container Manager.
- `work/<id>/`: the agent's scratch directory for that task.

## Guardrails

- The NAS ACLs block deletes and renames for agent-bot everywhere except
  `vault-work`, and all access to `docker` and `hcv-data`. Claude Code runs with
  `bypassPermissions`; the container and the ACLs are the boundary, not prompts.
- Anything that needs a delete/rename outside `vault-work` goes in the summary
  under "Requests for Ben" (Phase 7 executor will turn these into approvals).
- Limits per task: 50 turns, 30 minutes. Model: `sonnet`. Org spend limit $25/month.

## Starting it (and after every restart)

Vault Agent consumes the wrapped secret ID and deletes the file, so every
start of `shed-vault-agent` needs a fresh one (Vault itself also needs
unsealing after a NAS reboot, so you're in the loop then anyway):

```sh
vault write -wrap-ttl=30m -f -namespace=agent auth/approle/role/claude-agent/secret-id -format=json \
  | jq -r .wrap_info.token > /Volumes/vault-work/_agent/secrets/wrapped-secret-id
```

Secret IDs expire after 30 days (`secret_id_ttl`), so the agent needs a fresh
one at least monthly even without a restart.
