# Branch Protection Policy (Issue #1747)

**Effective Date**: Sprint 38, June 24, 2026  
**Policy Owner**: Platform Security  
**Last Updated**: June 24, 2026

---

## Overview

This policy establishes mandatory branch protection rules for the `ivegamsft/basecoat` repository to prevent unauthorized or untested code from reaching the main branch.

## Scope

**Applies to**:

- `main` branch (production)
- All feature, fix, chore, automation, and CI branches matching patterns:
  - `feat/*`
  - `fix/*`
  - `chore/*`
  - `ci/*`
  - `copilot/*`
  - `automation/*`

**Excludes**:

- Temporary branches with lifetime < 7 days (must be cleaned up)
- Experimental branches prefixed with `exp-*` (best effort, cleanup required weekly)

## Required Branch Protections

### 1. Require Pull Request Reviews

- **Minimum reviewers**: 1
- **Dismiss stale pull request approvals when new commits are pushed**: Enabled
- **Require code review from code owners**: Enabled
- **CODEOWNERS file location**: `.github/CODEOWNERS`

### 2. Require Signed Commits

- **Status**: Enabled via GitHub Ruleset `require-signed-commits`
- **Expected verification**: All commits must have GPG or S/MIME signature

### 3. Require CI Status Checks to Pass

- **Required checks**:
  - `BaseCoat - CI` (must pass)
  - `BaseCoat - Secret Scanning` (advisory, does not block)
  - `BaseCoat - PR Flow Hygiene` (must pass)

- **Require branches to be up to date before merge**: Enabled
- **Require status checks to pass before merging**: Enabled

### 4. Restrict Who Can Push to Matching Branches

- **Allowed roles**: Repository maintainers and above
- **Bypass allowed for**: Pre-approved automation (GitHub Apps with approved credential)

### 5. Require Conversation Resolution Before Merge

- **Enabled**: Yes
- **All comments must be resolved before merge proceeds**

## Enforcement Mechanism

### Current Status

- ACTIVE: Ruleset `default-branch-protection` (active)
- ACTIVE: Ruleset `require-signed-commits` (active)
- GAP: 10+ branches currently unprotected (tracked in GitHub Issue #1747)

### Remediation Tasks

| Task | Priority | Status | Owner | Due |
| --- | --- | --- | --- | --- |
| Apply default protection to all feat/* branches | P0 | Pending | Platform Security | Sprint 38 |
| Apply default protection to all fix/* branches | P0 | Pending | Platform Security | Sprint 38 |
| Apply default protection to all chore/* branches | P0 | Pending | Platform Security | Sprint 38 |
| Apply default protection to all ci/* branches | P0 | Pending | Platform Security | Sprint 38 |
| Apply default protection to all copilot/* branches | P0 | Pending | Platform Security | Sprint 38 |
| Apply default protection to all automation/* branches | P0 | Pending | Platform Security | Sprint 38 |
| Update PR flow hygiene to detect unprotected branches | P1 | Pending | Workflow Security | Sprint 38 |

### Remediation Workflow

To audit branch protection posture and detect unprotected branches:

```bash
# Trigger the branch protection drift gate/audit workflow
gh workflow run branch-protection-enforce.yml --repo ivegamsft/basecoat

# Verify active rulesets
gh api repos/ivegamsft/basecoat/rulesets --jq '.[] | {name, enforcement}'
```

## Exceptions and Waivers

**Temporary branch exceptions** require:

1. CODEOWNER approval via GitHub issue comment (tracked in #1747 or subsequent issue)
2. Automatic cleanup deadline (max 30 days)
3. Escalation path to Security Steering Committee

**No production exceptions** are allowed for signed commit or PR review requirements.

## Monitoring and Audit

- **Audit frequency**: Weekly via `branch-protection-enforce.yml` workflow
- **Alert destination**: Portfolio operations queue
- **Escalation on**: Detection of unprotected branches with >5 commits/24 hours

## Related Policies

- [Secret Scanning Runbook](../operations/security/secret-scanning.md)
- [Branch Protection Runbook](../operations/security/branch-protection.md)
- Workflow Permission Matrix — to be created in Sprint 39
- Dependency Alert SLA — to be created in Sprint 40

---

**Policy Version**: 1.0  
**Approved By**: Security Audit (Issue #1747)  
**Distribution**: Platform Security, Workflow Security Team
