---
issue: 3495
title: "Release and verify gated delivery and PR decomposition updates"
status: proposed
author: ibuyspy
created: 2026-10-04
labels: ["enhancement", "priority:medium", "needs-prd", "synthesize-spec"]
---

# Spec: Release and verify gated delivery and PR decomposition updates

## Context

Source #3495 requires a release and installed-consumer proof of already-merged
intent/decomposition fixes. This spec is a release execution contract, not a
claim of publication. PRD requirements R1-R5 map to the sections and tests below.

## Scope

One cohesive unit: release-readiness documentation and verification plan.
The parent release owner executes the later release and consumer evidence
collection. Include the merge of PR #3493 (`e93c66b399f6a394829363425efd1dff64fcd352`),
PR #3485 (`db2a5eec4e99b2b868834219531c806a1b242ffd`), and PR #3491
(`17def675099399fbf461e87203a783e8c0872dca`) in the candidate ancestry.

## Out of Scope

No experiment repo changes, reimplementation, approval fabrication, or queue
code. This lane does not bump metadata, tag, publish, deploy, merge, or enable
auto-merge. No release is asserted as complete and #3495 remains open for actual
release/consumer acceptance.

## Architecture and Data Contracts

Existing path: reviewed `main` candidate -> approved release metadata PR ->
version tag -> `release.yml` and `package-basecoat.yml` -> canonical release and
`publish-to-production.yml` mirror -> pinned consumer sync -> selected workflow
onboarding -> installed validation -> normal consumer upgrade PR.
No schema, service, or storage migration is introduced. Existing `version.json`,
`asset-manifest.json`, `.source-provenance.json`, ownership manifest, and
consumer `.basecoat.yml` are the verification contracts.

## Provenance and Version Selection

On 2026-10-05, `v4.5.2` resolves to
`36243362189f2bf4582aeb8d22e167dc5ff76ba5`; inspected `origin/main` was
`66945773`, 19 commits ahead, with root version `4.5.2`.
The eventual pin is **pending next SemVer release determination**. The release
owner inventories all intervening merged PRs and applies the release-process
rules (breaking consumer contract: major; compatible additions: minor; fixes:
patch), accounting for any intervening release. Do not assume a patch bump just
because the source issue describes fixes.

After selection, record an actual tag in `$ReleaseTag` and its full resolved
commit in `$ReleaseSha`; these variables below are execution inputs, not
placeholder version recommendations. Commit aligned version/manifest/changelog
metadata through normal review before tagging. No exclusions are proposed.
Before publication and again after tag creation:

```powershell
git fetch origin --tags
$ReleaseSha = (git rev-parse "$ReleaseTag^{commit}").Trim()
foreach ($RequiredMerge in @(
  'e93c66b399f6a394829363425efd1dff64fcd352',
  'db2a5eec4e99b2b868834219531c806a1b242ffd',
  '17def675099399fbf461e87203a783e8c0872dca'
)) {
  git merge-base --is-ancestor $RequiredMerge $ReleaseSha
  if ($LASTEXITCODE -ne 0) { throw "Required merge absent: $RequiredMerge" }
}
gh release view $ReleaseTag --repo IBuySpy-Shared/basecoat --json tagName,isDraft,isPrerelease,assets,publishedAt
```

Before tagging, run the same ancestry loop with the chosen candidate SHA instead.
Stop if the tag is unpublished, draft, wrong-version, missing ancestry, or an
unapproved prerelease. Root version, manifest library version, archive metadata,
and installed metadata must equal the tag without its `v` prefix.

## Interface and Governance Contracts

Release notes must explicitly state:

- `feature:` creates intake/issue/spec/draft work; approved scope, green checks,
  and `pr-lifecycle=full` alone never authorize delivery.
- `ship-it: <goal>` and `spec-2-prod: <goal>` normalize to existing canonical
  intents. Require a nonempty goal and qualified explicit delivery evidence;
  reject lookalikes, conflicting directives, and quoted/embedded/agent-authored
  commands. Read-only, log-only, and deferred intent suppresses side effects.
- Issue approval and delivery consent are independent. Validate open approved
  source issue, non-placeholder spec, exact qualified `/approve`, actor
  permission, scope, provenance markers, and required plan confirmation. Markers
  prove provenance, not consent; never synthesize approval/delivery comments.
- Independently deliverable batches exceeding 15 files **or** 300 total changed
  lines must split. A single cohesive feature is not a batch, but still obeys
  size/risk gates. A mechanical exception requires complete reproducible JSON
  evidence in intake Design and a qualified current-head human approval binding
  both head SHA and evidence digest; it is not a self-declared exception.
- XXL changes above 2000 lines still require qualified human PR review.
  Required checks, branch protections/native merge policy, serialized merges,
  production environment approval, and rollback/post-release verification remain.

Recommend a full compatible payload refresh, not a script-only cherry-pick.
Managed workflow sources and active consumer workflows are distinct; refresh the
latter only through supported selection-preserving onboarding.

## Security and Privacy Considerations

Do not execute untrusted fork code with release credentials. Approve Actions
execution only for a trusted current head after reviewing its diff; this is not
issue approval, XXL review, or production authorization. No gate waiver follows
from solo-dev mode. Keep tokens in existing secrets/auth tooling and redact
logs. Do not broaden workflow classes, Actions permissions, secrets, or local
ownership. Production publish must retain token preflight and environment gates.

## Reliability and Failure Modes

| Failure | Required response and owner |
|---|---|
| Candidate lacks a required merge or metadata differs from tag | Release owner stops; fixes through reviewed release PR, never retags silently. |
| Package/checksum/mirror publication is incomplete | Release owner withholds consumer recommendation; records failed run and repairs normal workflow. |
| Missing/invalid ownership or partial ship-it installation | Consumer verifier stops before delivery; resolves selection with maintainer, never installs defaults. |
| Sync succeeds but active workflow/runtime is stale | Verifier checks installed files and targeted onboarding; no success based only on version text. |
| Installer, validator, or behavior assertions fail | Verifier preserves isolated worktree/logs; no consumer merge or claimed acceptance. |
| Approval, XXL human review, checks, or production gate is absent | Gate remains blocked; report the specific required actor/evidence. |

## Performance and Capacity Considerations

Use a bounded disposable consumer fixture and existing targeted suites; no
production load or runtime capacity changes. Capture concise evidence instead of
duplicating entire payloads in PR comments.

## Implementation Plan

1. Parent inventories release window, selects SemVer and candidate, reviews
   notes/metadata, and verifies all required merge ancestry (R1/R2).
2. Run source validation and contract suites below on that candidate; record
   exact commands, exit codes, candidate SHA, and baseline diagnostics.
3. Obtain current release approvals and green token preflight:
   `gh workflow run token-preflight.yml --repo IBuySpy-Shared/basecoat`, then
   `gh run watch <actual-run-id> --repo IBuySpy-Shared/basecoat --exit-status`.
   Parent alone handles tag/publication after this wave; no dispatch here.
4. Verify successful release/package/production workflows, actual assets,
   checksum manifest, matching metadata and notes on source and mirror.
5. Run consumer verification below in a new disposable fixture, preserving
   classes and local files; attach actual results before recommending a pin.

## Consumer Verification

Follow rollout-basecoat's delivery lifecycle: resolve the consumer default
branch and configured `sync.script`, create an isolated upgrade worktree, and
record prior pin, owned active workflow inventory, local-file hashes, and install
classes **before** sync. Do not use an experiment repository.

For an existing compatible fixture, `$SyncScript` is the resolved configured
entrypoint, `$ReleaseTag` the actual approved published tag, and `$ReleaseSha`
its verified commit. Execute each block fail-fast, checking native exit codes:

```powershell
$Selection = pwsh .github\base-coat\scripts\invoke-basecoat-consumer-update.ps1 `
  -CaptureWorkflowSelection -StagePath .github\base-coat | ConvertFrom-Json
if ($LASTEXITCODE -ne 0 -or $Selection.state -eq 'partial') {
  throw 'Invalid selection or partial ship-it installation'
}
$env:BASECOAT_REPO = 'https://github.com/IBuySpy-Shared/basecoat.git'
$env:BASECOAT_REF = $ReleaseTag
$env:BASECOAT_EXPECTED_SHA = $ReleaseSha
pwsh $SyncScript
if ($LASTEXITCODE -ne 0) { throw 'Pinned sync failed' }
if ($Selection.workflow_targets.Count -gt 0) {
  pwsh .github\base-coat\scripts\configure-downstream-workflows.ps1 `
    -SourceDir .github\base-coat\workflows -DestinationDir .github\workflows `
    -Workflow $Selection.workflow_targets
  if ($LASTEXITCODE -ne 0) { throw 'Targeted onboarding failed' }
}
pwsh .github\base-coat\scripts\validate-basecoat.ps1 `
  -RootDir .github\base-coat -WorkflowValidationMode Consumer -ConsumerRoot .
if ($LASTEXITCODE -ne 0) { throw 'Installed consumer validation failed' }
$Installed = Get-Content .github\base-coat\version.json -Raw | ConvertFrom-Json
$Manifest = Get-Content .github\base-coat\asset-manifest.json -Raw | ConvertFrom-Json
$Provenance = Get-Content .github\base-coat\.source-provenance.json -Raw | ConvertFrom-Json
if ($Installed.version -ne $ReleaseTag.TrimStart('v') -or
    $Manifest.libraryVersion -ne $Installed.version -or
    $Provenance.commit -ne $ReleaseSha) { throw 'Installed provenance mismatch' }
```

For staged-only consumers skip installation and report the selection capture's
explicit activation command and permission/trigger effects. If the prior pin
lacks capture support, stop and follow the documented maintained bootstrap path;
do not guess ownership from file presence or copy new tooling into the old
consumer to conceal a failed upgrade.

Download the actual release assets with
`gh release download $ReleaseTag --repo IBuySpy-Shared/basecoat --dir .\release-evidence`.
Verify `SHA256SUMS.txt` against archive hashes, inspect the extracted archive's
`base-coat\version.json` and manifest, and compare them with the canonical tag
and installed payload (the source archive may use a different root).
Use a project-local evidence directory, not shared temporary paths. Update the
consumer `.basecoat.yml` `ref` to the exact verified tag in its upgrade PR;
environment overrides alone do not persist a pin.

The existing release consumer smoke runner provides an additional packaged
installation check after publication:

```powershell
pwsh tests\run-consumer-smoke.ps1 -BaseCoatRepo IBuySpy-Shared/basecoat `
  -Version $ReleaseTag -ArtifactSource Release
if ($LASTEXITCODE -ne 0) { throw 'Release consumer smoke failed' }
```

This supplements, not replaces, the selection-preserving upgrade fixture and
installed intent/decomposition assertions.

Inspect/hash installed routing instructions, ship-it skill and delivery contract,
`scripts\ship-it\dispatch-intent.ps1`,
`scripts\ship-it\validate-target-repository.ps1`,
`scripts\pr-decomposition-evaluator.cjs`, managed dispatch/merge workflows,
and each captured active workflow. Compare to tag-source bytes or documented
installer transformations; a matching version number alone is insufficient.
Confirm the active merge executor resolves the installed canonical evaluator
path and active dispatch uses the installed target validator.

## Testing Strategy

Candidate source commands (existing suites; run before the parent's release):

```powershell
pwsh scripts\validate-basecoat.ps1
pwsh tests\ship-it-dispatch-tests.ps1
pwsh tests\workflow-issue-approve-routing-tests.ps1
pwsh tests\routing-guardrail-tests.ps1
pwsh tests\pr-auto-merge-executor-tests.ps1
pwsh tests\merge-eligibility-human-review-reconcile-tests.ps1
pwsh tests\consumer-updater-tests.ps1
pwsh tests\workflow-ownership-tests.ps1
pwsh tests\release-process-doc-tests.ps1
```

Source suites are regression evidence, not proof of consumer installation.
In the disposable consumer, execute equivalent fixture assertions using the
**installed** dispatcher and canonical evaluator/runtime with mocked GitHub
responses; never dispatch live delivery just to test. Include:

| PRD requirement | Installed test / expected result |
|---|---|
| R1/R5 | Tag ancestry, hashes and metadata match; wrong expected SHA/version is rejected. |
| R2/R3 | `feature:` retains draft/intake; valid explicit aliases normalize, preserve actor/evidence, and do not fabricate approval. |
| R3/R4 | Missing approval/delivery, malformed directives and log-only/read-only intent cannot trigger delivery. |
| R2/R4 | Independent batch at 16 files or 301 lines blocks; cohesive unit follows ordinary gates; incomplete/stale exception blocks. |
| R4 | XXL without qualified human review, failed checks, or missing production approval remains blocked. |
| R3/R5 | Complete and staged-only refresh succeed without new classes; partial/invalid ownership fails; second refresh has no owned-content drift. |

Record actual fixture test names and outputs, not merely expected outcomes.
Check unknown local workflows and guidance hashes before/after; do not run a
live publish/deploy in the fixture. Existing 31 strict MkDocs baseline warnings,
if still present, must be reported separately, not fixed by broadening this PR.

## Rollout, Migration, and Rollback Plan

Pilot -> early adopters -> broad rollout only after artifact and installed
acceptance passes. Publish the actual verified tag, SHA, payload inventory and
pin instructions in release evidence. Use normal consumer PR reviews/checks.
No storage migration is needed. On failure stop rollout, retain failed evidence,
and restore the previous pin and factory-owned staged/active files through a
reviewed consumer rollback PR; preserve repository-owned content. Revalidate
rollback installation and disclose that the older pin lacks these fixes.
Never force-move an existing tag, bypass production approval, or claim a partial
mirror publish is successful.

## Observability and Operational Readiness

Release owner attaches: final SemVer rationale, candidate/tag SHA, merge ancestry
results, notes URL, source/mirror assets and checksum results, preflight and
release/package/publish run URLs/status, and current-head gate evidence.
Consumer verifier attaches: fixture identity (not an experiment), prior/new pin,
selection state/classes/targets, installed provenance and hashes, active workflow
comparisons, negative-case results, idempotence result, and upgrade/rollback PR.
Any missing item remains pending in #3495; documentation readiness is separate
from release acceptance.

## Risks, Mitigations, and Open Decisions

Parent release owner resolves version, candidate SHA, pilot fixture and gate
actors at execution. Mixed payload versions are mitigated by full sync plus
targeted onboarding and byte-level installed evidence. Partial publication is
mitigated by preflight and checking both repositories before recommending a pin.
No approval decision is pre-filled in this spec.

## References

- [PRD](../../prd/synthesized/issue-3495-release-and-verify-gated-delivery-and-pr-decomposition-updat.prd.md)
- [Source #3495](https://github.com/IBuySpy-Shared/basecoat/issues/3495)
- [Release process](../../operations/release-process.md)
- Rollout lifecycle: `skills/rollout-basecoat/references/delivery-lifecycle.md`
- Delivery intent contract: `skills/ship-it/references/delivery-intent-contract.md`
- [Governance contract](../../reference/governance-contract.md)
