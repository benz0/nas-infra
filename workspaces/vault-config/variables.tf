variable "tfc_organization" {
  description = "HCP Terraform organization allowed to log in to Vault with workload identity."
  type        = string
  default     = "derpwagon-lab"
}

variable "tfc_workspace" {
  description = "HCP Terraform workspace that manages this configuration."
  type        = string
  default     = "shed-vault-config"
}

variable "snapshot_interval_seconds" {
  description = "How often Vault takes an automated raft snapshot."
  type        = number
  default     = 3600
}

variable "snapshot_retain" {
  description = "How many local snapshots to keep (72 hourly snapshots = 3 days)."
  type        = number
  default     = 72
}

variable "oidc_issuer" {
  description = "Base issuer URL for identity tokens from the agent namespace. Tokens carry <this>/v1/agent/identity/oidc as iss."
  type        = string
  default     = "https://vault.shed.benz0.com"
}

variable "oidc_key_rotation_seconds" {
  description = "Signing key rotation period. Long on purpose: every rotation means re-uploading the JWKS to Anthropic."
  type        = number
  default     = 31536000 # 365 days
}

variable "agent_cidrs" {
  description = "Networks the agent container may log in and use tokens from (Docker bridge networks)."
  type        = list(string)
  default     = ["172.16.0.0/12"]
}
