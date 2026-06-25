# Project Rules Drift Auditor

Detects drift between live GitHub Project (v2) automation rules and the canonical
AIDL guardrail baseline. Classifies findings by severity and supports advisory
and enforce execution modes.

## Overview

The auditor compares each automation rule in `scripts/project-rules-baseline.json`
against the live rules in a GitHub Project. It classifies every delta as `missing`,
`modified`, or `extra`, assigns a severity level, and produces a
deterministic JSON report and Markdown summary.

In enforce mode, it opens a GitHub issue for each finding that meets or exceeds
the configured severity threshold.

## Components

| Component | Path | Purpose |
|---|---|---|
| Agent | `agents/basecoat-50-security-project-rules-drift-auditor.agent.md` | Conversational drift audit with full workflow guidance |
| Skill | `skills/project-rules-drift-audit/SKILL.md` | Reusable protocol for project rule auditing |
| Script | `scripts/project-rules-drift-audit.ps1` | Automation script for local and CI use |
| Baseline | `scripts/project-rules-baseline.json` | Canonical AIDL guardrail rule definitions |
| Workflow | `.github/workflows/project-rules-drift-audit.yml` | Scheduled and on-demand CI integration |

## Severity Model

| Severity | Condition | Response |
|---|---|---|
| `critical` | Required guardrail rule absent or its action disabled | Block automation; open issue immediately |
| `high` | Rule condition or target deviates from baseline | Fix before next sprint; issue required |
| `medium` | Rule present but in a non-canonical configuration | Planned remediation |
| `low` | Extra rule or cosmetic mismatch | Advisory; backlog candidate |

## Drift Categories

| Category | Description |
|---|---|
| `missing` | Baseline rule not present in the live project |
| `modified` | Rule exists but enabled state differs from baseline |
| `extra` | Live rule not represented in the baseline |

## Running Locally

### Advisory mode (report only)

```powershell
pwsh scripts/project-rules-drift-audit.ps1 `
  -Repo "myorg/myrepo" `
  -ProjectUrl "https://github.com/orgs/myorg/projects/42" `
  -Mode advisory
```

### Enforce mode (open issues for high and above)

```powershell
pwsh scripts/project-rules-drift-audit.ps1 `
  -Repo "myorg/myrepo" `
  -ProjectUrl "https://github.com/orgs/myorg/projects/42" `
  -Mode enforce `
  -SeverityThreshold high `
  -AssumeYes
```

### Baseline-only validation (no live project)

Omit `-ProjectUrl` and `-ProjectId` to validate the baseline JSON without
comparing against a live project. The script will log "baseline-only mode"
and produce a clean report (zero findings) without making any GraphQL calls.

> **Note for CI:** For scheduled and push-triggered workflow runs, set the
> `PROJECT_RULES_AUDIT_URL` repository variable to your project URL so the
> audit compares live rules instead of running in baseline-only mode.

## CI Integration

The scheduled workflow at `.github/workflows/project-rules-drift-audit.yml` runs:

- Weekly on Mondays at 07:00 UTC
- On any push that modifies `scripts/project-rules-baseline.json`
- On demand via `workflow_dispatch` with configurable mode and threshold

The workflow uploads a `drift-report.json` artifact and opens a critical issue
when critical drift is detected.

### Triggering manually

```shell
gh workflow run project-rules-drift-audit.yml \
  --field mode=enforce \
  --field severity_threshold=high \
  --field project_url="https://github.com/orgs/myorg/projects/42"
```

## Maintaining the Baseline

The baseline manifest (`scripts/project-rules-baseline.json`) defines the set
of automation rules every AIDL-governed project must have. To update it:

1. Open a PR with the change and a clear rationale.
2. The CI workflow triggers automatically on merge and validates the JSON.
3. The next scheduled run compares live rules against the updated baseline.

### Adding a new required rule

```json
{
  "rule_id": "PRD-009",
  "name": "Auto-set assignee on PR open",
  "enabled": true,
  "condition": {
    "type": "pull_request_event",
    "event": "opened"
  },
  "action": {
    "type": "set_field",
    "field": "Assignees",
    "value": "@author"
  },
  "severity_if_missing": "medium",
  "rationale": "Ensures PR authors are always assigned for accountability tracking."
}
```

## Output Format

### JSON Report (`drift-report.json`)

```json
{
  "audit_id": "20260101120000-myorg-myrepo",
  "repo": "myorg/myrepo",
  "project_id": "PVT_...",
  "project_title": "Sprint 38 - Feature Execution",
  "baseline_version": "1.0.0",
  "mode": "advisory",
  "severity_filter": "low",
  "generated_at": "2026-01-01T12:00:00Z",
  "findings": [],
  "summary": {
    "total_findings": 0,
    "by_severity": { "critical": 0, "high": 0, "medium": 0, "low": 0 },
    "by_drift_type": { "missing": 0, "modified": 0, "extra": 0 }
  }
}
```

### Markdown Summary

```markdown
## Project Rules Drift Audit -- myorg/myrepo

**Project:** PVT_...
**Baseline:** v1.0.0
**Mode:** advisory
**Findings:** 0 (critical: 0, high: 0, medium: 0, low: 0)

No drift detected. All project rules match the baseline.
```

## Related Assets

- `agents/governance-auditor.agent.md` — broader governance auditing
- `agents/basecoat-50-security-policy-as-code-compliance.agent.md` — policy compliance
- `skills/governance-audit/SKILL.md` — metadata and label auditing
- `skills/flow-suggest/SKILL.md` — convert findings into backlog items
- `agents/agentic-sdlc-autonomy.agent.md` — SDLC governance context
