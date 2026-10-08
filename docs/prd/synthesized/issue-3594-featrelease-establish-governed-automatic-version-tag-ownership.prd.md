---
issue: 3594
title: "feat(release): establish governed automatic version-tag ownership after validated merge"
status: proposed
author: ibuyspy
created: 2026-10-06
labels: ["enhancement", "priority:high", "needs-triage", "needs-prd", "synthesize-spec"]
---

# PRD: Governed automatic version-tag ownership after validated merge

## Problem Statement

The release workflows consume a version tag, but no workflow owns the full,
authorized transition from a merged delivery scope to that tag. The release
train can report a candidate, while the release manager can create a version
change and tag; neither is a bounded, idempotent owner that proves the complete
release window, committed version metadata, current validation, and production
readiness before creating exactly one immutable tag.

## Why This Matters

Missing release ownership causes routine delivery to stop after merge or tempts
operators to tag every merge, use a moving ref, repeat a version, or mistake
dispatch and dry-run evidence for production authorization. A single owner
must connect approved scope to release without adding routine human approvals
for solo-dev XS through XL, while preserving explicit authorization, protected
merge policy, production gates, and honest failure reporting.

## Goals

- Define an auditable release-owner contract from explicit delivery scope to
  immutable version tag and verified publication.
- Preserve unattended progress for explicitly authorized work through XL
  without expanding the authorization represented by an issue label, merged PR,
  workflow dispatch, or release-candidate issue.
- Make release-window inventory, batching, version selection, retries, no-op
  cases, and post-tag recovery deterministic.

## Non-Goals

- This issue is a tracking and requirements-definition request only. This PRD
  and its paired spec do not implement workflows, create a release PR, approve
  a scope, create a tag, publish artifacts, or assign an agent.
- No new general-purpose approval system, queue bypass, tag mutation, production
  environment bypass, or automatic release of every merged PR.
- No changes to consumer installation or the production mirror's release
  workflow.

## Scope

Specify one serialized release owner that can prepare a reviewed version
metadata change for an explicitly authorized delivery scope, then create one
matching immutable tag only after the metadata change is merged and current
release evidence and token readiness are revalidated. Existing tag-driven
release and package workflows remain the publishers. The owner verifies
publication in both canonical source and production mirror before reporting
completion.

## User Personas and Use Cases

- **Delivery owner:** authorizes a bounded delivery scope once and receives
  traceable progress without routine re-approval at every ordinary release
  step.
- **Release owner:** sees the complete interval of merged work, a reproducible
  version decision, and explicit stop/retry actions.
- **Maintainer:** can distinguish an authorized candidate, merged version
  metadata, created tag, internal release, and production publication.

## User Experience Summary

The owner reports one of: no eligible release; blocked with a precise missing
precondition; candidate prepared and awaiting normal merge policy; tag created
for a specific metadata commit; or release verified with source/mirror evidence.
It never reports a dispatch, tag, or internal-only release as completed
production delivery.

## Functional Requirements

| ID | Requirement | Evidence |
|---|---|---|
| R1 | Only an existing qualified delivery authorization is eligible: the same-repository source issue, exact approved scope/spec contract, exact standalone `/approve`, approved label, and currently qualified human permission must validate under #3591/#3476. Intake labels, merged status, candidate issues, and dry-run dispatch are not consent. | Authorization fixtures reject each proxy independently and scope mismatch. |
| R2 | Inventory every merged PR in the selected release window from the last verified tag through an immutable candidate commit; bind every included PR to the exact authorized PR set and disclose exclusions with rationale. | Complete inventory, authorization-to-PR mapping, and ancestry report. |
| R3 | Apply documented SemVer and batching rules; handle concurrent merges without losing or silently adding scope. | Version decision and concurrent-merge tests. |
| R4 | Commit version, changelog, and manifest metadata through the normal protected PR/queue path; tag only the exact merged commit whose metadata matches the tag. | Merged metadata SHA and tag-to-commit/version assertions. |
| R5 | Revalidate current authorization, #3595 unified release-label coverage, window inventory, merge/check evidence, metadata, and production-token readiness immediately before tag creation. | Stale-evidence, coverage-policy, and missing-token negative tests. |
| R6 | Serialize attempts through durable compare-and-swap state; retries are idempotent, never move an existing tag, and never publish a different target under the same version. | Restart, concurrent duplicate, retry, stale-write, and conflicting-tag tests. |
| R7 | Treat no eligible work and docs-only work explicitly; distinguish a valid no-release outcome from a failed or incomplete run. | No-op and docs-only policy tests. |
| R8 | Verify canonical release assets, checksums, production mirror tag/assets, and required smoke/docs evidence before claiming production completion. | Source/mirror artifact and verification evidence. |
| R9 | Make partial publication recoverable by retrying the existing immutable tag's failed publishing work; never delete or retarget the tag. | Partial-failure recovery exercise. |

## Non-Functional Requirements

The owner must fail closed on incomplete inventory, missing or stale evidence,
ambiguous scope, API errors, missing token readiness, and conflicting version
state. Operations must be bounded, auditable, least-privileged, safe to retry,
and must not expose credentials in logs. Version tags are immutable. The
workflow must not run untrusted PR code with release credentials.

## Success Criteria

- [ ] An explicitly authorized delivery scope can proceed through normal
  release gates without an additional routine human approval through XL.
- [ ] No candidate is built from a moving ref or incomplete time-limited PR
  listing; all release-window items have an inclusion or exclusion disposition.
- [ ] `version.json`, `CHANGELOG.md`, `asset-manifest.json`, and the proposed
  tag's exact commit agree before tag creation.
- [ ] Concurrent runs and retries yield one intended tag or a clear conflict;
  no existing tag can be retargeted.
- [ ] Missing production token readiness or any failed gate prevents tag
  creation; a post-tag publishing failure is reported as partial, not complete.
- [ ] A successful report links the exact tag/SHA, source and mirror releases,
  assets/checksums, and required smoke/docs results.

These criteria define future implementation and operational acceptance. This
PRD/spec contribution does not satisfy release execution criteria or close
issue `#3594`.

## Constraints and Assumptions

- The current release process uses `version.json`, `CHANGELOG.md`, `release.yml`,
  `package-basecoat.yml`, `token-preflight.yml`, and
  `publish-to-production.yml`; tag-triggered publishing is downstream of tag
  creation.
- The post-merge release chain uses dry-run release-gate evidence and must not
  be promoted into authorization.
- Production token preflight proves readiness, not scope approval or delivery
  consent. Tag-creation credentials must be narrowly scoped and distinct from
  the production mirror token unless repository policy proves otherwise.
- The full merged-PR inventory is bounded by immutable tags/SHAs, not an
  arbitrary recent-time fallback. If its baseline cannot be proven, stop.
- Version policy remains the canonical release-process SemVer policy. The
  implementation spec must resolve how no-release and docs-only cases map to
  it without silently discarding merged work.

## Risks and Open Questions

A missing or moved tag baseline can omit work; require ancestry and complete
pagination. A concurrent merge can change the candidate; freeze the release
scope at a specific commit and repeat the inventory immediately before tagging.
GitHub token semantics may prevent downstream workflows from triggering when
the tag is created with the default workflow token; use a reviewed, narrow
credential path and prove the event chain in tests. A release may be present in
the source repository while mirror publication fails; report the partial state
and retry publishing without moving the tag.

## Dependencies

- Existing protected merge/queue and version-consistency checks.
- Current `release.yml`, `package-basecoat.yml`, `token-preflight.yml`,
  `publish-to-production.yml`, and release process. The owner must observe all
  tag-triggered publisher workflows, not infer completion from one workflow.
- #3578 immutable packaging target contract.
- #3591/#3476 qualified approval and delivery-intent contracts. The exact
  authorized release scope must map deterministically to the included PR set;
  ambiguous or unrepresentable scope blocks tag creation.
- #3595 unified release-label coverage implementation and verification. This
  proposal does not claim the merged specification is deployed; tag creation
  remains disabled until that implementation is merged and its exact policy is
  verified across PR, merge-group, and release-window gates.

## Rollout and Rollback Plan

Future implementation must first run in report-only mode against a complete
release window, then prepare metadata through the normal PR and merge queue.
Tag creation is enabled only after contract tests, token/event-chain checks,
and source/mirror recovery verification pass. Rollback means stop new candidate
creation and repair or retry publishing for the already-created tag. Never
delete, force-move, or reuse a version tag.

## References

- Source: <https://github.com/IBuySpy-Shared/basecoat/issues/3594>
- Related immutable packaging contract: [#3578](https://github.com/IBuySpy-Shared/basecoat/issues/3578)
- [Release process](../../operations/release-process.md)
- [Governance contract](../../reference/governance-contract.md)
- [Paired spec](../../spec/synthesized/issue-3594-featrelease-establish-governed-automatic-version-tag-ownership.spec.md)
