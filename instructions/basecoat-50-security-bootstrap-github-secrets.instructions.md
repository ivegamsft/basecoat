---
description: "Use when writing bootstrap scripts that provision identity or infrastructure for GitHub Actions. Ensures CI/CD secrets and variables are pushed automatically."
applyTo: "**/bootstrap*github*.{ps1,sh},**/bootstrap*secret*.{ps1,sh},**/bootstrap*vars*.{ps1,sh},scripts/*github*.{ps1,sh},scripts/*secret*.{ps1,sh},scripts/*vars*.{ps1,sh}"
---

# Bootstrap GitHub Secrets Integration

Use this instruction for any bootstrap script that creates values consumed by GitHub Actions workflows.

## Expectations

- Bootstrap scripts **must** use `gh secret set` and `gh variable set` to push configuration to GitHub immediately after creation.
- Non-secret identifiers go to **variables**: subscription ID, tenant ID, client ID, resource names, regions.
- Sensitive credentials go to **secrets**: client secrets (if OIDC is not possible), SAS tokens, connection strings.
- **Bootstrap is reserved for chicken-egg setup** (first-run identity/bootstrap dependencies). It is not the long-term mechanism for routine value propagation.
- If IaC or a workflow **generates** a value needed by downstream workflows, it must push that value to GitHub Secrets/Variables immediately in the same automation path.
- Generated values needed by "next workflow" steps are first-class outputs: publish them as soon as they exist (secret/variable classification still applies).
- Provide a `-SkipGitHubVars` flag for air-gapped or testing scenarios.
- When skipping, print the equivalent `gh` commands so users can run them manually.

## Secret vs Variable Classification

| Value | Target | Rationale |
|-------|--------|-----------|
| `AZURE_CLIENT_ID` | `gh variable set` | Public app identifier, not sensitive |
| `AZURE_TENANT_ID` | `gh variable set` | Public directory identifier |
| `AZURE_SUBSCRIPTION_ID` | `gh variable set` | Public subscription identifier |
| `TF_STATE_BUCKET` | `gh variable set` | Infrastructure metadata |
| `AZURE_CLIENT_SECRET` | `gh secret set` | Sensitive credential (prefer OIDC instead) |

## Correct Pattern

```powershell
param(
    [string]$Repository,
    [switch]$SkipGitHubVars
)

if (-not $Repository) {
    $remoteUrl = git config --get remote.origin.url
    $Repository = ($remoteUrl -replace '.*github\.com[:/]' -replace '\.git$')
}

if ($SkipGitHubVars) {
    Write-Host "Skipping GitHub integration. Run these manually:"
    Write-Host "  gh variable set AZURE_CLIENT_ID --body '$appId' -R $Repository"
    Write-Host "  gh variable set AZURE_TENANT_ID --body '$tenantId' -R $Repository"
    Write-Host "  gh variable set AZURE_SUBSCRIPTION_ID --body '$subscriptionId' -R $Repository"
} else {
    gh variable set AZURE_CLIENT_ID --body $appId -R $Repository
    gh variable set AZURE_TENANT_ID --body $tenantId -R $Repository
    gh variable set AZURE_SUBSCRIPTION_ID --body $subscriptionId -R $Repository
    Write-Host "GitHub variables set for $Repository"
}
```

## Anti-Patterns

```powershell
# WRONG — manual copy-paste required
Write-Host "Now go to Settings > Secrets and add AZURE_CLIENT_ID = $appId"

# WRONG — non-secret value stored as secret (wastes secret quota, harder to debug)
gh secret set AZURE_SUBSCRIPTION_ID --body $subscriptionId -R $Repository
```

## Review Lens

- Does the bootstrap script push all required values to GitHub after provisioning?
- Are non-secret values stored as variables, not secrets?
- Are generated values from IaC/workflows published to GitHub immediately when downstream workflows depend on them?
- Is bootstrap usage limited to chicken-egg initialization rather than ongoing operational sync?
- Is there a `-SkipGitHubVars` escape hatch?
- Does the skip path print the manual commands?
