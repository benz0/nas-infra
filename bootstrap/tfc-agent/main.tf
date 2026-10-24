# HCP Terraform agent on shed.
#
# The agent only makes outbound connections (app.terraform.io and friends).
# It needs no published ports. It reaches the DSM API and, later, Vault over
# the LAN from inside the default bridge network.
#
# The agent token is NOT passed through Terraform. The synology provider
# renders services into a compose file that it prints in plan output and
# stores in state, so any environment value would leak. Instead the token
# lives in a file on the NAS, bind-mounted read-only, and the entrypoint
# exports it just before starting the agent.

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

      # "$$" becomes "$" after compose interpolation, so the shell sees $(cat ...).
      entrypoint = [
        "/bin/sh",
        "-c",
        "TFC_AGENT_TOKEN=\"$$(cat /run/secrets/tfc-agent-token)\" exec /home/tfc-agent/bin/tfc-agent",
      ]

      environment = {
        TFC_AGENT_NAME = var.agent_name
      }

      volumes = [{
        type      = "bind"
        source    = var.token_host_path
        target    = "/run/secrets/tfc-agent-token"
        read_only = true
      }]

      # Hardening. The image already runs as the unprivileged tfc-agent user.
      cap_drop     = ["ALL"]
      security_opt = ["no-new-privileges:true"]
      mem_limit    = var.memory_limit
    }
  }
}
