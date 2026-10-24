# Bootstrap: HCP Terraform agent on shed

One-time bootstrap. Runs from your Mac (local execution) because the agent it
creates is what every later workspace will run on. State is stored in HCP
Terraform workspace `shed-bootstrap`.

## Prerequisites

- HCP Terraform org `derpwagon-lab` with an agent pool named `shed` and a token.
- Workspace `shed-bootstrap` created as **CLI-driven** with **Execution Mode: Local**
  (Settings > General). If it runs remotely, the plan can't reach shed.
- `terraform login` completed on your Mac.
- A DSM account in the Administrators group (Container Manager has no finer-grained role).
- The agent token written to `/volume1/docker/tfc-agent/secrets/agent-token` on the NAS
  (see below). Terraform never sees it.

## Put the token on the NAS

Mount the `docker` share on your Mac (Finder > Go > Connect to Server, `smb://<shed-address>/docker`), then:

```bash
mkdir -p /Volumes/docker/tfc-agent/secrets
op item get '<token item>' --vault <vault> --fields credential --reveal > /Volumes/docker/tfc-agent/secrets/agent-token
```

The command line contains no secret, so nothing lands in shell history.

## Run

```bash
cd bootstrap/tfc-agent

export SYNOLOGY_HOST="https://<shed-address>:<dsm-https-port>"
export SYNOLOGY_USER="<dsm-admin-user>"
export SYNOLOGY_PASSWORD="$(op read 'op://<vault>/<item>/password')"
export SYNOLOGY_OTP_SECRET="$(op read 'op://<vault>/<item>/one-time password' | sed -E 's/.*[?&]secret=([^&]+).*/\1/')"
export SYNOLOGY_SKIP_CERT_CHECK="true"

terraform init
terraform plan
terraform apply

unset SYNOLOGY_PASSWORD SYNOLOGY_OTP_SECRET
```

## Known provider issues (synology-community/synology 0.6.11)

- **Credentials in URLs.** Login sends user, password and OTP code as GET query
  parameters and prints that URL when login fails. Treat any failed-login output
  as containing the password. Credentials can also appear in DSM web server logs.
- **Compose content is not redacted.** Everything in `services` is rendered into
  the `content` attribute, shown in plan output and stored in state. Never put a
  secret in `environment`.
- **Logging options are dropped.** A `logging` block renders as `logging: {}`,
  so log rotation must be set elsewhere.
- **No read-only root filesystem option** in the service schema.
