# Environment Protection and Production Approvals Implementation

> **Issue:** [#1547](https://github.com/IBuySpy-Shared/basecoat/issues/1547)  
> **Sprint:** Sprint 36  
> **Component:** Production governance and deployment safety

---

## Overview

This document describes the implementation of environment protection and production approval requirements. The goal is to enforce safe deployment practices by requiring:

1. **Environment protection** on the production environment (`prod`) with deployment approvals
2. **Deployment branch restrictions** to ensure only reviewed, tested code reaches production
3. **Continuous verification** that environment protection rules are maintained

**Note:** Branch protection for the `main` branch is covered separately in #1556 (`docs/reference/branch-protection.md`). This document focuses on deployment environment controls.

---

## Implementation Scope

### Environment Protection (prod)

Configuration file: `.github/environment-protection-production.json`

**Enforced rules:**

- ✅ Deployments to `prod` environment restricted to `main` branch
- ✅ Requires 1 approval for deployment
- ✅ Prevents self-review (author cannot approve own deployment)
- ✅ Wait timer: 0 (immediate after approval)

**Application method:**

Via GitHub UI (primary):

1. Navigate to: Settings → Environments → prod
2. Enable "Deployment branches and environments"
3. Select "Protected branches only"
4. Add protection rules:
   - Check "Require reviewers"
   - Set "Required number of reviewers: 1"
   - Check "Prevent self review"

Or via API:

```bash
# Configure deployment branch policy
gh api \
  --method PUT \
  /repos/IBuySpy-Shared/basecoat/environments/prod \
  -f deployment_branch_policy='{"protected_branches":true,"custom_branch_policies":false}'

# Add protection rule (requires admin access)
# Currently no direct API for setting approval requirement; use UI
```

**Status:** Template documented in `.github/environment-protection-production.json` for reference and audit trail.

### Staging Environment (optional)

Configuration: Same as production (for consistency)

For teams that need a pre-production testing environment:

1. Navigate to: Settings → Environments → staging
2. Apply same protection rules as production
3. Restrict deployments to `release/*` or `main` branch (team preference)

---

## Integration with Branch Protection

This implementation assumes the `main` branch has baseline protections (required approvals, status checks, signed commits). See **[Branch Protection](docs/reference/branch-protection.md)** (Issue #1556) for branch-level controls.

**Deployment safety depends on both layers:**

- **Layer 1 (Branch):** Code reaches main only after review and CI checks pass → handled by #1556
- **Layer 2 (Environment):** Deployments to prod from main require additional approval → handled here by #1547

---

## Verification Workflow

The `.github/workflows/enforce-protection.yml` workflow:

- Runs on a schedule (daily at 2 AM UTC)
- Runs on manual dispatch
- Runs when environment protection configs are changed
- Bootstraps `prod` when missing via GitHub environment API
- Retries environment list checks with deterministic backoff to handle API propagation delay
- Emits direct API/list API/template diagnostics when `prod` is still not observable
- Verifies:
  - Production environment exists and is configured
  - Staging environment (if present) is documented
  - Enforcement rules are in place per documentation

---

## Related Documentation

- [Branch Protection Ruleset](docs/reference/branch-protection.md) — Main branch controls (Issue #1556)
- [Secret Scanning](docs/operations/security/secret-scanning.md) — Complementary security control
- [Security Remediation Traceability Workflow](docs/operations/security/remediation-traceability-workflow.md) — Canonical closure-evidence workflow for security findings
- [Deployment Checklist](docs/guides/deployment-checklist.md) — How to execute safe deployments

---

## Rollout Checklist

- [x] Create environment protection template (`.github/environment-protection-production.json`)
- [x] Create verification workflow (`.github/workflows/enforce-protection.yml`)
- [x] Document implementation (this file)
- [ ] Configure prod environment protection via UI (requires Settings access)
- [ ] Configure staging environment (optional, requires Settings access)
- [ ] Verify protection is in place (check workflow run)
- [ ] Communicate change to team (if applicable)

---

## Troubleshooting

### Environment protection not enforced

**Symptom:** Deployments to prod succeed without approval

**Causes:**

- Environment protection not configured (Settings → Environments → prod)
- User is org admin (admins may bypass environment protection)
- Deployment job missing `environment: prod` in workflow

**Resolution:**

1. Verify environment config via UI or API: `gh api /repos/IBuySpy-Shared/basecoat/environments/prod`
2. Check workflow has `environment: prod` in the deployment job
3. Review environment protection rules for bypass actors
4. Confirm user role doesn't have admin bypass permissions

### Cannot add protection rules to environment

**Symptom:** UI shows protection rules grayed out or API returns 422

**Causes:**

- Organization-level environment policies conflict
- User lacks permission to manage environments
- Environment is managed at org level

**Resolution:**

1. Check org Settings → Environments for inherited policies
2. Verify user has "Manage environments" permission
3. Contact org admin if policies restrict environment-level overrides

---

## Maintenance

- Review environment protection settings quarterly
- Audit deployment approval logs monthly
- Update documentation if policy changes
- Monitor enforcement workflow for failures

---

**Owner:** security_analyst agent  
**Related Issue:** #1556 (Branch Protection Baseline)  
**Last Updated:** 2026-06-14  
**Status:** Implemented
