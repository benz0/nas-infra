# Smoke test for the HCP Terraform agent on shed.
#
# Runs entirely on the agent (workspace execution mode: Agent, pool "shed").
# Proves the agent can run Terraform, download a provider from the public
# registry, and reach DSM on the LAN. Read-only: it calls DSM's unauthenticated
# API-info endpoint, logs in to nothing and creates no resources, so every
# plan should report "No changes" and the outputs below.

terraform {
  required_version = ">= 1.13.0"

  required_providers {
    http = {
      source  = "hashicorp/http"
      version = "~> 3.5"
    }
  }
}

variable "dsm_url" {
  description = "Base URL of DSM as seen from the agent, e.g. https://<shed-address>:<port>. Set as a workspace variable, not in the repo."
  type        = string
}

data "http" "dsm_api_info" {
  url = "${var.dsm_url}/webapi/query.cgi?api=SYNO.API.Info&version=1&method=query&query=SYNO.API.Auth"

  # DSM still uses its self-signed certificate. Read-only, LAN-only call.
  insecure = true

  request_timeout_ms = 15000
}

locals {
  dsm_response = jsondecode(data.http.dsm_api_info.response_body)
}

output "dsm_reachable" {
  description = "True when DSM answered the API-info query from the agent."
  value       = data.http.dsm_api_info.status_code == 200 && local.dsm_response.success
}

output "dsm_auth_api_max_version" {
  description = "Highest SYNO.API.Auth version DSM advertises (7 on DSM 7.x)."
  value       = local.dsm_response.data["SYNO.API.Auth"].maxVersion
}
