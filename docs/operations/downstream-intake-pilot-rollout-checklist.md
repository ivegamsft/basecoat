# Downstream Intake-First Gate Pilot Rollout Checklist

> **Related issue:** #1812
> Sprint: Sprint 38 (2026-08-04 to 2026-08-18)

## Purpose

Validate that the intake-first gate changes land correctly in a downstream consumer
repo (`IBuySpy-Dev/wawkr`), demonstrate measurably lower avoidable gate failures, and
produce a repeatable checklist for broader consumer repo adoption.

This checklist is the consumer-repo companion to the BaseCoat-side runbook at
`docs/operations/pr-gate-intake-rollout.md`.

## Upstream Dependency Status

All BaseCoat-side prerequisites must be confirmed closed before proceeding.

| Issue | Title | Required status |
|---|---|---|
| #1815 | Intake contract: require RCA, Design, Debate + PRD/Spec in issue and PR templates | Closed |
| #1810 | Docs harmonization: remove PRD/spec gate drift across guides and contributing docs | Closed |
| #1826 | Debate: design the downstream governance enforcement model for BaseCoat consumers | Closed |
| #1829 | Feature: enforce downstream PR and issue intake contract surfaces in BaseCoat consumer repos | Closed |

All four issues are closed as of sprint 38 planning. Proceed to the consumer repo steps.

## Consumer Repo Adoption Checklist

Run this checklist once per consumer repo. The pilot repo is `IBuySpy-Dev/wawkr`.

### Phase 1 — Baseline capture

Record these values before making any changes so gate failure reduction is measurable.

| Metric | Baseline value | Source |
|---|---|---|
| Failed gate runs (last 30 days) | | Actions runs for `prd-spec-gate.yml` or `intake-contract-check.yml` |
| Avoidable failures (missing templates) | | Filter above by `Missing required PR template` or `Missing required issue template surface` errors |
| Bypass label usage | | Count of PRs labeled `skip-prd-spec-check` |
| PRs without a PR template | | Open and recently closed PRs lacking intake sections |
| Issues without intake fields | | Open issues missing RCA / Design / Debate / PRD / Spec sections |

### Phase 2 — BaseCoat sync

Confirm the consumer repo carries the BaseCoat release that includes the new intake
surfaces and the reusable `intake-contract-check.yml` workflow.

- [ ] `cat .github/base-coat/version.json` shows a release >= the one containing #1815 changes.
- [ ] `.github/base-coat/workflows/intake-contract-check.yml` is present.
- [ ] `docs/templates/issue-template.md` includes the `Intake Contract` section.
- [ ] `docs/templates/pr-template.md` includes the `Intake Contract` section.

If any of the above are missing, run the sync first:

```bash
BASECOAT_REPO=https://github.com/IBuySpy-Shared/basecoat.git ./sync.sh
# or on Windows:
$env:BASECOAT_REPO = 'https://github.com/IBuySpy-Shared/basecoat.git'
.\sync.ps1
```

Then recheck the items above.

### Phase 3 — Install intake templates

Confirm the consumer repo has the required intake surfaces. These are mandatory for the
`intake-contract-check.yml` validation to pass.

- [ ] `.github/PULL_REQUEST_TEMPLATE.md` is present and includes the `Intake Contract` section (RCA, Design, Debate, PRD/Spec references, Planning Metadata table).
- [ ] At least one file exists under `.github/ISSUE_TEMPLATE/` (`.md`, `.yml`, or `.yaml`), or a root `.github/ISSUE_TEMPLATE.md` is present.
- [ ] The issue template surface includes the intake fields: RCA, Design, Debate, PRD/Spec references, and Planning Metadata.

If templates are missing, install from the BaseCoat template pack:

```bash
# Copy BaseCoat PR template into consumer repo
cp .github/base-coat/templates/pr-template.md .github/PULL_REQUEST_TEMPLATE.md

# Copy BaseCoat issue template
mkdir -p .github/ISSUE_TEMPLATE
cp .github/base-coat/templates/issue-template.md .github/ISSUE_TEMPLATE/issue.md
```

Open a PR in the consumer repo to commit these changes. Use the new intake template
when authoring that PR so the template validates itself.

### Phase 4 — Wire the intake-contract-check workflow

Add the intake surface validation step to the consumer repo's CI.

- [ ] A caller workflow exists at `.github/workflows/basecoat-intake-contract-check.yml` in the consumer repo.
- [ ] That workflow calls the reusable `intake-contract-check.yml` from the synced BaseCoat location.

Example caller:

```yaml
name: "Intake Contract Check"

on:
  pull_request:
  workflow_dispatch:

jobs:
  intake-check:
    uses: ./.github/base-coat/workflows/intake-contract-check.yml@main
    with:
      issue_template_path: .github/ISSUE_TEMPLATE
      pr_template_path: .github/PULL_REQUEST_TEMPLATE.md
```

Verify the workflow runs on the first PR after merging the templates above.

### Phase 5 — Pilot validation

Open three validation PRs in the consumer repo to confirm gate behavior matches
expectations. Record outcomes in the table below.

| Case | PR | Expected result | Actual result |
|---|---|---|---|
| Missing PR template (no intake surfaces) | | Fail — `Missing required PR template` | |
| PR template present, issue template absent | | Fail — `Missing required issue template surface` | |
| Both templates present and correct | | Pass — `Intake contract check passed` | |

For each case:
1. Create the PR in the consumer repo using the condition described.
2. Wait for the `Intake Contract Check` workflow to complete.
3. Record the actual result.
4. If the actual result does not match the expected result, see Troubleshooting below.

### Phase 6 — Post-rollout metrics capture

After the pilot validation PRs are merged or closed, collect the same metrics as Phase 1.

| Metric | Baseline | Post-rollout | Delta |
|---|---|---|---|
| Failed gate runs (last 30 days) | | | |
| Avoidable failures (missing templates) | | | |
| Bypass label usage | | | |
| PRs without a PR template | | | |
| Issues without intake fields | | | |

A reduction in avoidable failures (missing template errors) confirms the pilot objective.
Record the delta in the PR that closes this checklist issue.

## Go / No-Go Criteria

| Signal | Go | No-go |
|---|---|---|
| Intake surfaces present | Both PR and issue templates installed and verified | Either surface missing after sync |
| Gate behavior correct | All three validation cases match expected results | Any case produces wrong outcome |
| Avoidable failures | Measurably lower than baseline after rollout | Same or higher than baseline |
| Sync path confirmed | Consumer repo synced to correct BaseCoat release | Sync path unclear or version mismatch |

If any no-go condition is true, pause rollout, file a follow-up issue with the blocker
details, and revert to the rollback procedure below.

## Broader Consumer Repo Adoption

After the pilot succeeds on `IBuySpy-Dev/wawkr`, use this same checklist for each
additional consumer repo. Candidate repos to onboard next (from the fleet audit):

- `IBuySpy-Dev/work-tracker` — missing PR template and issue template directory
- `IBuySpy-Shared/gh-devops-runners` — missing PR template and issue template directory
- `IBuySpy-Dev/luxesite` — has PR template, missing issue template directory

For each repo, record the baseline metrics, complete phases 2–5, and capture post-rollout
metrics. A completed checklist PR for each repo is the evidence of successful adoption.

## Rollback

If gate behavior is incorrect or the sync path is broken:

1. Revert the template changes in the consumer repo.
2. Disable the `basecoat-intake-contract-check.yml` caller workflow.
3. File a follow-up issue against `IBuySpy-Shared/basecoat` with:
   - Which gate validation case failed
   - The Actions run URL for the failed case
   - The consumer repo and BaseCoat version in use
4. Resume only after the upstream issue is resolved and a new BaseCoat release is available.

## Troubleshooting

### `intake-contract-check.yml` not found

The reusable workflow was introduced in issue #1829. Sync the consumer repo to the
BaseCoat release that contains that change.

### Gate passes when it should fail

Confirm the caller workflow is pointing to the correct path for the reusable workflow.
Check that `pr_template_path` and `issue_template_path` inputs match the consumer repo
layout. If the inputs default to paths that exist in the caller, the check will pass
regardless of template content.

### Gate fails on template content

The `intake-contract-check.yml` validates *presence* of templates, not content. A
content failure at the PRD/spec gate level comes from `prd-spec-gate.yml`, not from
the intake contract check. Investigate the `prd-spec-gate.yml` run separately.

## Related Docs

- `docs/operations/pr-gate-intake-rollout.md` — BaseCoat-side rollout runbook (issue #1815)
- `docs/guides/consumer-sync.md` — how to sync BaseCoat assets into a consumer repo
- `docs/guides/downstream-workflows-setup.md` — installing and managing BaseCoat workflows in consumer repos
- `docs/guides/downstream-reviewer-routing-audit.md` — cross-repo reviewer-routing audit loop
- `.github/base-coat/workflows/intake-contract-check.yml` — reusable intake validation workflow
- `docs/examples/workflows/validate-basecoat-consumer.yml` — example consumer validation workflow
