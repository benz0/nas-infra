variable "vault_version" {
  description = "hashicorp/vault-enterprise image tag. Pinned so upgrades are deliberate."
  type        = string
  default     = "2.2.1-ent"
}

variable "api_addr" {
  description = "Address clients use to reach Vault, e.g. https://<shed-address>:8200. Set as a workspace variable."
  type        = string
}

variable "host_data_root" {
  description = "Absolute path of the encrypted shared folder that holds Vault's config, data and logs."
  type        = string
  default     = "/volume1/hcv-data"
}

variable "published_port" {
  description = "Host port for Vault's API and UI."
  type        = number
  default     = 8200
}

variable "memory_limit" {
  description = "Container memory cap."
  type        = string
  default     = "1g"
}
