# CI Remediation Traceability Record

**Date:** 2026-06-21  
**Issue linkage:** [#1659](https://github.com/ivegamsft/basecoat/issues/1659), [#1554](https://github.com/ivegamsft/basecoat/issues/1554)

## Purpose

Restore auditable linkage between the CI instability finding in #1554, the
implemented remediation PRs, and measurable reliability outcomes.

## Implementation Linkage Ledger

| Skill-aligned track | Remediation PRs | Scope | Status |
|---|---|---|---|
| `ci-audit` | [#1602](https://github.com/ivegamsft/basecoat/pull/1602), [#1651](https://github.com/ivegamsft/basecoat/pull/1651) | Added retry/timeouts for transient network operations and enforced required CI status coverage. | Landed |
| `ci-flake-quarantine` | [#1602](https://github.com/ivegamsft/basecoat/pull/1602) | Added containment retry/backoff behavior to reduce transient flakes without suppressing failing signals. | Landed |
| `build-master-control-plane` | [#1642](https://github.com/ivegamsft/basecoat/pull/1642), [#1649](https://github.com/ivegamsft/basecoat/pull/1649), [#1677](https://github.com/ivegamsft/basecoat/pull/1677) | Standardized workflow-file evaluation path for publish pipeline and moved parse-fragile inline logic into script-based control. | Partially landed (recurrence still present) |

## Failure-Class Register (Owner + Remediation State)

Owner assignment follows `.github/CODEOWNERS` for `.github/workflows/**`.
Primary owner is `@ibuyspy`; secondary owner is `@ivegamsft`.

| Failure class | Primary workflows | Broken vs flaky | Owner | Remediation status |
|---|---|---|---|---|
| Workflow file-load/parser rejection | `.github/workflows/publish-to-production.yml` | **Broken** (latest run still fails before job start) | `@ibuyspy` (`@ivegamsft` backup) | In progress |
| Transient network dependency failures (download/install/fetch) | `BaseCoat - PR Validation`, `BaseCoat - Validate BaseCoat` | **Flaky-containment class** (mitigated with retries/timeouts) | `@ibuyspy` | Mitigated, monitor |
| Required-check coverage drift | `Agent Merge` / required status wiring | **Broken-control class** (policy drift risk if status not emitted) | `@ibuyspy` | Mitigated via #1651 |
| Policy gate failures (label compliance) | `BaseCoat - PR Validation` (`Release label gate`) | **Not flaky** (deterministic governance enforcement) | `@ibuyspy` | Active enforcement |

## Current Snapshot (Last 20 Runs per Workflow, sampled 2026-06-21)

| Workflow | Success | Failure | Cancelled | Classification |
|---|---:|---:|---:|---|
| BaseCoat - CI | 18 | 0 | 2 | Healthy |
| BaseCoat - Validate BaseCoat | 16 | 0 | 4 | Healthy |
| BaseCoat - PR Validation | 5 | 14 | 1 | Degraded (mostly policy gate failures) |
| publish-to-production.yml | 0 | 20 | 0 | Broken (workflow-file issue recurrence) |
| Enforce Environment and Production Approvals | 2 | 18 | 0 | Recovering (latest run succeeded) |

## Retry vs Escalation Policy Note

This repository uses the build-master control-plane default:

1. Automated remediation retries per incident: **2**.
2. On second failed remediation attempt: **pause lane and open blocking escalation issue**.
3. Secret/auth/security-boundary and infra-access failures are **never auto-fixed**; they
   must escalate immediately with human approval.

Reference: `skills/build-master-control-plane/references/policy-matrix.md`.

## Measurable Target and Validation Window

Validation window for this remediation set is **next 14 days or next 20 runs per
workflow (whichever is later)**, measured from 2026-06-21.

Success targets:

1. `publish-to-production.yml` has **0 workflow-file load failures** in the window.
2. `BaseCoat - CI` and `BaseCoat - Validate BaseCoat` sustain **>= 90% success**.
3. `BaseCoat - PR Validation` failures are attributable to policy gates or code defects,
   not transient infrastructure faults.
4. Any repeated failure class (2+ consecutive same signature) has a linked escalation issue.

## Verification Commands

```bash
gh run list --repo IBuySpy-Shared/basecoat --workflow "BaseCoat - CI" --limit 20
gh run list --repo IBuySpy-Shared/basecoat --workflow "BaseCoat - Validate BaseCoat" --limit 20
gh run list --repo IBuySpy-Shared/basecoat --workflow "BaseCoat - PR Validation" --limit 20
gh run list --repo IBuySpy-Shared/basecoat --workflow ".github/workflows/publish-to-production.yml" --limit 20
gh run list --repo IBuySpy-Shared/basecoat --workflow "Enforce Environment and Production Approvals" --limit 20
```
