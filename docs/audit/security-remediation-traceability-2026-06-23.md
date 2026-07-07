# Security Remediation Traceability Record

**Date:** 2026-06-23  
**Issue linkage:** [#1771](https://github.com/ivegamsft/basecoat/issues/1771), [#1657](https://github.com/ivegamsft/basecoat/issues/1657)

## Purpose

Restore an auditable implementation trail for security remediation by linking
closed security items to concrete implementation evidence, owner accountability,
and closure rationale.

## Implementation-Linked Security Closure Ledger

| Security item | Category | Owner | Due date | Implementation evidence | Closure type | Verification evidence |
|---|---|---|---|---|---|---|
| [#1556](https://github.com/ivegamsft/basecoat/issues/1556) Define and enforce main branch protection baseline | Code and branch governance remediation | `@ibuyspy` | 2026-06-17 | [PR #1600](https://github.com/ivegamsft/basecoat/pull/1600), commit `de3568f04e1cda57dbffe5a781e781e548ab1643` (`Closes #1556`) | Fixed | Branch protection policy docs and enforcement workflow landed (`docs/reference/branch-protection.md`, `.github/workflows/branch-protection-enforce.yml`) |
| [#1558](https://github.com/ivegamsft/basecoat/issues/1558) Triage and remediate open security alerts backlog | Security backlog closure evidence and operating policy | `@ibuyspy` | 2026-06-15 | [PR #1610](https://github.com/ivegamsft/basecoat/pull/1610), commit `d1ee8bdd5926edee64d0966d39e75cc4e2013a36` (`Fixes #1558`) | Fixed with documented closure policy | Security remediation plan captured and linked closure requirements documented in commit and issue close event |
| [#1154](https://github.com/ivegamsft/basecoat/issues/1154) Merge pending Dependabot security PRs before production cut | Dependency-remediation execution | `@ibuyspy` | 2026-05-25 | [#1138](https://github.com/ivegamsft/basecoat/pull/1138), [#1140](https://github.com/ivegamsft/basecoat/pull/1140), [#1145](https://github.com/ivegamsft/basecoat/pull/1145), [#1146](https://github.com/ivegamsft/basecoat/pull/1146), [#1147](https://github.com/ivegamsft/basecoat/pull/1147) | Fixed | All listed Dependabot security PRs merged on 2026-05-23 and tracked as closure evidence in issue #1154 |
| Security secret-scanning false-positive control hardening | Secret-remediation workflow hardening | `@ibuyspy` | 2026-04-30 | [PR #303](https://github.com/ivegamsft/basecoat/pull/303) `fix(security): narrow gitleaks allowlist scope` | Fixed | Gitleaks allowlist scope narrowed to reduce false-positive suppression risk |

## Risk Acceptance Register

Current status: **no active formal risk acceptances recorded** in this closure
ledger. Future risk acceptances must include:

1. Exception owner
2. Expiration date
3. Compensating control
4. Approver identity

## Follow-Up Pattern (Implementation-Linked)

For every security item closed after this record:

1. Add or update one row in the closure ledger with owner, due date, and closure type.
2. Link at least one merged PR or signed risk acceptance record.
3. Attach verification evidence (workflow run, scanner output, or policy check).
4. Do not close the security issue until fields above are complete.

## Evidence Commands

```bash
gh issue view 1558 --repo IBuySpy-Shared/basecoat --json closedAt,state,url
gh api repos/IBuySpy-Shared/basecoat/issues/1558/events
gh api repos/IBuySpy-Shared/basecoat/commits/d1ee8bdd5926edee64d0966d39e75cc4e2013a36
gh pr view 1600 --repo IBuySpy-Shared/basecoat --json state,mergedAt,url
gh pr view 1138 --repo IBuySpy-Shared/basecoat --json state,mergedAt,url
gh pr view 1140 --repo IBuySpy-Shared/basecoat --json state,mergedAt,url
gh pr view 1145 --repo IBuySpy-Shared/basecoat --json state,mergedAt,url
gh pr view 1146 --repo IBuySpy-Shared/basecoat --json state,mergedAt,url
gh pr view 1147 --repo IBuySpy-Shared/basecoat --json state,mergedAt,url
```
