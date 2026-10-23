# nas-infra

Infrastructure as code for a home Synology NAS that hosts a resident, model-agnostic AI agent, secured with HashiCorp Vault Enterprise and managed with HCP Terraform.

> Status: phase 1 (prep). This repo is private for now and written as if it were public. A sanitized public version will be published later.

## What this builds

- **Agent slot:** a locked-down container on the NAS that runs tasks from a file-based inbox with a pluggable agent CLI (Claude Code first, Goose second).
- **Vault Enterprise:** the only source of the agent's credentials, with Control Groups for human approval of privileged actions and Agentic IAM (agent registry, on-behalf-of tokens, RAR) for identity.
- **HCP Terraform:** VCS-driven runs executed by an agent container on the NAS, with applies approved in the web UI.

## Rules for this repo

- No secrets, ever. Credentials live in Vault or 1Password, never in code, tfvars or commit messages.
- Site-specific values (hostnames, addresses, usernames) go in `*.tfvars`, which git ignores. Each layer ships a `*.tfvars.example` with placeholders.
- State lives in HCP Terraform, never in git.
- Changes land through pull requests so every plan is reviewed before apply.
