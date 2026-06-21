# PR Merge + Cloud Deploy Agent Pairing Design (Issue #1662)

**Issue:** #1662  
**Related finding:** `docs/audit/ci-cd-findings-2026-06-14.md` (Section "2. PR Merge Agent + Cloud Agent")

## Problem Statement

Merge completion and cloud deployment readiness are currently decoupled. This causes two failure modes: merge-first changes that are not deployment-safe, and late discovery of deploy blockers that are expensive to unwind.

- **Current behavior:** merge and deploy workflows run independently with no explicit handoff contract
- **Symptom:** PRs can merge while deployment preconditions are unmet, then fail later in environment-specific workflows
- **Underlying cause:** no shared readiness payload or ownership boundary between merge and deployment stages

## Decisions

### 1. Handoff Protocol

The merge stage must emit a structured handoff payload consumed by the deployment stage.

**Contract:** `deployment_handoff_v1`

| Field | Description | Source |
|---|---|---|
| `pr_number` | Merged PR number | merge-coordinator |
| `merge_sha` | Merge commit SHA | merge-coordinator |
| `target_branch` | Branch that received merge | merge-coordinator |
| `environment` | Intended deployment environment (`dev`, `staging`, `prod`) | PR metadata/label |
| `risk_tier` | `low`, `medium`, `high` deployment risk | merge-coordinator policy |
| `required_checks` | Required status checks and final states | branch protection + policy |
| `change_surface` | High-level touched areas (`agents/`, `skills/`, workflows, docs-only) | merge-coordinator |
| `rollback_reference` | Rollback plan link or runbook path | PR template metadata |
| `deploy_mode` | `advisory` or `blocking` | environment policy |

The merge coordinator publishes the handoff in machine-readable form (job output or artifact) and includes a human-readable summary in PR metadata.

### 2. Merge Gates and Deployment Readiness

Deployment readiness must be split into:

1. **Merge-time mandatory checks** (always blocking):
   - required CI checks are green
   - environment target is declared
   - rollback reference is present
2. **Deployment-time preflight checks** (executed by deployment agent):
   - environment credentials and approvals
   - resource quota/capacity/lock checks
   - policy/security preflight specific to target environment

This keeps merge latency low while preventing silent deploy fragility.

### 3. Deployment Veto Power

Deployment veto is **allowed but scoped**:

- **Blocking veto** for `prod` or explicitly high-risk changes when `deploy_mode=blocking`
- **Advisory veto** for lower environments (`dev`, `staging`) where merge remains valid but deployment is deferred

A blocking veto must surface as a required status context (for example, `deploy-readiness/prod`) so branch protection enforces it consistently.

## Operating Model

1. Merge coordinator evaluates merge-time mandatory checks.
2. On pass, merge coordinator emits `deployment_handoff_v1`.
3. Infrastructure deploy agent ingests payload and executes preflight.
4. Agent returns one of:
   - `approved` (proceed deploy)
   - `blocked` (hard veto; required context fails)
   - `deferred` (advisory veto; non-prod or non-blocking mode)
5. Result is written back as a status context and PR/deploy summary.

## Success Criteria

- [x] Handoff payload contract defined
- [x] Merge-time vs deploy-time gates defined
- [x] Veto policy bounded by environment and risk tier
- [x] Agent contract updates reflected in `merge-coordinator` and `infrastructure-deploy`

## Non-Goals

- Implementing new GitHub Actions workflows in this issue
- Enforcing dynamic risk scoring in runtime policy engines
- Reworking release topology beyond merge/deploy handoff

## Rollout Guidance

1. Add status context policy for `deploy-readiness/<env>` with `prod` required first.
2. Run advisory mode for `dev` and `staging` for one sprint.
3. Promote `staging` to blocking once false positives are below team threshold.
4. Track veto rates and mean time to resolution to calibrate risk tiers.
