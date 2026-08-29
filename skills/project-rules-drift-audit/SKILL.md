---
name: project-rules-drift-audit
compatibility: [github-copilot-cli]
description: "Audits GitHub Project automation rules against the canonical AIDL guardrail baseline. USE FOR: comparing live project rule configuration to a baseline manifest, classifying drift by severity, producing issue-ready remediation output, and running in advisory or enforce mode. DO NOT USE FOR: writing application code, direct project configuration changes, or replacing policy engines that manage approvals."
category: governance

metadata:
  category: governance
  domain: project-governance
  maturity: production
  audience:
    - maintainer
    - operator
allowed-tools:
  - bash
  - git
  - gh
visibility: public
model_policy:
  fallback: true
  preferred_families: [claude, gpt]
  upshift:
    allowed: true
    owner: runtime
    max_tier: reasoning
    triggers: [complexity, low_confidence]
  cost_tracking:
    budget_tier: low
    chargeback_tag: project-rules-drift-audit
---

# Project Rules Drift Audit Skill

Detect, classify, and remediate drift between live GitHub Project automation rules
and the canonical AIDL guardrail baseline.

## When to Use

- Scheduled drift detection for GitHub Project automation rules
- Pre-sprint governance health checks
- Generating issue-ready remediation items for drifted rules

## Workflow

1. Confirm `.github/workflows/project-rules-drift-audit.yml` exists (opt-in
   template workflow, not installed by default -- see
   `scripts/configure-downstream-workflows.ps1`). If missing, stop and
   report it with installation guidance:
   `pwsh scripts/configure-downstream-workflows.ps1 -InstallClass templates -Workflow project-rules-drift-audit.yml`.
2. Load baseline from `scripts/project-rules-baseline.json`.
3. Fetch live rules via `gh api graphql`.
4. Classify each delta: `missing`, `modified`, or `extra`.
5. Apply severity model and generate remediation rubric.
6. Emit JSON report and Markdown summary (`advisory` mode).
7. Open one GitHub issue per finding at or above threshold (`enforce` mode).

## Severity

| Severity | Trigger |
|---|---|
| `critical` | Required rule absent or disabled |
| `high` | Condition or action deviates from baseline |
| `medium` | Non-canonical configuration |
| `low` | Extra rule or cosmetic mismatch |

## Related Assets

- `agents/basecoat-50-security-project-rules-drift-auditor.agent.md`
- `scripts/project-rules-drift-audit.ps1`
- `scripts/project-rules-baseline.json`
- `.github/workflows/project-rules-drift-audit.yml`
- `docs/reference/project-rules-drift-auditor.md`
