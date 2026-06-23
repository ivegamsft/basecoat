# CI/CD Remaining Gaps Triage and Scope

## Summary

This sprint scoped the reported CI/CD gaps and checked the current repo state before making changes.

## Issue Triage

| Issue | Status | Current observation | Planned fix |
|---|---|---|---|
| #1681 validate-windows regression | Fixed in this branch | `tests/adoption-scanner-tests.ps1` now uses a temp file with file-based parameter binding, which is stable on Windows. | Keep the hardened test path. |
| #1684 unpinned workflow actions | Already aligned | Workflow action refs currently use full SHAs; only a commented example still mentions `@main`. | No code change needed. |
| #1690 missing agent eval companions | Already aligned | All `agents/*.agent.md` files have matching `.agent.eval.yaml` companions. | No code change needed. |
| #1695 asset health null `$Matches` indexing | Fixed in this branch | `.github/workflows/asset-health.yml` now guards against a missing match before indexing `$Matches[1]`. | Keep the null-safe guard. |
| #1696 dependency graph string terminator | Needs CI evidence | `scripts/graph-dependencies.ps1` runs successfully in this checkout. | Defer until CI reproduces the parser error again. |
| #1710 security analyst lock-file sync | Needs CI evidence | The reported lock-file mismatch was not reproduced during initial local inspection. | Defer until CI reproduces the lock-file mismatch. |
| #1711 environment-audit-drift package lookup | Already aligned | `.github/workflows/audit-environment-drift.yml` uses the local `skills/environment-audit-drift` package path. | No code change needed. |

## Scope

- Keep the #1681 and #1695 hardening fixes in this branch.
- Document the already-resolved or unreproducible items here instead of forcing unrelated edits.
