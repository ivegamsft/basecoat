---
name: hybrid-branching-audit
description: "Audits repository readiness for hybrid branching (trunk + release/hotfix + agent lanes) and outputs a gap-ranked report. USE FOR: branch policy readiness audits, merge-lane control checks, downstream repo adoption readiness, and governance evidence exports. DO NOT USE FOR: implementing workflow changes, editing branch protections directly, or feature development."
compatibility:
  - github-copilot-cli
visibility: public
category: operations
metadata:
  category: flow-governance
  domain: branching-strategy
  maturity: production
  audience:
    - maintainer
    - release-manager
    - platform-engineer
allowed-tools:
  - git
  - gh
  - bash
---
# Hybrid Branching Audit Skill

Run this skill when you need an evidence-based readiness audit before adopting the hybrid branching strategy.

## Workflow

1. Collect branch, protection, check, and merge workflow evidence.
2. Validate branch taxonomy coverage (`main`, `release/*`, `hotfix/*`, `agent/*`, `feature/*`, `maintenance/*`).
3. Evaluate lane governance contracts (required checks, approvals, escalation thresholds).
4. Assess agent PR metadata readiness and traceability coverage.
5. Score readiness by severity and identify blockers versus advisories.
6. Produce a downstream-safe audit package with prioritized remediations.

## Output contract

Every run must produce:

1. Scope and timestamp.
2. Pass/fail matrix for policy, lane, and metadata controls.
3. Gap list with severity and owner recommendation.
4. Dependency map and impact summary.
5. Rollout readiness decision (`ready`, `ready-with-conditions`, `not-ready`).

## References and templates

- `references/audit-checklist.md`
- `templates/audit-report-template.md`
