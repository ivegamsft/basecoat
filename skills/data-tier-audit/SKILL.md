---
name: data-tier-audit
compatibility: [github-copilot-cli]
description: "Use when reviewing schemas, migrations, indexes, query plans, or data contract safety. USE FOR: audit schema drift, migration rollback safety, index health, query risk, repository patterns. DO NOT USE FOR: UI copywriting, infrastructure-only tasks, generic code review."
---
# Data Tier Audit Skill

Review data-layer changes for schema drift, migration safety, query risk, and index health.

## USE FOR

- Auditing schema changes and data contract drift
- Reviewing migrations for reversibility and rollout safety
- Checking indexes, pagination, and query plans for performance risk
- Verifying repository and data-access patterns remain consistent

## DO NOT USE FOR

- UI copywriting or visual design
- Infrastructure-only changes with no data-layer impact
- Generic code review without a data concern
- Fixing runtime bugs outside the data layer

## Workflow

1. Compare the proposed schema or migration against existing contracts.
2. Verify rollback support, nullability changes, and backfill risk.
3. Inspect queries for N+1 patterns, scans, and missing indexes.
4. Check data integrity, ownership boundaries, and repository patterns.
5. Summarize findings with severity, evidence, and remediation.

## Output

Return:

- Verdict: pass, pass with notes, or request changes
- Findings with severity and evidence
- Rollback and backfill risks
- Suggested remediation steps

## Related Agent

Use with `data-tier` agent.


