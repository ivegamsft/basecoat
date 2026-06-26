# Intake Pilot Results: IBuySpy-Dev/wawkr

> **Related issue:** #1812
> **Pilot date:** 2026-06-25
> **Validation script:** `scripts/validate-intake-contract.ps1`
> **BaseCoat version:** See `.github/base-coat/version.json` in wawkr

## Executive Summary

`IBuySpy-Dev/wawkr` partially satisfies the BaseCoat intake contract. The PR
template surface is present; the issue template surface is absent. Two optional
BaseCoat-managed workflows have not been installed. The gap is contained and
addressable with one PR in the consumer repo.

## Validation Results

Command run:

```bash
pwsh scripts/validate-intake-contract.ps1 -Repo IBuySpy-Dev/wawkr -CheckWorkflows
```

| Surface | Status | Detail |
|---|---|---|
| PR template (`.github/PULL_REQUEST_TEMPLATE.md`) | **PASS** ✓ | File is present |
| Issue template(s) (`.github/ISSUE_TEMPLATE/`) | **FAIL** ✗ | Directory and legacy file both absent |
| Workflow: `prd-spec-gate` | WARN (optional) | Not installed |
| Workflow: `intake-contract-check` | WARN (optional) | Not installed |

**Overall result: FAIL** — 1 required surface missing.

## Before/After Gate Failure Baseline

No `prd-spec-gate` workflow is installed in wawkr, so the gate cannot currently
fire. The baseline avoidable failure count is therefore **not measurable** — the
gate does not exist to produce failures. The root cause is:

1. wawkr's `configure-downstream-workflows.ps1` has not been run with
   `-InstallClass reusable` since `intake-contract-check.yml` was added to the
   workflow map.
2. wawkr has no issue template forms, so the intake-first fields that the gate
   relies on are not surfaced to issue authors.

## Gap Analysis

| Gap | Remediation |
|---|---|
| Missing issue templates | Add at least one `.github/ISSUE_TEMPLATE/*.yml` form exposing sprint target, priority, estimated change size, risky-path signal, and RCA/Design/Debate/PRD-Spec intake fields |
| `prd-spec-gate` not installed | Run `pwsh scripts/configure-downstream-workflows.ps1` in wawkr (workflow is in the `reusable` class and will be installed by default) |
| `intake-contract-check` not installed | Included in the same `configure-downstream-workflows.ps1` run above |

## Go / No-Go Assessment

| Criterion | Status | Notes |
|---|---|---|
| PR template present | **Go** | `.github/PULL_REQUEST_TEMPLATE.md` confirmed |
| Issue template present | **No-go** | Missing entirely |
| Sync path confirmed | **Go** | `configure-downstream-workflows.ps1` covers both required workflows |
| Template parity (PR ↔ docs) | **Pending** | Requires local review in wawkr |
| Gate behavior reproduced | **No-go** | Gate not installed; cannot reproduce pass/fail cases |

**Pilot verdict: No-go for gate measurement. Go for gap remediation.**

## Recommended Remediation Steps (in wawkr)

1. Create `.github/ISSUE_TEMPLATE/` with at least one issue form exposing the
   required intake fields. Use the BaseCoat issue template reference in
   `docs/templates/` as a starting point.

2. Run the downstream workflow installer:

   ```bash
   pwsh scripts/configure-downstream-workflows.ps1
   ```

   This installs `basecoat-intake-contract-check.yml` and is ready to add
   `basecoat-prd-spec-gate.yml` once that workflow is promoted to the `reusable`
   class in `configure-downstream-workflows.ps1`.

3. Re-run the validation script to confirm all checks pass:

   ```bash
   pwsh scripts/validate-intake-contract.ps1 -Repo IBuySpy-Dev/wawkr -CheckWorkflows
   ```

4. Open three validation PRs per the [pilot protocol](pr-gate-intake-rollout.md#3-open-three-validation-prs)
   once the gate is installed.

## Broader Rollout Readiness

| Consumer repo | PR template | Issue templates | prd-spec-gate installed |
|---|---|---|---|
| `IBuySpy-Dev/wawkr` | ✓ | ✗ | ✗ |

To validate additional repos, run:

```bash
pwsh scripts/validate-intake-contract.ps1 -Repo <owner>/<repo> -CheckWorkflows
```

## Open Items Before Broader Rollout

- [ ] `prd-spec-gate.yml` promoted to `reusable` class in `configure-downstream-workflows.ps1`
  so consumer repos can install it via the standard workflow installer
- [ ] wawkr issue template gap closed (tracked in `IBuySpy-Dev/wawkr`)
- [ ] Gate behavior validated end-to-end with three pilot PRs
- [ ] Metrics baseline captured (avoidable failures before gate, then post-gate trend)
