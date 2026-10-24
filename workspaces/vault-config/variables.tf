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
