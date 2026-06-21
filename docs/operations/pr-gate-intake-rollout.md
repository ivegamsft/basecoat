# PR Gate Intake Rollout Runbook

> **Related issue:** #1815

## Objective

Make intake-time metadata explicit so authors know when PRD/spec links are expected before a PR is opened, then validate the effect in a downstream pilot.

## Preconditions

- BaseCoat template and guidance changes are merged.
- The consumer repo has synced the BaseCoat release that contains the new templates.
- `gh auth status` is green for the account used to inspect runs.
- No consumer-repo writes are attempted without coordinator approval.

## Rollout Checklist

| Step | Command / Action | Evidence |
|---|---|---|
| Validate repo changes | `pwsh scripts/validate-basecoat.ps1` | Validation passes |
| Run repo tests | `pwsh tests/run-tests.ps1` | Test suite passes |
| Build docs | `python -m mkdocs build --strict` | MkDocs completes cleanly |
| Confirm PR template parity | Check `.github/PULL_REQUEST_TEMPLATE.md` and `docs/templates/pr-template.md` | Sections match |
| Confirm issue template parity | Check `.github/ISSUE_TEMPLATE/*.md` and `docs/templates/issue-template.md` | Intake fields match |
| Publish the release | Follow the normal BaseCoat release flow | New tag or synced release is available |
| Sync the consumer repo | Use the supported BaseCoat sync path | Consumer repo reports the new release version |

## Pilot Protocol

### 1. Create the triage issue

Use the updated issue template and fill in:

- sprint target
- priority
- estimated change size
- risky-path signal
- RCA / Design / Debate
- PRD / Spec intake

### 2. Classify by threshold

Use the PRD/spec gate rules in `.github/workflows/prd-spec-gate.yml`:

- Below threshold and not risky: PR can proceed without PRD/spec links.
- At or above threshold: PR must include both PRD and spec references, or a clear `N/A` rationale.
- Risky path touched: PR should include at least one PRD or spec reference.

### 3. Open three validation PRs

| Case | Expected result |
|---|---|
| Below threshold, no PRD/spec links | Pass |
| Above threshold or risky path, no PRD/spec links | Fail |
| Corrected PR with required links | Pass |

### 4. Observe gate behavior

Check the consumer repo Actions run for `prd-spec-gate.yml` and confirm the outcome matches the expected result for each case.

### 5. Record the result

Capture whether any failure was actually avoidable, or whether it came from an unrelated repo problem.

## Metrics Plan

| Metric | Baseline | Post-rollout |
|---|---|---|
| Avoidable gate failures | Recent failed `prd-spec-gate` runs with missing links | Same count after intake changes |
| Lead time impact | Time from issue creation to PR open | Same metric after rollout |
| Bypass label usage | Count of `skip-prd-spec-check` labels | Same count after rollout |
| Explicit rationale usage | Count of PRs with `N/A` and reason | Same count after rollout |

## Go / No-Go Criteria

- Go: issue, PR, and docs templates all expose the same intake contract, and the consumer repo reproduces the expected pass/fail gate behavior.
- No-go: the sync path is unclear, template parity is incomplete, or the threshold cases cannot be reproduced.

## Rollback

1. Revert the BaseCoat template and guidance changes.
2. Publish a new BaseCoat release.
3. Re-sync the consumer repo to the prior known-good version.
4. Pause the pilot until the gate behavior is stable again.
