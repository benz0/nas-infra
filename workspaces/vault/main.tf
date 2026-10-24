# Vault Enterprise on shed: single node, integrated storage (raft).
#
# Layout of the encrypted shared folder (created by hand, see README):
#   <host_data_root>/config/            -> /vault/config   (rendered config, TLS, license)
#   <host_data_root>/config/tls/        vault.crt, vault.key   (placed by hand)
#   <host_data_root>/config/license/    vault.hclic            (placed by hand)
#   <host_data_root>/data/raft/         -> /vault/file/raft (storage)
#   <host_data_root>/logs/              -> /vault/logs      (audit log)
#
# Secrets (TLS key, license) never pass through Terraform: they are files on
# the encrypted share. The provider renders this whole service into compose
# content that appears in plan output and state, so nothing secret goes here.

locals {
  vault_config = {
    ui            = true
    disable_mlock = true # recommended with integrated storage
    api_addr      = var.api_addr
    cluster_addr  = "https://127.0.0.1:8201"
    license_path  = "/vault/config/license/vault.hclic"

    listener = [{
      tcp = {
        address         = "0.0.0.0:8200"
        cluster_address = "0.0.0.0:8201"
        tls_cert_file   = "/vault/config/tls/vault.crt"
        tls_key_file    = "/vault/config/tls/vault.key"
        tls_min_version = "tls12"
      }
    }]

    storage = {
      raft = {
        path    = "/vault/file/raft"
        node_id = "shed-vault-1"
      }
    }
  }
}

resource "synology_container_project" "vault" {
  name       = "shed-vault"
  share_path = "/docker/shed-vault"
  run        = true
  metadata   = {}

  services = {
    "vault" = {
      image          = "hashicorp/vault-enterprise:${var.vault_version}"
      container_name = "shed-vault"
      restart        = "unless-stopped"
      command        = ["server"]

      # The image's entrypoint writes this JSON to /vault/config/local.json.
      environment = {
        VAULT_LOCAL_CONFIG = jsonencode(local.vault_config)
      }

      # Start as root only so the entrypoint can chown the bind mounts, then
      # it drops to the unprivileged "vault" user via su-exec. These three
      # capabilities are all that step needs; everything else is dropped.
      user         = "0:0"
      cap_drop     = ["ALL"]
      cap_add      = ["CHOWN", "SETUID", "SETGID"]
      security_opt = ["no-new-privileges:true"]
      mem_limit    = var.memory_limit

      network_mode = "bridge"
      ports = [{
        target    = 8200
        published = tostring(var.published_port)
        protocol  = "tcp"
      }]

      volumes = [
        {
          type   = "bind"
          source = "${var.host_data_root}/config"
          target = "/vault/config"
        },
        {
          type   = "bind"
          source = "${var.host_data_root}/data"
          target = "/vault/file"
        },
        {
          type   = "bind"
          source = "${var.host_data_root}/logs"
          target = "/vault/logs"
        },
      ]
    }
  }
}
