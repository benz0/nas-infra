# Same image as the Vault server, so nothing new is pulled and versions match.
FROM hashicorp/vault-enterprise:2.2.1-ent

# Config is baked in (not bind-mounted) so the agent can't change it at runtime.
# role_id is not secret on its own: it is useless without a secret ID from
# 172.16.0.0/12. shed-vault.crt is the public CA cert for Vault's TLS.
COPY agent.hcl     /vault/agent/agent.hcl
COPY role_id       /vault/agent/role_id
COPY shed-vault.crt /vault/agent/ca.crt
