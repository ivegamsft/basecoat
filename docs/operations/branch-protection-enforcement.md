# Branch Protection Enforcement Procedures

This document outlines the operational procedures for enforcing and validating main branch protection rules.

## Overview

Branch protection enforcement is handled through three mechanisms:

1. **Manual Configuration**: Applied via GitHub Settings UI and documented in `docs/reference/branch-protection.md`
2. **Automated Validation**: Checked by `governance-audit.yml` workflow (weekly + manual trigger)
3. **Enforcement Workflow**: `branch-protection-enforce.yml` can re-apply rules if they drift

## Workflow: Automated Audit (`governance-audit.yml`)

**Trigger**: Weekly (Monday 3:23 AM UTC) or manual via `workflow_dispatch`

**What it does**:
- Queries repository API for main branch protection settings
- Validates that all baseline controls are enabled
- Generates audit evidence and comparison to expected state
- Fails if protection payload is null or incomplete

**Evidence output**: GitHub Actions logs showing `gh api` responses

**Remediation**: If audit fails, manually re-apply rules via Settings UI or trigger `branch-protection-enforce.yml`

## Workflow: Enforcement (`branch-protection-enforce.yml`)

**Trigger**: Manual via `workflow_dispatch` (one-time or as-needed)

**Permissions required**:
- Repository admin access via `GITHUB_TOKEN` or `BRANCH_PROTECT_TOKEN` (PAT)
- Write access to repository settings

**What it does**:
1. Checks out repository
2. Uses `gh api` POST to apply branch protection rules
3. Validates rules were applied successfully
4. Outputs audit evidence

**Configuration**: Rules are defined inline in the workflow; keep synchronized with `docs/reference/branch-protection.md`

## Operational Checklist

### Initial Setup

- [ ] Review and approve `docs/reference/branch-protection.md` policy
- [ ] Apply rules via GitHub Settings UI or trigger `branch-protection-enforce.yml`
- [ ] Run `governance-audit.yml` to verify rules are active
- [ ] Document baseline in this file and commit to main

### Ongoing Validation

- [ ] Weekly audit runs automatically (Monday 3:23 AM UTC)
- [ ] Monitor GitHub Actions logs for audit failures
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
| `governance-audit` workflow fails | Check Actions logs; review protection API response | Re-apply rules if drift detected |
| PR merged without required reviews | Check audit trail; contact admins if intentional | Verify protection is enforced |
| `main` branch history shows force-push | Audit admin access logs | Investigate if unauthorized |

## Documentation Maintenance

Keep these files in sync:

1. **`docs/reference/branch-protection.md`** — Policy and controls definition
2. **`docs/operations/branch-protection-enforcement.md`** — This file; operational procedures
3. **`.github/workflows/governance-audit.yml`** — Validation logic
4. **`.github/workflows/branch-protection-enforce.yml`** — Enforcement logic (if created)

When policy changes:
1. Update `branch-protection.md` first
2. Update enforcement workflow(s) to match
3. Create PR with both docs and workflows
4. Link to issue #1556
5. Verify audit passes before merging
