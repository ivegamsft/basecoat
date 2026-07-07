# CI/CD Guardrails Learning Log

**Control Plane Issue**: [#1890](https://github.com/ivegamsft/basecoat/issues/1890)  
**Sprint Closeout Issue**: [#1893](https://github.com/ivegamsft/basecoat/issues/1893)

## Run Summary

- Sprints completed in sequence: 1, 2, and 3.
- Stabilization issues addressed: #1687, #1688, #1712, #1764.
- Sprint closeout PRs created for #1891, #1892, and #1893.

## What Worked Well

1. Serialized merge pacing reduced cross-PR conflicts in a busy main branch.
2. Explicit API-based checks in workflow scripts improved confidence versus doc-only validation.
3. Keeping enforcement changes advisory-first avoided accidental hard-fail regressions.

## What Required Rework

1. A workflow permission scope (`administration`) was invalid and had to be removed after syntax validation surfaced it.
2. Frequent main-branch movement required repeated rebase cycles to satisfy strict up-to-date branch protection.

## Operational Learnings

1. For GitHub workflow token scopes, rely on documented permission keys only; actionlint catches unknown scopes early.
2. In strict branch protection repositories, enable auto-merge and keep branches rebased to avoid manual merge timing races.
3. When graceful enforcement paths are intentional, write findings to step summary so governance signals stay visible.

## Follow-Up Recommendations

1. Keep branch protection required-check documentation synchronized with actual configured contexts.
2. Retain the branch protection API audit step in scheduled runs as a drift detector.
3. Continue using explicit sprint closeout artifacts to capture operational lessons and reduce repeated triage.
