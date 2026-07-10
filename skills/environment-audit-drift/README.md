# Environment Audit Drift Skill - Integration Guide

The `environment-audit-drift` skill continuously validates that your `.github/environment-map.yml` matches actual infrastructure and GitHub configuration state.

## Setup

### 1. Install the skill package

```bash
npm install @basecoat/environment-audit-drift
# or yarn / pnpm
```

### 2. Add the workflow

Copy `templates/audit-environment-drift.yml` to `.github/workflows/`:

```bash
cp skills/environment-audit-drift/templates/audit-environment-drift.yml \
   .github/workflows/audit-environment-drift.yml
```

### 3. Configure triggers

Edit the workflow to match your schedule:

```yaml
on:
  schedule:
    - cron: '0 6 * * *'         # Daily at 06:00 UTC
  workflow_dispatch:            # Manual trigger
  push:
    paths:
      - '.github/environment-map.yml'  # Auto-run on config changes
```

### 4. (Optional) Set up notifications

The workflow can post drift findings as:

- GitHub Issue comments
- Slack notifications (requires webhook)
- Email alerts (requires action)

See workflow template for configuration.

## Usage

### Manual audit

```bash
npx @basecoat/environment-audit-drift \
  --config .github/environment-map.yml \
  --subscription YOUR_AZURE_SUBSCRIPTION_ID \
  --output drift-report.json
```

### Programmatic usage (in agents)

```typescript
import { auditEnvironmentDrift, driftIsCritical } from '@basecoat/environment-audit-drift';

const report = await auditEnvironmentDrift({
  config_path: '.github/environment-map.yml',
  azure_subscription_id: process.env.AZURE_SUBSCRIPTION_ID,
  github_token: process.env.GITHUB_TOKEN,
  release_manifest_path: '.release/manifest.json',
  app_config_key_check: true,
});

if (driftIsCritical(report)) {
  console.warn('Critical drift detected:', report.findings);
  // Escalate or block deployment
}
```

### Consume drift status in your workflow

```typescript
const report = await auditEnvironmentDrift({ ... });
if (driftIsCritical(report)) {
  throw new Error('Cannot proceed: critical environment drift detected');
}
```

## What Gets Audited

| Category | Check | Why It Matters |
|----------|-------|----------------|
| **Config Drift** | Does Azure resource exist? (RG, CAE, LAW, AppConfig, KV) | Resolver can't route to missing resources |
| **Config Drift** | Does GitHub Environment exist? | Deployments fail if environment is missing |
| **Deployment Drift** | Does deployed version match release manifest? | Agents might act on stale version info |
| **Security Drift** | Do GitHub branch protection rules match autonomy levels? | Approval gates could be bypassed |
| **Tag Drift** | Do Azure resources have required tags (`Environment`, `App`, `ManagedBy`, `ReleaseId`)? | Cost allocation, release traceability, compliance reporting fail |

## Output Format

```json
{
  "audit_id": "550e8400-e29b-41d4-a716-446655440000",
  "timestamp": "2026-06-14T06:00:00Z",
  "config_file": ".github/environment-map.yml",
  "total_drifts": 2,
  "severity_summary": {
    "critical": 0,
    "high": 2,
    "medium": 0,
    "low": 0
  },
  "findings": [
    {
      "id": "config-resource-missing-container-apps",
      "environment": "prod",
      "severity": "high",
      "category": "config_drift",
      "finding": "Container Apps environment 'cae-app-prod' not found in Azure",
      "expected": "cae-app-prod",
      "actual": "not_found",
      "resource": "cae-app-prod",
      "remediation": "Create the Container Apps environment in Azure or update config",
      "timestamp": "2026-06-14T06:00:00Z"
    },
    {
      "id": "security-approval-mismatch-main",
      "environment": "prod",
      "severity": "high",
      "category": "security_drift",
      "finding": "Branch 'main' is A2 (approval-gated) but GitHub shows 0 required approvals",
      "expected": "1+ required approval",
      "actual": "0",
      "resource": "main",
      "remediation": "Update GitHub branch protection rules to require 1+ approval",
      "timestamp": "2026-06-14T06:00:00Z"
    }
  ],
  "resolved_drifts": 0,
  "actionable": true,
  "validation_duration_ms": 3241,
  "next_audit": "2026-06-15T06:00:00Z"
}
```

## Interpreting Findings

### Severity Levels

- **Critical**: Blocks deployment or resolver function (fix immediately)
  - Missing resource groups, GitHub environments, or approval gate mismatches
  
- **High**: Reduces reliability, agent may act on stale data
  - Missing Container Apps, Log Analytics, Key Vault
  - Deployment version mismatches
  
- **Medium**: Operational risk, compliance/billing impact
  - Missing tags (cost allocation, compliance reporting)
  - Stale release manifests
  
- **Low**: Advisory, no immediate action required
  - Minor configuration inconsistencies

### Actionable vs. Informational

- `actionable: true` - No critical drifts; safe to proceed
- `actionable: false` - Critical drifts found; needs manual review/fix

## Release manifest version comparison

Deployment drift compares release intent to deployed Container Apps revisions per environment.
Provide a `.release/manifest.json` with this shape:

```json
{
  "timestamp": "2026-06-14T06:00:00Z",
  "environments": {
    "prod": {
      "expected_version": "1.2.3",
      "deployed_revision": "1.2.2"
    },
    "staging": {
      "expected_version": "1.2.3",
      "deployed_revision": "1.2.3"
    }
  }
}
```

Supported aliases:

- `expected_version` or `release_version` for expected value
- `deployed_revision`, `deployed_version`, or `container_app_revision` for deployed value

## Common Scenarios

### Scenario 1: Adding a new environment

```yaml
# .github/environment-map.yml
environments:
  dr:  # New disaster recovery environment
    github_environment: 'dr'
    resource_group: 'rg-app-dr'
    # ... other config
```

**Next audit will find**:

- If you haven't created the Azure resources yet: `config_drift` findings with remediation steps
- If you create resources but forget GitHub environment: `config_drift` for GitHub environment

**Expected result**: After creating resources and GitHub environment, drift findings clear.

### Scenario 2: Promotion workflow broke

Release manifest shows version `1.2.3` but Container Apps shows `1.2.2`.

**Drift finder reports**:

- `deployment_drift` high severity
- Remediation: "Check promotion workflow or manually promote container image"

**Agent action**: Queries drift report before proceeding with version-dependent operations

### Scenario 3: Branch protection rule changed

Someone accidentally disabled the approval requirement on `main`.

**Drift finder reports**:

- `security_drift` high severity
- Finding: "main branch is A2 but GitHub shows 0 approvals required"
- Remediation: "Re-enable branch protection rule"

**Agent action**: Blocks PR merge if security drift is active

## Troubleshooting

### Audit fails with "Azure credential not found"

```bash
# Ensure you're authenticated with Azure CLI
az login
az account set --subscription <subscription-id>
```

### Audit fails with "GitHub token has insufficient permissions"

Ensure token has these scopes:

- `repo` (for GitHub Environments)
- `read:repo_hooks` (for branch protection rules)

### Drift report is empty

No drifts detected! This means:

- All Azure resources exist and are correctly named
- GitHub Environments match your config
- GitHub branch protection matches autonomy levels
- Azure tags are up-to-date

You're good to go!

## Advanced Options

### Strict mode (fail on any drift)

```bash
npx @basecoat/environment-audit-drift \
  --config .github/environment-map.yml \
  --strict
```

Exit code 1 if any drift found (useful for CI gates).

### Skip expensive checks

```bash
npx @basecoat/environment-audit-drift \
  --config .github/environment-map.yml \
  --skip-deployment-check  # Skip release manifest check
  --skip-tag-check         # Skip Azure tag validation
```

### Custom output format

```bash
npx @basecoat/environment-audit-drift \
  --config .github/environment-map.yml \
  --output-format json     # JSON (default)
  --output-format markdown # Markdown table
  --output-format junit    # JUnit XML (for CI)
```

## See Also

- [`operation-context-resolver`](../operation-context-resolver/) - Uses drift reports to gate operations
- [Workflow Template](./templates/audit-environment-drift.yml) - GitHub Actions configuration
- [Examples](./examples/) - Agent integration patterns
