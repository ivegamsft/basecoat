# Task Scope Validator — Detail Reference

## Classification Checks

### Check 1: Single Issue / Single Outcome

Pass: targets one issue/PR/feature; one identifiable outcome.
Fail: multiple independent outcomes; open-ended exploration without bounding issue.

### Check 2: Deterministic Path

Pass: steps to completion known or strongly inferrable; repeatable substeps; no subjective judgment.
Fail: discovering unknown unknowns; success hinges on human creativity; conditional on external events.

### Check 3: Success Measurability

Pass: objectively verifiable (PR merged, test passes, file created); explicit acceptance criteria.
Fail: vague success ("improve the system"); requires subjective approval.

### Check 4: Time-Bounded

Pass: <5 min for explore agents; <60 min for task/general-purpose; no external waits.
Fail: exceeds time bounds; requires back-and-forth; depends on long-running processes.

## Classification Decisions

| Classification | Condition |
|---|---|
| `automatable` | All checks pass; ready to dispatch |
| `gather-findings-only` | Checks 1-3 pass; exploration-only, no execution |
| `defer` | One or more checks fail significantly; needs refinement |

Dispatch rules: approve if `automatable` with confidence ≥0.8; caution if 0.6–0.79; require refinement if `defer` or <0.6.

## Output JSON Schema

```json
{
  "task_id": "string",
  "classification": "automatable | gather-findings-only | defer",
  "confidence": 0.0,
  "checks": {
    "single_issue": { "pass": true, "evidence": "string" },
    "deterministic_path": { "pass": true, "evidence": "string" },
    "success_measurable": { "pass": true, "evidence": "string" },
    "time_bounded": { "pass": true, "estimated_minutes": 0, "evidence": "string" }
  },
  "recommended_agent": "explore | task | general-purpose | escalate",
  "risks": ["string"],
  "remediation_suggestions": [
    { "category": "scope | clarity | criteria | time", "suggestion": "string", "example": "string" }
  ],
  "approved_for_dispatch": true,
  "notes": "string"
}
```

## Example: Passing Task

Input: `scope-check: Review PR #123 and post a code review comment on Authentication.ts flagging missing error handling.`

Result: `automatable`, confidence 0.95, all checks pass, recommended agent: `task`.

## Example: Failing Task

Input: `scope-check: Analyze our entire codebase to find performance issues and suggest architectural improvements.`

Result: `defer`, confidence 0.15, all checks fail, recommended agent: `escalate`.

Remediation suggestions:

- Scope: "Narrow to a single service or module."
- Criteria: "Define success: measurable metrics, specific recommendations, or ranked list."
- Time: "Break into smaller tasks or use general-purpose agent for design work."

## Integration Points

- Pre-dispatch validation before invoking explore, task, or general-purpose agents.
- Orchestrator pre-flight check in multi-agent pipelines.
- Manual override: `--force` flag bypasses checks and logs the override.
- Reference: [Decision Tree](../../docs/diagrams/task-scope-validator-decision-tree-and-dispatch-policy.md)
