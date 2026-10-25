# ---------------------------------------------------------------------------
# NAS agent identity (phase 6).
#
#   1. The agent container logs in with AppRole (agent namespace). The secret ID
#      is generated with the CLI and handed to the container, never stored here.
#   2. Its token can read agent-bot's DSM credentials and mint a short-lived
#      OIDC identity token signed by Vault.
#   3. Claude Code trades that token with Anthropic (Workload Identity
#      Federation) for a ~10 minute API token. No Anthropic key exists anywhere.
#
# Anthropic can't reach this Vault, so its public signing keys (JWKS) are
# uploaded to the Anthropic Console by hand ("inline" JWKS). Because of that,
# the signing key rotates rarely and deliberately; see README.
# ---------------------------------------------------------------------------

# Issuer value put in every identity token's `iss` claim. Anthropic compares it
# as a string (inline JWKS mode), so it only has to be stable, not reachable.
resource "vault_identity_oidc" "agent" {
  namespace = vault_namespace.agent.path
  issuer    = var.oidc_issuer

  depends_on = [vault_audit.file]
}

resource "vault_identity_oidc_key" "anthropic" {
  namespace        = vault_namespace.agent.path
  name             = "anthropic"
  algorithm        = "RS256"
  rotation_period  = var.oidc_key_rotation_seconds
  verification_ttl = var.oidc_key_rotation_seconds

  depends_on = [vault_audit.file]
}

resource "vault_identity_oidc_role" "claude_agent" {
  namespace = vault_namespace.agent.path
  name      = "claude-agent"
  key       = vault_identity_oidc_key.anthropic.name
  ttl       = 900 # 15 minutes; Anthropic caps its token at 2x what remains.

  # Fixed claim the Anthropic federation rule matches on. The token's `sub` is
  # the agent's Vault entity ID, which only exists after its first login.
  template = jsonencode({ agent = "shed-claude" })
}

resource "vault_identity_oidc_key_allowed_client_id" "claude_agent" {
  namespace         = vault_namespace.agent.path
  key_name          = vault_identity_oidc_key.anthropic.name
  allowed_client_id = vault_identity_oidc_role.claude_agent.client_id
}

resource "vault_policy" "claude_agent" {
  namespace = vault_namespace.agent.path
  name      = "claude-agent"
  policy    = <<-EOT
    # agent-bot's DSM login (written by hand with the CLI).
    path "kv/data/dsm/agent-bot" {
      capabilities = ["read"]
    }

    # Mint the identity token Anthropic exchanges for an API token.
    path "identity/oidc/token/claude-agent" {
      capabilities = ["read"]
    }
  EOT

  depends_on = [vault_audit.file]
}

resource "vault_auth_backend" "approle" {
  namespace   = vault_namespace.agent.path
  type        = "approle"
  path        = "approle"
  description = "NAS agent container login (replaced by IBM Verify identity in phase 8)"

  depends_on = [vault_audit.file]
}

resource "vault_approle_auth_backend_role" "claude_agent" {
  namespace = vault_namespace.agent.path
  backend   = vault_auth_backend.approle.path
  role_name = "claude-agent"

  token_policies = [vault_policy.claude_agent.name]
  token_ttl      = 3600
  token_max_ttl  = 14400

  # Only containers on the Docker networks may use the secret ID or the tokens.
  secret_id_bound_cidrs = var.agent_cidrs
  token_bound_cidrs     = var.agent_cidrs
}

output "claude_agent_role_id" {
  description = "AppRole role ID for the agent (not secret on its own)."
  value       = vault_approle_auth_backend_role.claude_agent.role_id
}

output "claude_agent_oidc_issuer" {
  description = "The `iss` claim in the agent's identity tokens (issuer URL in the Anthropic Console)."
  value       = "${var.oidc_issuer}/v1/${vault_namespace.agent.path}/identity/oidc"
}

output "claude_agent_oidc_client_id" {
  description = "The `aud` claim in the agent's identity tokens. Used in the Anthropic federation rule."
  value       = vault_identity_oidc_role.claude_agent.client_id
}
