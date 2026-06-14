---
name: environment-audit-drift
description: "Audit environment-map.yml against expected Azure and GitHub state to detect configuration, security, deployment, and tagging drift before automation runs. USE FOR: scheduled drift audits in CI, pre-deployment drift gates, identifying branch-protection mismatches to autonomy levels, and producing remediation-first findings for operators. DO NOT USE FOR: emergency incident execution paths, direct destructive infrastructure changes, or replacing policy engines that enforce approvals."
compatibility: GHCP
metadata:
  domain: platform-governance
  maturity: production
  audience:
    - maintainer
    - operator
allowed-tools:
  - bash
  - git
  - gh
visibility: public
---

# Environment Audit Drift

Validates that environment configuration stays aligned with infrastructure and governance settings.

## What it checks

- Config drift: mapped resources and GitHub environments
- Deployment drift: manifest/version expectations
- Security drift: branch protection vs autonomy level
- Tag drift: required resource tags

## Output

`DriftReport` contains:

- Severity summary (`critical`, `high`, `medium`, `low`)
- Findings with remediation guidance
- `actionable` flag (`false` when critical drift exists)

## Usage

```typescript
const report = await auditEnvironmentDrift({
  config_path: ".github/environment-map.yml",
  azure_subscription_id: process.env.AZURE_SUBSCRIPTION_ID!,
  github_token: process.env.GITHUB_TOKEN!,
});

if (driftIsCritical(report)) {
  throw new Error("Critical drift detected.");
}
```

## Artifacts

- Workflow template: `templates/audit-environment-drift.yml`
- Integration guide: `README.md`
- Types: `src/types.ts`
