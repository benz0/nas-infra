# Vault Agent sidecar for the shed agent.
# Logs in with AppRole, then keeps a fresh Vault identity token (the Anthropic
# WIF credential) in /tokens/idtoken. No listener: nothing can talk to this
# container, and no Vault token is written anywhere.

pid_file = "/tmp/vault-agent.pid"

vault {
  address = "https://192.168.86.60:8200"
  ca_cert = "/vault/agent/ca.crt"
}

auto_auth {
  method "approle" {
    namespace = "agent"
    config = {
      role_id_file_path = "/vault/agent/role_id"

      # Ben drops a response-wrapped secret ID here before starting the project.
      # The agent unwraps it, keeps the secret ID in memory for re-logins,
      # and deletes the file. A restart needs a fresh wrapped secret ID.
      secret_id_file_path                 = "/secrets/wrapped-secret-id"
      secret_id_response_wrapping_path    = "auth/approle/role/claude-agent/secret-id"
      remove_secret_id_file_after_reading = true
    }
  }
}

template_config {
  # Identity tokens have no lease, so they are re-minted on this interval.
  # Tokens live 15 minutes, so a 5-minute refresh always leaves 10+ minutes.
  static_secret_render_interval = "5m"
  exit_on_retry_failure         = false
}

template {
  contents    = "{{ with secret \"identity/oidc/token/claude-agent\" }}{{ .Data.token }}{{ end }}"
  destination = "/tokens/idtoken"
  perms       = "0640"
}
