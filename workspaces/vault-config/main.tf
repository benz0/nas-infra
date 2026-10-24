# Vault configuration for shed-vault, as code.

# ---------------------------------------------------------------------------
# Audit: every request and response, HMAC'd, to the logs share.
# ---------------------------------------------------------------------------
resource "vault_audit" "file" {
  type = "file"
  path = "file"

  options = {
    file_path = "/vault/logs/audit.log"
  }
}

# ---------------------------------------------------------------------------
# Admin policy, used by Terraform and by human administrators.
# ---------------------------------------------------------------------------
resource "vault_policy" "admin" {
  name   = "admin"
  policy = <<-EOT
    # Full administration, including sudo-protected paths. Root token is
    # revoked once a human admin login exists; this replaces it.
    path "*" {
      capabilities = ["create", "read", "update", "patch", "delete", "list", "sudo"]
    }
  EOT
  # Vault refuses requests it cannot audit. Wait until the audit device has
  # finished setting up, or a parallel create can fail with "internal error".
  depends_on = [vault_audit.file]
}

# ---------------------------------------------------------------------------
# HCP Terraform workload identity (dynamic provider credentials).
# Each run presents a short-lived signed token; Vault checks that it comes
# from this organization and this workspace before issuing a 20-minute token.
# ---------------------------------------------------------------------------
resource "vault_jwt_auth_backend" "tfc" {
  path               = "tfc"
  type               = "jwt"
  description        = "HCP Terraform workload identity"
  oidc_discovery_url = "https://app.terraform.io"
  bound_issuer       = "https://app.terraform.io"
  # Vault refuses requests it cannot audit. Wait until the audit device has
  # finished setting up, or a parallel create can fail with "internal error".
  depends_on = [vault_audit.file]
}

resource "vault_jwt_auth_backend_role" "shed_vault_config" {
  backend   = vault_jwt_auth_backend.tfc.path
  role_name = var.tfc_workspace
  role_type = "jwt"

  bound_audiences   = ["vault.workload.identity"]
  bound_claims_type = "glob"
  bound_claims = {
    sub = "organization:${var.tfc_organization}:project:*:workspace:${var.tfc_workspace}:run_phase:*"
  }
  user_claim = "terraform_full_workspace"

  token_policies = [vault_policy.admin.name]
  token_ttl      = 1200
  token_max_ttl  = 7200
}

# ---------------------------------------------------------------------------
# Human login. Users are created by hand with the CLI so passwords never
# enter Terraform state (see README).
# ---------------------------------------------------------------------------
resource "vault_auth_backend" "userpass" {
  type        = "userpass"
  path        = "userpass"
  description = "Human administrators"
  # Vault refuses requests it cannot audit. Wait until the audit device has
  # finished setting up, or a parallel create can fail with "internal error".
  depends_on = [vault_audit.file]
}

# ---------------------------------------------------------------------------
# Namespace for everything the NAS agent touches.
# ---------------------------------------------------------------------------
resource "vault_namespace" "agent" {
  path = "agent"
  # Vault refuses requests it cannot audit. Wait until the audit device has
  # finished setting up, or a parallel create can fail with "internal error".
  depends_on = [vault_audit.file]
}

# ---------------------------------------------------------------------------
# Automated snapshots (Enterprise). Local copy on the encrypted share;
# an offsite target is added once chosen.
# ---------------------------------------------------------------------------
resource "vault_raft_snapshot_agent_config" "local" {
  name             = "local-hourly"
  interval_seconds = var.snapshot_interval_seconds
  retain           = var.snapshot_retain
  path_prefix      = "/vault/file/snapshots"
  storage_type     = "local"
  local_max_space  = 2147483648 # 2 GiB
  # Vault refuses requests it cannot audit. Wait until the audit device has
  # finished setting up, or a parallel create can fail with "internal error".
  depends_on = [vault_audit.file]
}
