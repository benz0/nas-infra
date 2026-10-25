terraform {
  required_version = ">= 1.13.0"

  required_providers {
    b2 = {
      source  = "Backblaze/b2"
      version = "~> 0.14"
    }
  }
}

# Runs on the shed agent (workspace "shed-backup", execution mode Agent).
# Credentials come from sensitive workspace environment variables:
#   B2_APPLICATION_KEY_ID, B2_APPLICATION_KEY   (1Password: "Backblaze B2 - terraform")
provider "b2" {}
