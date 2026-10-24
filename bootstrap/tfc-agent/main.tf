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

  # Set explicitly: when left unset, the provider returns an empty map after
  # an update and Terraform reports "inconsistent result after apply".
  metadata = {}

  services = {
    "tfc-agent" = {
      image          = "hashicorp/tfc-agent:${var.tfc_agent_version}"
      container_name = "tfc-agent"
      restart        = "unless-stopped"
      init           = true

      # Use Docker's default bridge instead of a per-project network. On a
      # per-project network, lookups go through Docker's embedded DNS
      # (127.0.0.11), which timed out on shed. The default bridge hands the
      # container shed's own resolvers directly.
      network_mode = "bridge"

      # "$$" becomes "$" after compose interpolation, so the shell sees $(cat ...).
      entrypoint = [
        "/bin/sh",
        "-c",
        "TFC_AGENT_TOKEN=\"$$(cat /run/secrets/tfc-agent-token)\" exec /home/tfc-agent/bin/tfc-agent",
      ]

      environment = {
        TFC_AGENT_NAME = var.agent_name
        # The image tag is pinned; upgrades happen by changing
        # tfc_agent_version and applying, not by the agent updating itself.
        TFC_AGENT_AUTO_UPDATE = "disabled"
      }

      volumes = [
        {
          type      = "bind"
          source    = var.token_host_path
          target    = "/run/secrets/tfc-agent-token"
          read_only = true
        },
        {
          # Public CA certificate for shed's Vault, so runs can verify its TLS.
          # Workspaces point VAULT_CACERT at this path.
          type      = "bind"
          source    = var.vault_ca_host_path
          target    = "/etc/shed/vault-ca.crt"
          read_only = true
        },
      ]

      # Hardening. The image already runs as the unprivileged tfc-agent user.
      cap_drop     = ["ALL"]
      security_opt = ["no-new-privileges:true"]
      mem_limit    = var.memory_limit
    }
  }
}
