# Roadmap planner foundation

This is **only spec step 1** of [#3400](https://github.com/IBuySpy-Shared/basecoat/issues/3400).
It does not implement the `roadmap:` intent, milestone persistence, execution,
workflow triggers, roadmap artifact PR, or release cuts. Parent #3400 remains open.
The approved [spec](../spec/synthesized/issue-3400-roadmap-synthesizer-auto-group-issuesprs-into-release-milest.spec.md)
and [PRD](../prd/synthesized/issue-3400-roadmap-synthesizer-auto-group-issuesprs-into-release-milest.prd.md)
remain authoritative.

## Read-only interface

```powershell
python scripts\roadmap\plan.py --proposal proposal.json --snapshot snapshot.json
python scripts\roadmap\plan.py --proposal proposal.json --repo owner/repo
python tests\roadmap-plan-tests.py
```

There is no apply flag, workflow, dispatch, tag, release, or live mutation adapter.
Live mode uses paginated authenticated `gh api --method GET` calls only. An API
failure stops planning with endpoint and exit-code evidence; it is never treated
as an empty successful response. Credentials and untrusted API bodies are not
printed. Live PRs remain residual: linkage requires normalized mapper evidence,
which this foundation does not infer from untrusted body text.

## Input contract

Proposal JSON contains `repository`, `scope`, `current_version`, and `groups`.
Each group supplies mapper-normalized `issues` (positive numeric issue IDs),
`significant` (boolean mapper decision), and advisor-recommended `release`
(`vX.Y.Z` for significant groups). This module validates evidence; it does not
replace mapper clustering, significance/debate, or advisor classification.
Sub-threshold and unlinked/ambiguous PR work remains visible as residuals.

Snapshot JSON contains `repository`, `complete: true`, `errors: []`, `tags`,
`milestones`, and `items`. Milestones have `number`, `state`, and `description`.
Items have `number`, `kind: issue|pr`, `state`, `labels` (names), `milestone`
(number or null), and optional `linked_issues` (numeric IDs). Captured snapshots
must be complete; the CLI obtains the paginated live inventory automatically.
Labels must be a list of strings and each item must supply a milestone value
that is null or a positive integer referencing the milestone inventory.
Malformed assignment/pin evidence fails closed, including storage-step previews.
Tag evidence must be a list of nonempty strings without whitespace. Existing
stable SemVer tags (with or without `v`) establish the minimum current-version
baseline; a lower proposal baseline is rejected before evaluating releases.
Non-version tag names are preserved but do not establish a baseline.
Version-shaped malformed, prerelease or build-metadata tags fail closed because
this foundation does not yet support their release ordering semantics.

Supported scopes are `all`, `label:<name>` and `issue-set:#N,#M`. Theme
classification, custom pace/stop semantics and prerelease versions are explicitly
rejected until runtime integration. Bounds default to one release and configured
concurrency; foundation limits releases to configured maximum cycles and
concurrency to configured default concurrency. No overrides bypass these limits.

Output includes canonical plan, SHA-256 digest, `dry_run: true`, and proposed
storage steps. The digest binds repository, scope, bounds, ordered release keys,
assignments, ownership/pin observations and residuals, excluding display text.
Identity is the exact managed marker, never the milestone title. Ambiguous
markers, duplicate open managed keys, unknown ownership, and pins fail closed.

## Storage and approval boundary

The test-only mock adapter models atomic compare-and-set, one-time approval
consumption and idempotent create/assignment replay after lost responses. It is
not evidence that GitHub REST provides those guarantees. No live writes may be
enabled until stale concurrent updates can be rejected or equivalent protection
is proven. The pure approval checker accepts **already authenticated** permission
evidence; it neither authenticates an actor nor stores/consumes authorization.
It binds an exact repository/run/digest; scheduled/merge triggers cannot approve.

There is one roadmap plan approval, not a new XS-XL human PR review. Ordering
helpers only preview scope: `off` does not inspect roadmap state, `prefer`
falls back solely on absence, and invalid/pinned/stale state stops. Real
dependency order remains exclusively `build-waves.ps1`; no execution is enabled.

## Remaining linked delivery

- [#3616](https://github.com/IBuySpy-Shared/basecoat/issues/3616): mapper/advisor
  integration, race-safe persistence, authenticated approval, checkpoints,
  canonical roadmap artifact PR. The additive
  [grouping/checkpoint preview](roadmap-grouping-preview.md) validates supplied
  normalized mapper/advisor evidence and stores a local read-only artifact.
  Live CAS, authenticated approval consumption and remote writes remain blocked;
  this does not complete #3616.
- [#3617](https://github.com/IBuySpy-Shared/basecoat/issues/3617): intent/routing,
  triggers, bounded resume and autopilot roadmap-order integration, dependency
  failure/fallback coverage using existing topology helpers.
- [#3618](https://github.com/IBuySpy-Shared/basecoat/issues/3618): exact scoped
  release-set/version validation, existing gates, verified shipped state,
  serialized advance and full end-to-end shadow validation.
