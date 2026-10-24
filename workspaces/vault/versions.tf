terraform {
  required_version = ">= 1.13.0"

  required_providers {
    # Self-built from the provider's main branch with a patched API library,
    # published to the private registry (scripts/publish-provider.sh).
    synology = {
      source  = "app.terraform.io/derpwagon-lab/synology"
      version = "0.6.12-shed.1"
    }
  }
}

# Runs on the shed agent (workspace "shed-vault", execution mode Agent).
# Connection settings come from sensitive workspace environment variables:
#   SYNOLOGY_HOST, SYNOLOGY_USER, SYNOLOGY_PASSWORD, SYNOLOGY_OTP_SECRET,
#   SYNOLOGY_SKIP_CERT_CHECK=true
provider "synology" {}
