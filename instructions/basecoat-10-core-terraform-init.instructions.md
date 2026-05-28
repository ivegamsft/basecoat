---
description: "Use when running terraform init in bootstrap scripts or CI/CD pipelines. Ensures backend re-initialization doesn't block automation."
applyTo: "**/*.tf,**/*.yml,**/*.ps1,**/*.sh"
---

# Terraform Init Backend Handling

Use this instruction when writing or reviewing any automation that runs `terraform init`.

## Expectations

- **Bootstrap scripts**: always use `terraform init -reconfigure` when `backend.hcl` is regenerated from the same remote state.
- **CI/CD workflows**: always use `terraform init -reconfigure` — runners start with a fresh workspace each run.
- **Never** use bare `terraform init` in automation — always specify backend behavior explicitly.
- Reserve `-migrate-state` for intentional migrations between different backend locations (e.g., local → remote, bucket A → bucket B).

## Why

When `backend.hcl` is regenerated (common during bootstrap re-runs), bare `terraform init` prompts interactively:

```
Error: Backend configuration changed
A change in the backend configuration has been detected, which may require migrating existing state.
```

This blocks CI/CD pipelines and breaks unattended scripts. `-reconfigure` re-points the local `.terraform/` cache without prompting, which is safe when the state is already in the correct remote location.

## Correct Patterns

```powershell
# Bootstrap — backend.hcl just regenerated from same remote state
terraform init -reconfigure -backend-config="backend.hcl"

# CI/CD — always fresh workspace
terraform init -reconfigure -backend-config="backend.hcl" -input=false
```

## Anti-Patterns

```powershell
# WRONG — will prompt interactively if backend.hcl changed
terraform init -backend-config="backend.hcl"

# WRONG — migrate-state for a re-run that didn't change backends
terraform init -migrate-state -backend-config="backend.hcl"
```

## Review Lens

- Does any `terraform init` call in automation lack an explicit `-reconfigure` or `-migrate-state` flag?
- Is `-migrate-state` used only for actual backend migrations, not routine re-runs?
- Does the CI/CD step include `-input=false` to prevent any interactive prompts?
