# HCP Terraform agent on shed.
#
# The agent only makes outbound connections (app.terraform.io and friends).
# It needs no published ports. It reaches the DSM API and, later, Vault over
# the LAN from inside the default bridge network.

resource "synology_container_project" "tfc_agent" {
  name       = "tfc-agent"
  share_path = "/docker/tfc-agent"
  run        = true

  services = {
    "tfc-agent" = {
      image          = "hashicorp/tfc-agent:${var.tfc_agent_version}"
      container_name = "tfc-agent"
      restart        = "unless-stopped"
      init           = true

      environment = {
        TFC_AGENT_TOKEN = var.tfc_agent_token
        TFC_AGENT_NAME  = var.agent_name
      }

      # Hardening. The image already runs as the unprivileged tfc-agent user.
      cap_drop     = ["ALL"]
      security_opt = ["no-new-privileges:true"]
      mem_limit    = var.memory_limit

      # Keep container logs from filling the volume.
      logging = {
        driver = "json-file"
        options = {
          "max-size" = "10m"
          "max-file" = "3"
        }
      }
    }
  }
}
