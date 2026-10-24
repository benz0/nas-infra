terraform {
  required_version = ">= 1.13.0"

  # State lives in HCP Terraform. This workspace uses LOCAL execution:
  # plans and applies run on your Mac (the agent doesn't exist yet),
  # but state is stored and encrypted in HCP Terraform, never on disk or in git.
  cloud {
    organization = "derpwagon-lab"

    workspaces {
      name = "shed-bootstrap"
    }
  }

  required_providers {
    # Self-built from the provider's main branch with a patched API library,
    # published to the private registry (scripts/publish-provider.sh).
    # Pre-release versions must be pinned exactly.
    synology = {
      source  = "app.terraform.io/derpwagon-lab/synology"
      version = "0.6.12-shed.1"
    }
  }
}

# Connection settings come from environment variables so nothing
# site-specific or secret is committed:
#   SYNOLOGY_HOST, SYNOLOGY_USER, SYNOLOGY_PASSWORD
#   SYNOLOGY_SKIP_CERT_CHECK=true  (until shed has a trusted certificate)
provider "synology" {}
