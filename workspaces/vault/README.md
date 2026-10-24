# Vault Enterprise on shed

Single-node Vault Enterprise with integrated storage, deployed as a Container
Manager project by the HCP Terraform agent (workspace `shed-vault`).

## One-time setup (by hand)

1. **Encrypted shared folder** `hcv-data` on `/volume1`, with Key Manager auto-mount.
   Store its encryption key in the 1Password `shed-recovery` vault. Create:
   - `/volume1/hcv-data/config/tls/`
   - `/volume1/hcv-data/config/license/`
   - `/volume1/hcv-data/data/raft/`
   - `/volume1/hcv-data/logs/`
2. **TLS certificate** written to `config/tls/vault.crt` and `config/tls/vault.key`
   (self-signed for now; replaced by Vault PKI or Let's Encrypt later).
3. **License** written to `config/license/vault.hclic`.
4. **DSM firewall**: allow TCP 8200 from the LAN, above any Deny rule.
5. **Workspace `shed-vault`**: VCS-driven, working directory `workspaces/vault`,
   execution mode Agent (pool `shed`), manual apply. Variables:
   - Terraform: `api_addr` = `https://<shed-address>:8200`
   - Environment (sensitive): `SYNOLOGY_HOST`, `SYNOLOGY_USER`, `SYNOLOGY_PASSWORD`,
     `SYNOLOGY_OTP_SECRET`; plain: `SYNOLOGY_SKIP_CERT_CHECK=true`

## After the first apply

Initialize by hand, from a machine that trusts `vault.crt`:

```bash
export VAULT_ADDR=https://<shed-address>:8200
export VAULT_CACERT=<path to vault.crt>
vault operator init -key-shares=5 -key-threshold=3
```

Store the five unseal keys and the initial root token in `shed-recovery`, then
unseal with any three keys. After a reboot Vault starts sealed; unseal again.

## Design notes

- **Config** is rendered as JSON and passed in `VAULT_LOCAL_CONFIG`; the image
  writes it to `/vault/config/local.json`. It contains no secrets.
- **Privileges**: the container starts as root only so the image's entrypoint
  can chown the bind mounts, then drops to the `vault` user. Capabilities are
  limited to CHOWN, SETUID and SETGID; no-new-privileges is set.
- **`disable_mlock = true`**, as recommended for integrated storage.
- **Backups** use Vault's automated snapshots (configured in Vault, phase 4),
  not filesystem snapshots of a live raft database.
