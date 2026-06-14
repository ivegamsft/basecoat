# Report Templates

## Audit Report Template

```markdown
# Agentic SDLC Autonomy Audit

## Executive Summary

Repository:
Current autonomy rating:
Current enforcement rating:
Primary bottlenecks:
Primary production risks:
Recommended next phase:

## Evidence Summary

| Area | Finding | Evidence | Risk | Recommendation |
|---|---|---|---|---|

## Autonomy Level Assessment

| Level | Current state | Gap | Recommendation |
|---|---|---|---|
| A0 observe/report |  |  |  |
| A1 safe edits |  |  |  |
| A2 normal feature work |  |  |  |
| A3 auto-merge eligible |  |  |  |
| A4 staging/canary eligible |  |  |  |
| A5 human-gated |  |  |  |

## Policy vs Settings Drift

| Policy expectation | Actual setting | Drift | Priority |
|---|---|---|---|

## Risk Register

| Risk | Evidence | Impact | Fix | Priority |
|---|---|---|---|---|

## Recommended Roadmap

1. phase 0: evidence and drift baseline
2. phase 1: autonomy policy and labels
3. phase 2: report-only classifier
4. phase 3: required checks and merge queue parity
5. phase 4: deployment/db/iac gates
6. phase 5: auto-merge and WIP enforcement
```

## Measurement Scorecard Template

```markdown
# Agentic SDLC Autonomy Scorecard

Scoring: 0 = absent, 1 = documented only, 2 = partial, 3 = enforced for some lanes, 4 = broadly enforced, 5 = mature and measured.

| Dimension | Score | Evidence | Gap | Next action |
|---|---:|---|---|---|
| autonomy clarity |  |  |  |  |
| risk classification coverage |  |  |  |  |
| branch protection enforcement |  |  |  |  |
| environment protection enforcement |  |  |  |  |
| required check coverage |  |  |  |  |
| merge queue enforcement |  |  |  |  |
| CODEOWNERS/high-risk ownership |  |  |  |  |
| security gates |  |  |  |  |
| DB migration safety |  |  |  |  |
| IaC safety |  |  |  |  |
| runner isolation |  |  |  |  |
| agent WIP/stale lifecycle |  |  |  |  |
| release/rollback traceability |  |  |  |  |
| policy/settings parity |  |  |  |  |

## Queue Metrics

| Metric | Current | Threshold | Status |
|---|---:|---:|---|
| open agent PRs |  |  |  |
| open high-risk PRs |  |  |  |
| median PR age |  |  |  |
| stale PR count |  |  |  |
| merge queue wait time |  |  |  |
| average changed lines per PR |  |  |  |
| auto-merge eligible percentage |  |  |  |
| human-gated percentage |  |  |  |
```

## Implementation Plan Template

```markdown
# Agentic SDLC Autonomy Implementation Plan

## Scope

This PR implements:
This PR does not implement:

## Files to Change

| File | Purpose | Risk |
|---|---|---|

## Validation

- [ ] policy workflow runs in report-only mode
- [ ] classifier correctly detects docs-only low risk
- [ ] classifier correctly detects DB/IaC/workflow high risk
- [ ] classifier correctly detects destructive critical patterns
- [ ] no deployment, migration, or infrastructure apply runs

## Manual Settings Required

- branch protection:
- environment protection:
- merge queue:
- required checks:
- runner groups:

## Rollback

- revert policy PR
- disable new workflow
- remove new required checks if they were added
- restore previous branch/environment settings

## Future Enforcement Steps

1. report-only
2. warning mode
3. blocking for high-risk labels
4. blocking for auto-merge eligibility
5. full enforcement
```

## Agent Prompt Template

```text
You are an implementation agent for this repository.

Goal: implement rules-based human-in-the-loop autonomy so agents can handle
routine SDLC work while high-risk actions require human approval.

Do not deploy.
Do not run production database migrations.
Do not apply infrastructure.
Do not change secrets.
Do not alter branch protection or environment protection directly.
Do not bypass checks.

Implement a small reversible PR that:
1. adds or updates autonomy policy documentation
2. adds PR risk labels and path-based classification rules
3. adds a report-only GitHub Actions classifier workflow
4. classifies changes as low, medium, high, or critical risk
5. emits one of: auto-merge-eligible, stronger-checks-required, human-approval-required, plan-only-required
6. documents manual settings required for enforcement
7. includes validation and rollback instructions

Output files changed, validation steps, manual settings, and rollback instructions.
```
