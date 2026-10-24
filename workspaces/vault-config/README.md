# shed-vault configuration

Vault configuration as code for shed-vault, run on the shed agent by HCP
Terraform workspace `shed-vault-config`.

| Resource | Purpose |
| --- | --- |
| `file` audit device | Every request to `/vault/logs/audit.log` (HMAC'd) |
| `admin` policy | Full administration; used by Terraform and human admins |
| `tfc` JWT auth + role | HCP Terraform dynamic credentials for this workspace |
| `userpass` auth | Human administrator logins |
| `agent` namespace | Isolated space for everything the NAS agent uses |
| `local-hourly` snapshots | Automated raft snapshots, 72 retained, 2 GiB cap |

## Workspace variables

Always (environment):
- `VAULT_ADDR` = `https://<shed-address>:8200`
- `VAULT_CACERT` = `/etc/shed/vault-ca.crt`

First run only (environment, sensitive):
- `VAULT_TOKEN` = the initial root token

After the first apply, delete `VAULT_TOKEN` and switch to dynamic credentials
(environment):
- `TFC_VAULT_PROVIDER_AUTH` = `true`
- `TFC_VAULT_ADDR` = `https://<shed-address>:8200`
- `TFC_VAULT_AUTH_PATH` = `tfc`
- `TFC_VAULT_RUN_ROLE` = `shed-vault-config`
- `TFC_VAULT_ENCODED_CACERT` = base64 of the CA certificate PEM

## Human admin login (by hand, once)

```bash
vault write auth/userpass/users/<you> \
  password="$(op read 'op://<vault>/<item>/password')" \
  token_policies=admin token_ttl=8h token_max_ttl=24h
```

Then log in with it, confirm `vault token lookup` shows the `admin` policy, and
revoke the root token: `vault token revoke -self` while logged in as root.
A new root token can always be generated with the unseal keys
(`vault operator generate-root`).
