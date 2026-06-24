# Branch Protection Enforcement Procedures

This document outlines the operational procedures for enforcing and validating main branch protection rules.

## Overview

Branch protection enforcement is handled through three mechanisms:

1. **Manual Configuration**: Applied via GitHub Settings UI and documented in `docs/reference/branch-protection.md`
2. **PR-time Baseline Gate**: Checked by `pr-validation.yml` (`Main branch protection readiness gate`) on every PR targeting `main`
3. **Scheduled Drift Gate**: Checked by `branch-protection-enforce.yml` (weekly + manual trigger) to fail loudly on baseline regressions

## Workflow: PR Baseline Validation (`pr-validation.yml`)

**Trigger**: Every PR targeting `main` and `workflow_dispatch`

**What it does**:
- Queries repository API for main branch protection settings
- Enforces strict required status checks baseline
- Enforces at least one required approving review
- Enforces required conversation resolution
- Validates required check contexts from policy packs
- Validates merge queue posture from policy packs (`required` vs `deferred`)

**Evidence output**: GitHub Actions logs for `main-branch-protection-readiness`

**Remediation**: If validation fails, update live branch protection settings and rerun the workflow.

## Workflow: Drift Gate (`branch-protection-enforce.yml`)

**Trigger**: Weekly (Monday 3:23 AM UTC), PR edits to branch-protection policy files, or manual via `workflow_dispatch`

**Permissions required**:
- Repository admin access via `GITHUB_TOKEN` or `BRANCH_PROTECT_TOKEN` (PAT)
- Write access to repository settings

**What it does**:
1. Checks out repository
2. Validates branch protection policy documents exist and include expected controls
3. Audits live `main` branch protection via GitHub API
4. Fails the run when any hard baseline control drifts:
   - strict status checks disabled
   - required approving review count below 1
   - required conversation resolution disabled
   - force pushes enabled
   - deletions enabled

**Configuration**: Baseline controls are documented in `docs/reference/branch-protection.md` and enforced by workflow checks.

## Operational Checklist

### Initial Setup

- [ ] Review and approve `docs/reference/branch-protection.md` policy
- [ ] Apply rules via GitHub Settings UI or trigger `branch-protection-enforce.yml`
- [ ] Run `pr-validation.yml` (`Main branch protection readiness gate`) to verify PR-time enforcement
- [ ] Run `branch-protection-enforce.yml` to verify scheduled drift detection
- [ ] Document baseline in this file and commit to main

### Ongoing Validation

- [ ] Weekly drift gate runs automatically (Monday 3:23 AM UTC)
- [ ] Monitor GitHub Actions logs for drift failures
- [ ] If audit fails, check drift causes:
  - User accidentally disabled protection? → Re-apply via Settings
  - Workflow changes broke a required status check? → Update workflows to restore checks
  - API rate limit hit? → Retry audit

### Exception Handling

**Temporary Bypass (Emergency)**:
- If admins need to bypass protection for emergency merge:
  1. Document reason in issue or PR comment
  2. Admin pushes directly to main (logged in audit trail)
  3. Re-enable protection immediately after
  4. Post-incident review to prevent recurrence

**Status Check Removal**:
- If a required status check is no longer used:
  1. Update `docs/reference/branch-protection.md` baseline
  2. Re-apply via Settings UI or `branch-protection-enforce.yml`
  3. Verify audit passes

## Monitoring and Alerting

Monitor these signals:

| Signal | What to Check | Action |
|--------|--------------|--------|
| `branch-protection-enforce` workflow fails | Check Actions logs; review protection API response | Re-apply or correct branch protection settings |
| PR merged without required reviews | Check audit trail; contact admins if intentional | Verify protection is enforced |
| `main` branch history shows force-push | Audit admin access logs | Investigate if unauthorized |

## Documentation Maintenance

Keep these files in sync:

1. **`docs/reference/branch-protection.md`** — Policy and controls definition
2. **`docs/operations/branch-protection-enforcement.md`** — This file; operational procedures
3. **`.github/workflows/pr-validation.yml`** — PR-time baseline enforcement
4. **`.github/workflows/branch-protection-enforce.yml`** — Scheduled drift detection

When policy changes:
1. Update `branch-protection.md` first
2. Update enforcement workflow(s) to match
3. Create PR with both docs and workflows
4. Link to issue #1556
5. Verify audit passes before merging
