---
name: environment-audit-drift
description: "Detect and report drift between environment-map.yml and actual infrastructure state across Azure resources, GitHub environment settings, and deployment metadata. USE FOR: validating mapped resources before deployment workflows, catching branch-protection mismatches with autonomy levels, auditing required tagging coverage, and generating actionable remediation findings. DO NOT USE FOR: replacing real-time production incident response tooling, directly mutating infrastructure as part of audit execution, or bypassing manual approval requirements for critical drift."
compatibility: GHCP
requires:
  - "environment-map.yml in repo"
  - "Azure CLI context (subscription access)"
  - "GitHub token (Environment + branch protection read)"
  - "Optional: release manifest file"
provides:
  - "drift-report.json"
  - "Audit findings with severity + remediation"
  - "GitHub Actions workflow template"
eval_coverage:
  - Config resources are validated against Azure
  - Deployment versions match release manifest
  - GitHub branch protection aligns with autonomy levels
  - Azure resources have required tags
tags:
  - audit
  - drift-detection
  - environment-validation
  - infrastructure
---

# Environment Audit Drift Skill

Continuously validates that `.github/environment-map.yml` matches actual infrastructure state.

## Quick Start

### 1. Run audit manually

```bash
npx @basecoat/environment-audit-drift \
  --config-path .github/environment-map.yml \
  --output drift-report.json
```

### 2. Set up automated audits

Copy `templates/audit-environment-drift.yml` to `.github/workflows/` and configure:

```yaml
# .github/workflows/audit-environment-drift.yml

on:
  schedule:
    - cron: '0 6 * * *'  # Daily at 06:00 UTC
  workflow_dispatch:
  push:
    paths:
      - '.github/environment-map.yml'
```

### 3. Consume drift report in resolver

Resolver automatically checks drift status and includes in operation-context metadata:

```typescript
const context = await resolveOperationContext({ ... });
console.log(context.metadata.drift_status);  // 'clean' | 'warning' | 'critical'
```

## What It Audits

| Category | Checks | Severity if drift |
|----------|--------|-------------------|
| **Config Drift** | GitHub Environments exist, Azure resources exist (RG, CAE, LAW, AppConfig, KV) | Critical |
| **Deployment Drift** | Deployed version matches release manifest, Container Apps revision is current | High |
| **Security Drift** | GitHub branch protection rules match autonomy levels (A1-A4) | High |
| **Tag Drift** | Azure resources have required tags (Environment, App, ManagedBy, ReleaseId) | Medium |

## Output

```json
{
  "audit_id": "uuid",
  "timestamp": "2026-06-14T06:00Z",
  "total_drifts": 2,
  "severity_summary": {
    "critical": 0,
    "high": 2,
    "medium": 0,
    "low": 0
  },
  "findings": [
    {
      "id": "config-resource-missing",
      "environment": "prod",
      "severity": "high",
      "finding": "Container Apps environment 'cae-app-prod' not found",
      "remediation": "Create in Azure or update config"
    }
  ],
  "actionable": true
}
```

## See Also

- [README](./README.md) - Integration guide
- [Workflow Template](./templates/audit-environment-drift.yml) - CI/CD setup
- [operation-context-resolver](../operation-context-resolver/) - Companion skill (checks drift status)
