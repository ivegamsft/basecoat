# CI/CD Guardrails Learning Log

**Control Plane Issue**: [#1890](https://github.com/IBuySpy-Shared/basecoat/issues/1890)  
**Sprint Closeout Issue**: [#1893](https://github.com/IBuySpy-Shared/basecoat/issues/1893)

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

## July 2026 Runner Routing Audit

1. Prefer `vars.RUNNER_DEPLOY` and `vars.RUNNER_RELEASE` over hard-coded runner groups when a workflow needs a migration-safe fallback.
2. Use the soft-fallback expression (`vars.RUNNER_DEPLOY || 'ubuntu-latest'`) instead of a resolver or preflight job. The `resolve-deploy-runner` resolver pattern has been removed; workflows should not fail when `RUNNER_DEPLOY` is unset.
3. For deploy workflows requiring Linux capabilities on PR events, add a PR guard: `github.event_name == 'pull_request' && 'ubuntu-latest' || vars.RUNNER_DEPLOY || 'ubuntu-latest'`.
4. CI-only workflows that require Docker (e.g., image build/smoke tests) should pin to `ubuntu-latest` unconditionally; do not route them through `vars.RUNNER_DEPLOY`.
5. Keep PR validation and other fast gates on GitHub-hosted runners unless a private network or managed identity is required.
6. Runner contract changes in deploy/release workflows must sync `.github/workflow-runner-routing-contracts.json`; contract violations are enforced by `workflow-runner-capability-audit.yml` (which runs `scripts/audit-workflow-runner-capabilities.ps1 -FailOnContractViolation`) and by Test 19 in `tests/workflow-guardrails-tests.ps1` (the `runner-capability-classification` test, part of the `validate-windows` CI job).
