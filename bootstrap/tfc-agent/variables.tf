variable "tfc_agent_version" {
  description = "hashicorp/tfc-agent image tag. Pinned so upgrades are deliberate."
  type        = string
  default     = "1.33.3"
}

variable "agent_name" {
  description = "Name the agent reports to HCP Terraform."
  type        = string
  default     = "shed-agent-1"
}

variable "memory_limit" {
  description = "Container memory cap. HCP Terraform agents need at least 2 GB."
  type        = string
  default     = "2g"
}

variable "token_host_path" {
  description = "Absolute path on the NAS of the file holding the agent pool token. Created by hand, never by Terraform, so the token never enters config, plan output or state."
  type        = string
  default     = "/volume1/docker/tfc-agent/secrets/agent-token"
}
