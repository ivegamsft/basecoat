# Autonomy Policy Reference

## 1. Risk Rules

### Low Risk

Classify as low risk when all conditions are true:

- Changed lines are small, normally <= 300
- No protected paths are touched
- No production deployment, DB migration, IaC apply, security/auth, secrets, or GitHub governance files are touched
- No dependency major upgrade is present
- Tests and policy checks pass
- Rollback is trivial, such as reverting a PR

Examples:

- Docs updates
- Tests only
- Lint/format/type cleanup
- UI copy changes
- Small non-runtime refactors
- Small bug fix with targeted tests

Allowed autonomy: A1-A3. Agents may auto-merge if required checks pass.

### Medium Risk

Classify as medium risk when the change affects runtime behavior but stays within
normal app/package surfaces and does not touch protected paths.

Examples:

- Bounded web/API/mobile feature change
- API endpoint change with contract tests
- Non-breaking schema usage without migration
- Non-prod config update
- Dependency patch/minor update with clean scans

Allowed autonomy: A2-A4. Agents may auto-merge after stronger checks such as
integration, affected e2e smoke, contract tests, dependency review, and security checks.

### High Risk

Classify as high risk when the change touches sensitive surfaces even if the diff is small.

High-risk paths/patterns (defaults — configure per-repo in `classify_pr_risk` config):

```text
.github/workflows/**
.github/actions/**
.github/dependabot.yml
iac/**
infra/**
terraform/**
bicep/**
cloudformation/**
kubernetes/**
helm/**
charts/**
db/**
database/**
**/auth/**
**/security/**
**/permissions/**
**/secrets/**
**/.env*
**/Dockerfile
Dockerfile
```

High-risk action keywords:

```text
production
prod-full
workflow_dispatch
permissions:
id-token: write
secrets.
DATABASE_URL
kubectl apply
terraform apply
az deployment group create
```

Allowed autonomy: agents may prepare PRs, plans, dry runs, manifests, and
non-prod validations. Human approval is required for final high-risk gates.

### Critical Risk

Classify as critical when the change may cause data loss, production outage,
credential exposure, or governance bypass.

Critical patterns:

```text
DROP TABLE
DROP COLUMN
TRUNCATE
DELETE FROM
ALTER COLUMN
DROP DATABASE
az deployment group delete
az resource delete
kubectl delete
terraform destroy
federated credential
admin bypass
required_approving_review_count: 0
can_admins_bypass: true
```

Also classify as critical:

- Production DB migration
- Production IaC apply with destructive changes
- Secrets rotation or secret storage changes
- Auth provider migration
- Data deletion/backfill at production scale
- Branch protection or environment protection changes
- Runner group permission changes
- Emergency rollback or incident remediation

Allowed autonomy: plan-first. Agents may draft an implementation plan, dry-run
instructions, rollback plan, and validation checklist. Human authorization is
required before execution.

## 2. Auto-Merge Rules

Auto-merge is allowed only when all are true:

```text
risk is low or approved medium
required CI checks pass
policy/risk classifier passes
security checks pass
no protected path is touched
no unresolved comments
PR is not stale
branch is current or merge queue can rebase it
agent-authored label is present for agent PRs
rollback note is present
```

Block or human-gate auto-merge when:

```text
risk:high
risk:critical
human-approval-required
plan-only-required
protected path touched
production target touched
DB migration touched
IaC apply path touched
workflow permissions changed
secrets/auth/security touched
large PR override needed
```

## 3. WIP Limits

Adjust thresholds based on team size and review capacity.

Recommended starting defaults:

```text
max open low-risk agent PRs: 10
max open medium-risk agent PRs: 5
max open high-risk agent PRs: 2
max open critical-risk plans: 1
max active PRs per agent: 2
stale warning: 72 hours
stale close/regenerate: 7 days
large PR warning: 300 changed lines
large PR block: 600 changed lines unless override label exists
```

For tighter review capacity (small team or solo maintainer), reduce to:

```text
max open low-risk agent PRs: 5
max open medium-risk agent PRs: 3
max open high-risk agent PRs: 1
max active PRs per agent: 1
```

## 4. Deployment Rules

Recommended lane policy:

```text
preview/integration: agents allowed after checks
staging: agents allowed after release checks
prod-canary: agents allowed only for low/medium risk from immutable manifest, otherwise human-gated
prod-full: human approval always
hotfix: human approval always
```

Production deployment must require:

```text
protected environment
explicit human approval
immutable artifact or release manifest
post-deploy smoke test
rollback pointer
no agent-only approval
```

## 5. Database Rules

Non-prod migrations may run automatically after validation. Production migrations require:

```text
migration ID uniqueness check
shadow or dry-run validation
destructive SQL detector
rollback or roll-forward plan
serialized production migration lock
human approval
```

Prefer expand/migrate/contract:

```text
expand: additive schema change
migrate: backfill or dual-write validation
contract: remove old paths after safe window
```

## 6. IaC Rules

Agents may run validate and what-if/plan. Production apply requires human approval.
Destructive changes require plan-first review.

Required controls:

```text
plan on PR
plan artifact attached to PR
apply separate from plan
production apply protected environment
restricted runner for production apply
secrets kept out of repo
recurring drift check
```

## 7. Ownership Model

Route high-risk approvals to the appropriate human owner or team. Do not require
multi-person approvals that exceed actual team capacity.

```text
agents = authors/operators
ci = verifier
policy = classifier/enforcer
human owner/team = final approver for irreversible risk
```

For solo-maintainer repos, use the single human owner for high-risk and critical gates.
For team repos, route to the owning team defined in CODEOWNERS.
