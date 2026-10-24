variable "tfc_agent_token" {
  description = "HCP Terraform agent pool token for the 'shed' pool. Supply via TF_VAR_tfc_agent_token at run time; never put it in a file."
  type        = string
  sensitive   = true
}

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
