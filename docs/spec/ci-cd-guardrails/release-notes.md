# CI/CD Guardrails Sprint Release Notes

**Version**: v0.1.0  
**Sprint**: Sprint 3 - Closeout  
**Control Plane Issue**: [#1890](https://github.com/IBuySpy-Shared/basecoat/issues/1890)  
**Sprint Issue**: [#1893](https://github.com/IBuySpy-Shared/basecoat/issues/1893)

## What Was Shipped

### Sprint 1 - Triage Scope ([PR #1959](https://github.com/IBuySpy-Shared/basecoat/pull/1959))

- Added scope and investigation record: `docs/spec/ci-cd-guardrails/triage-scope.md`.
- Confirmed root causes and planned sequence for #1687, #1688, #1712, and #1764.

### Sprint 2 - Implementation

- [PR #1965](https://github.com/IBuySpy-Shared/basecoat/pull/1965) (closes #1712): corrected jq environment detection handling.
- [PR #1967](https://github.com/IBuySpy-Shared/basecoat/pull/1967) (closes #1687): added missing `environments: read` permission.
- [PR #1968](https://github.com/IBuySpy-Shared/basecoat/pull/1968) (closes #1688): improved no-reviewer handling visibility through step summary output.
- [PR #1970](https://github.com/IBuySpy-Shared/basecoat/pull/1970): Sprint 2 closeout.

### Sprint 3 - Branch Protection Stabilization

- [PR #1973](https://github.com/IBuySpy-Shared/basecoat/pull/1973) (closes #1764):
  - removed invalid workflow permission scope usage,
  - aligned branch protection check names with active CI contexts,
  - added branch protection API audit coverage.
- [PR #1976](https://github.com/IBuySpy-Shared/basecoat/pull/1976): Sprint 3 closeout and control-plane wrap-up artifacts.

## Validation Summary

- Required checks for merged Sprint 1/2 PRs completed successfully.
- Sprint 3 closeout remains gated on final PR merge sequence and required checks on the open closeout PR.

## Rollback Strategy

All delivered changes are workflow and documentation updates. Rollback can be done by reverting the related PR commits without data migration.
