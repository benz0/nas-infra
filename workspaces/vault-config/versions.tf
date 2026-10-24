terraform {
  required_version = ">= 1.13.0"

  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "~> 5.13"
    }
  }
}

# Runs on the shed agent (workspace "shed-vault-config").
#
# Address, token and CA come from the run environment, never from code:
#   VAULT_ADDR     workspace env var (also set by HCP Terraform from TFC_VAULT_ADDR)
#   VAULT_CACERT   /etc/shed/vault-ca.crt, mounted into the agent
#   token          first run only: VAULT_TOKEN (sensitive, root token), then
#                  removed in favour of dynamic credentials (TFC_VAULT_*)
provider "vault" {
  # Required for HCP Terraform dynamic credentials, which manage the token.
  skip_child_token = true
}
