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

## Run

```bash
cd bootstrap/tfc-agent

export SYNOLOGY_HOST="https://<shed-address>:<dsm-https-port>"
export SYNOLOGY_USER="<dsm-admin-user>"
export SYNOLOGY_PASSWORD="$(op read 'op://<vault>/<item>/password')"
export SYNOLOGY_SKIP_CERT_CHECK="true"
export TF_VAR_tfc_agent_token="$(op read 'op://<vault>/<item>/credential')"

terraform init
terraform plan
terraform apply

unset SYNOLOGY_PASSWORD TF_VAR_tfc_agent_token
```

## Known trade-offs

- The agent token is passed as an environment variable, so it is stored
  (encrypted) in this workspace's state in HCP Terraform. It moves behind
  Vault in a later phase.
- The provider's service schema has no read-only root filesystem option, so
  hardening here is dropped capabilities, no-new-privileges and a memory cap.
