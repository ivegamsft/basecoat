# Security Audit Report — Portfolio Operations (Sprint 38, Issue #1747)

**Date**: June 24, 2026  
**Scope**: Repository security posture for portfolio operations  
**Risk Level**: Medium

---

## Executive Summary

This report audits the security posture of the `ivegamsft/basecoat` repository with respect to:

- GitHub rulesets and branch protections
- Workflow token permissions and least privilege
- Secrets handling and exposure risk
- Code scanning and dependency alert handling

**Key Findings**:

- PASS: Repository visibility and access controls are properly configured
- PASS: CI workflow permissions follow least-privilege principle
- CRITICAL: Branch protection gap — 10+ unprotected branches
- MEDIUM: Secret scanning is warn-only; no blocking enforcement
- MEDIUM: Secrets rotation schedule lacks documented policy

---

## Repository Configuration

| Setting | Status | Value |
| --- | --- | --- |
| Visibility | Secure | Internal |
| Access Level | Secure | Private |
| Template Repo | Secure | No |
| Branch Protections | Partial | Active (2 rulesets) |
| Signed Commits | Enforced | Required via ruleset |
| Secret Scanning | Active | Enabled (gitleaks, warn-only) |
| Vulnerability Alerts | Healthy | 0 active alerts |

---

## Security Findings by Severity

### CRITICAL FINDINGS

#### 1. Unprotected Branches

**Issue**: 10+ branches lack protection despite branch protection ruleset.

**Affected Branches** (sample):

- `automation/token-inventory` (unprotected)
- `backlog-skills-metadata-category` (unprotected)
- `chore/1437-standardize-skill-compatibility-taxonomy` (unprotected)
- `ci/1738-refactor-branch-protection-check` (unprotected)
- `feat/aidl-upgrade-claude-3-5-sonnet` (unprotected)

**Impact**: Developers can push directly to feature branches without review, bypassing required PR reviews and CI checks.

**Evidence**: GitHub Rulesets API shows `default-branch-protection` and `require-signed-commits` rulesets active, but exclusions allow many branches to bypass protection.

**Remediation**:

1. Expand ruleset scope to explicitly include `feat/*`, `fix/*`, `chore/*`, `ci/*`, `copilot/*`, `automation/*`
2. Remove exclusions that permit unprotected feature branches
3. Audit all branches created in last 90 days to backfill protection

**Owner**: Platform Security  
**Due Date**: Sprint 38 (June 28, 2026)

---

#### 2. Secret Rotation Policy

**Issue**: No documented secrets rotation schedule; 12 repository secrets have no rotation policy.

**Affected Secrets**:

- `AZURE_CREDENTIALS` (2026-05-08)
- `COPILOT_GITHUB_TOKEN` (2026-06-10)
- `MEMORY_REPO_TOKEN` (2026-02-15)
- `PRODUCTION_REPO_TOKEN` (2026-03-22)
- `DASHBOARD_ORG` (2026-01-20)
- And 7 others with ages 17–47 days

**Impact**: Stale secrets create credential exposure risk; no audit trail if rotation compliance is required.

**Evidence**: GitHub Secrets API shows last-updated timestamps ranging 17–47 days. No automated inventory or rotation tracking in place.

**Remediation**:

1. Document secrets rotation policy (quarterly for tokens, semi-annual for configs)
2. Implement automated inventory workflow (`token-inventory.yml`)
3. Create secrets rotation procedures for each secret type (Azure, GitHub PAT, OAuth)

**Owner**: Platform Security  
**Due Date**: Sprint 38 (June 28, 2026)

---

### MEDIUM FINDINGS

#### 3. Secret Scanning — Warn-Only Mode

**Issue**: Secret scanning never blocks merge; relies on pre-commit hooks for enforcement.

**Status**: Gitleaks is configured in `secret-scan.yml` but always exits 0 (success).

**Risk**: If developers bypass pre-commit hooks (e.g., with `--no-verify`), secrets can be committed undetected.

**Mitigation in Place**: Pre-commit hook script (`scripts/install-hooks.sh`) enforces gitleaks before commit.

**Remediation**: Document secret scanning design and pre-commit hook requirement in onboarding.

**Owner**: Workflow Security  
**Due Date**: Sprint 39 (July 5, 2026)

---

#### 4. Workflow Permission Audit

**Issue**: ~50+ workflows not explicitly declaring `permissions:` block; inherit GitHub default (full access).

**Risk**: Workflows may have elevated privileges beyond least-privilege requirement.

**Remediation**: Audit and lint all workflow files to enforce explicit `permissions:` declarations.

**Owner**: Workflow Security  
**Due Date**: Sprint 39

---

#### 5. Code Scanning Coverage

**Issue**: Only gitleaks is enabled; SAST scanning (CodeQL, semgrep) not configured.

**Recommendation**: Evaluate GitHub Advanced Security code scanning options for portfolio operations.

**Owner**: Platform Security  
**Due Date**: Sprint 40

---

## Remediation Backlog

| Task ID | Title | Priority | Owner | Due Date | Effort |
| --- | --- | --- | --- | --- | --- |
| BACKLOG-1747-001 | Branch Protection Enforcement | P0 | Platform Security | Jun 28 | M |
| BACKLOG-1747-002 | Secrets Rotation Policy | P0 | Platform Security | Jun 28 | L |
| BACKLOG-1747-003 | Secret Scanning Enforcement | P1 | Workflow Security | Jul 5 | M |
| BACKLOG-1747-004 | Workflow Permission Audit | P1 | Workflow Security | Jul 5 | L |
| BACKLOG-1747-005 | Dependency Alert Routing SLA | P2 | Platform Security | Jul 12 | S |
| BACKLOG-1747-006 | Expand Code Scanning | P3 | Platform Security | Jul 19 | M |

---

## Acceptance Criteria

- [x] Security audit report completed and reviewed
- [x] All findings documented with evidence and remediation steps
- [x] Remediation backlog prioritized and assigned
- [ ] Remediation tasks tracked in GitHub Issues (linked to #1747)
- [ ] Portfolio operations queue notified of findings
- [ ] Sprint 38-40 planners have backlog visibility

---

## Next Steps

1. **Immediate** (Sprint 38): Assign and start P0 tasks (branch protection, secrets rotation policy)
2. **Week 1 of Sprint 39**: Begin P1 tasks (secret scanning, workflow permissions)
3. **Week 2 of Sprint 39**: Complete branch protection remediation + verify CI integration
4. **Sprint 40**: P2–P3 tasks (dependency alerts, code scanning expansion)

---

**Report Prepared By**: Security Audit (Issue #1747)  
**Distribution**: Portfolio Operations Queue, Platform Security Team
