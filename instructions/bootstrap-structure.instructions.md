---
description: "Use when designing or reviewing bootstrap scripts. Covers decomposition, idempotency, documentation, and cross-platform requirements."
applyTo: "**/bootstrap*.{ps1,sh}"
---

# Bootstrap Script Structure

Use this instruction when creating, reviewing, or restructuring bootstrap scripts for infrastructure, identity, or CI/CD setup.

## Expectations

- Bootstrap must be decomposed into **single-responsibility scripts** — one concern per script.
- Each script must be **idempotent** — safe to re-run without side effects (creates only if not exists, skips otherwise).
- Each script must have a **documentation header** (PowerShell help block or shell comment block).
- Both `.ps1` and `.sh` variants should exist for cross-platform CI compatibility.
- Each script must be **runnable standalone** — no hidden dependencies on other scripts running first.
- A top-level orchestrator may combine scripts, but it must not contain business logic itself.

## Decomposition Standard

| Script | Responsibility |
|--------|---------------|
| `bootstrap-identity.ps1/.sh` | Create service principal, managed identity, or app registration |
| `bootstrap-oidc.ps1/.sh` | Configure OIDC federated credentials for GitHub Actions |
| `bootstrap-state-backend.ps1/.sh` | Create Terraform state storage (Storage Account, S3, etc.) |
| `bootstrap-github-vars.ps1/.sh` | Push secrets and variables to GitHub repository |
| `bootstrap-rbac.ps1/.sh` | Assign RBAC roles to identities |
| `bootstrap.ps1/.sh` | Orchestrator — calls the above in order |

## Script Header Standard

Every bootstrap script must include a documentation block:

```powershell
<#
.SYNOPSIS
    Creates the Azure Storage Account for Terraform remote state.

.DESCRIPTION
    Provisions a resource group and storage account for Terraform state,
    enables versioning and soft-delete, and pushes state config to GitHub
    variables. Idempotent — skips creation if resources already exist.

.PARAMETER SubscriptionId
    Azure subscription ID. Auto-detected from 'az account show' if omitted.

.PARAMETER DryRun
    Show what would be created without making changes.

.EXAMPLE
    ./bootstrap-state-backend.ps1
    ./bootstrap-state-backend.ps1 -SubscriptionId "abc-123" -DryRun
#>
```

Bash equivalent:

```bash
#!/usr/bin/env bash
# bootstrap-state-backend.sh — Create Terraform state backend
#
# Usage: ./bootstrap-state-backend.sh [--subscription-id ID] [--dry-run]
#
# Creates resource group and storage account for Terraform remote state.
# Idempotent — skips creation if resources already exist.
```

## Idempotency Patterns

```powershell
# Check before creating
$existing = az group show -n $rgName 2>$null
if (-not $existing) {
    az group create -n $rgName -l $location
    Write-Host "Created resource group: $rgName"
} else {
    Write-Host "Resource group already exists: $rgName (skipping)"
}
```

## Anti-Patterns

- **Monolith script**: one 500-line script doing identity + OIDC + state + secrets + RBAC.
- **Hidden ordering**: script B silently fails if script A hasn't run, with no error message.
- **Non-idempotent**: `az group create` without checking existence first (may error or overwrite).
- **Missing documentation**: no synopsis, parameters, or examples.

## Review Lens

- Does each script have exactly one responsibility?
- Can each script be re-run safely without side effects?
- Does each script have a documentation header?
- Do both `.ps1` and `.sh` variants exist (or is there a tracked issue to add the missing one)?
- Does the orchestrator contain only sequencing logic, not business logic?
