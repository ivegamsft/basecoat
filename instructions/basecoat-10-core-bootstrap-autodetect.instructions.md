---
description: "Use when writing or reviewing bootstrap scripts. Ensures scripts auto-detect values from context and run without interactive prompts."
applyTo: "**/bootstrap*.{ps1,sh},scripts/bootstrap*.{ps1,sh}"
---

# Bootstrap Auto-Detection

Use this instruction for any script that provisions infrastructure, configures identity, or sets up CI/CD pipelines.

## Expectations

- Bootstrap scripts **must not** use `Read-Host`, `read -p`, or any interactive prompt.
- All values must be resolved via a detection cascade: explicit parameter → environment variable → CLI context → project files → sensible default.
- Scripts must fail fast with a clear error message if a required value cannot be resolved from any source.
- Scripts must support a `-DryRun` (or `--dry-run`) flag that shows what would happen without making mutations.

## Detection Cascade

Resolve each required value in this order, stopping at the first hit:

| Priority | Source | Example |
|----------|--------|---------|
| 1 | Explicit parameter | `-SubscriptionId "abc-123"` |
| 2 | Environment variable | `$env:AZURE_SUBSCRIPTION_ID` |
| 3 | CLI context | `az account show --query id -o tsv` |
| 4 | Project files | Parse from `backend.hcl`, `terraform.tfvars` |
| 5 | Sensible default | Region → `eastus2`, environment → `dev` |

## Required Auto-Detection Targets

| Value | CLI Source |
|-------|-----------|
| Azure Subscription ID | `az account show --query id -o tsv` |
| Azure Tenant ID | `az account show --query tenantId -o tsv` |
| GitHub Repository | `git config --get remote.origin.url` (parsed to `owner/repo`) |
| Current User / SPN | `az ad signed-in-user show --query id -o tsv` |

## Correct Pattern

```powershell
param(
    [string]$SubscriptionId,
    [string]$TenantId,
    [switch]$DryRun
)

if (-not $SubscriptionId) { $SubscriptionId = $env:AZURE_SUBSCRIPTION_ID }
if (-not $SubscriptionId) { $SubscriptionId = (az account show --query id -o tsv 2>$null) }
if (-not $SubscriptionId) { throw "Cannot resolve SubscriptionId. Pass -SubscriptionId, set AZURE_SUBSCRIPTION_ID, or run 'az login'." }
```

## Anti-Patterns

```powershell
# WRONG — interactive prompt blocks CI/CD
$sub = Read-Host "Enter your subscription ID"

# WRONG — no fallback, no error
$sub = $env:AZURE_SUBSCRIPTION_ID  # silently null if not set
```

## Review Lens

- Does the script run unattended after `az login` / `gh auth login`?
- Does every required value have at least two resolution sources?
- Does the script fail with actionable error messages, not silent nulls?
- Is there a `-DryRun` flag for safe previewing?
