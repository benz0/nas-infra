# Bootstrap: HCP Terraform agent on shed

One-time bootstrap. Runs from your Mac (local execution) because the agent it
creates is what every later workspace will run on. State is stored in HCP
Terraform workspace `shed-bootstrap`.

## Prerequisites

- HCP Terraform org with an agent pool named `shed` and a token.
- Workspace `shed-bootstrap` created as **CLI-driven** with **Execution Mode: Local**
  (Settings > General). If it runs remotely, the plan can't reach the NAS.
- `terraform login` completed on your Mac.
- A DSM account in the Administrators group (Container Manager has no finer-grained role).
- The **self-built Synology provider** (see below). Release 0.6.11 can't manage
  projects on DSM 7.3.
- A **DSM firewall rule allowing Docker networks** (see below).
- The agent token written to `/volume1/docker/tfc-agent/secrets/agent-token` on the NAS.
  Terraform never sees it.

## Self-built Synology provider

Release 0.6.11 (April 2026) predates fixes that DSM 7.3 needs. Build the
provider from `main` against a patched copy of its API library:

```bash
# Library: same version the provider pins, with the per-call timeout raised
git clone https://github.com/TMAtwood/go-synology.git ~/code/go-synology
cd ~/code/go-synology
git checkout v0.1.12-fcg.5
sed -i '' 's/^var defaultTimeout = 30 \* time.Second$/var defaultTimeout = 10 * time.Minute/' pkg/api/client.go

# Provider: pinned commit, pointed at the patched library
git clone https://github.com/synology-community/terraform-provider-synology.git ~/code/terraform-provider-synology
cd ~/code/terraform-provider-synology
git checkout 6219694919bad2be5b0cd3f8b3c5ea02c11452ce
go mod edit -replace github.com/synology-community/go-synology=$HOME/code/go-synology
mkdir -p ~/terraform-providers
go build -o ~/terraform-providers/terraform-provider-synology .
```

Then tell Terraform to use it, in `~/.terraformrc`:

```hcl
provider_installation {
  dev_overrides {
    "registry.terraform.io/synology-community/synology" = "/Users/<you>/terraform-providers"
  }
  direct {}
}
```

Terraform prints a "development overrides are in effect" warning on every run.
That is expected. Remove the override once a release includes these fixes.

## DSM firewall and Docker

With the DSM firewall on, containers can't reach DNS (or anything else) until
Docker's address range is allowed. Add a rule above any Deny rule:
Ports **All**, Source **subnet 172.16.0.0 / 255.240.0.0**, Action **Allow**.
This rule is manual for now.

## Put the token on the NAS

macOS holds one SMB login per server name, so mount the `docker` share as the
admin user under a different name than your other shares (e.g. `shed.local`):

```bash
mkdir -p ~/shed-docker
mount_smbfs "//<dsm-admin-user>@<shed-name>/docker" ~/shed-docker
mkdir -p ~/shed-docker/tfc-agent/secrets
op item get '<token item>' --vault <vault> --fields credential --reveal > ~/shed-docker/tfc-agent/secrets/agent-token
umount ~/shed-docker
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

`op read` rejects item names containing parentheses; use `op item get` for those.

## Known provider issues

| Issue | Status | Handling here |
| --- | --- | --- |
| Login sends user, password and OTP code in the URL and prints it on failure | Open | Treat failed-login output as containing the password; rotate if shared |
| `services` rendered unredacted into `content` (plan output and state) | By design | Never put secrets in `environment`; token is a mounted file |
| `logging` options dropped (`logging: {}`) | Open | Not used |
| No read-only root filesystem option | Open | Not used |
| Stop/build/restart replies from DSM 7.3 not parsed ("unable to decode response") | Fixed in go-synology #84 and provider main (#218), unreleased | Self-built provider |
| Fixed 30-second limit per DSM call; a restart on the DS918+ takes about 60 seconds | Open | Patched library (10 minutes) |
| `metadata` null vs empty map: "inconsistent result after apply" | Open | `metadata = {}` set explicitly |
