# Project Rules Drift Auditor Agent — Detail Reference

Full severity model, remediation rubric, baseline manifest contract, and output format
examples for `agents/basecoat-50-security-project-rules-drift-auditor.agent.md`.

## Severity Model

| Severity | Condition | Expected Action |
|---|---|---|
| `critical` | Required guardrail rule is absent or its action is disabled | Block automation; file issue immediately |
| `high` | Rule condition or target field deviates from baseline | Fix before next sprint; issue required |
| `medium` | Rule is present but in a non-canonical configuration | Schedule remediation in planned work |
| `low` | Extra rule with no baseline entry or cosmetic mismatch | Advisory note; backlog if not needed |

## Remediation Rubric

For each finding include:

- Finding ID (stable, derived from rule ID and drift type)
- Rule name and baseline entry reference
- Drift type: `missing` | `modified` | `extra`
- Severity: `critical` | `high` | `medium` | `low`
- Evidence: baseline value vs live value (or absence)
- Remediation steps: exact configuration change or API call to resolve
- Effort estimate: `minutes` | `hours` | `days`

## Baseline Manifest Contract

The baseline manifest is a JSON file at `scripts/project-rules-baseline.json`.
Required fields per rule entry:

| Field | Type | Description |
|---|---|---|
| `rule_id` | string | Stable identifier used across audit runs |
| `name` | string | Human-readable rule name |
| `enabled` | boolean | Whether the rule must be active |
| `condition` | object | Field, operator, and value that triggers the rule |
| `action` | object | Action type and target field/value |
| `severity_if_missing` | string | Severity to assign when this rule is absent |
| `rationale` | string | Why this rule exists in the guardrail baseline |

## Output Format

### JSON Report

```json
{
  "audit_id": "<timestamp>-<repo>",
  "repo": "owner/repo",
  "project_id": "PVT_...",
  "baseline_version": "1.0.0",
  "mode": "advisory",
  "findings": [
    {
      "finding_id": "PRD-001-missing",
      "rule_id": "PRD-001",
      "rule_name": "Auto-assign priority on triage label",
      "drift_type": "missing",
      "severity": "high",
      "baseline_value": { "enabled": true, "condition": { "field": "label", "value": "triage" } },
      "live_value": null,
      "remediation": "Add automation rule: when label = 'triage', set Priority = 'P2'.",
      "effort": "minutes"
    }
  ],
  "summary": {
    "total_findings": 1,
    "by_severity": { "critical": 0, "high": 1, "medium": 0, "low": 0 },
    "by_drift_type": { "missing": 1, "modified": 0, "extra": 0 }
  }
}
```

### Markdown Summary

```markdown
## Project Rules Drift Audit — owner/repo

**Project:** PVT_...
**Baseline:** v1.0.0
**Mode:** advisory
**Findings:** 1 (critical: 0, high: 1, medium: 0, low: 0)

| Finding ID | Rule | Drift Type | Severity | Remediation |
|---|---|---|---|---|
| PRD-001-missing | Auto-assign priority on triage label | missing | high | Add automation rule: when label = 'triage', set Priority = 'P2'. |
```

## Determinism Requirements

- Output order is stable: sort findings by `severity` (critical first) then `rule_id`.
- The same baseline and live state always produces the same report.
- Timestamps are included for traceability but do not affect finding IDs or ordering.
- Use `gh api graphql` with pinned query variables; avoid non-deterministic pagination.
