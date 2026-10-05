---
issue: 3495
title: "Release and verify gated delivery and PR decomposition updates"
status: proposed
author: ibuyspy
created: 2026-10-04
labels: ["enhancement", "priority:medium", "needs-prd", "synthesize-spec"]
---

# PRD: Release and verify gated delivery and PR decomposition updates

## Problem Statement

Consumers pinned to a published release cannot receive fixes present only on
`main`. The downstream readiness report
[ss-control#189](https://github.com/IBuySpy-Dev/ss-control/issues/189) observed
feature intake treated as delivery consent and an oversized, single-PR batch
while pinned to `v4.5.1`. Source #3495 requests release and installed-consumer
verification, not another implementation of the already-merged fixes.

## Goals

Ship a traceable, compatible release containing #3493, #3485, and #3491; explain
the contracts in its notes; verify the supported refresh/onboarding path against
installed assets before recommending a consumer pin.

## Non-Goals

No downstream experiment repository edits, new intent engine, gate relaxation,
queue implementation, or changes to the merged routing/decomposition code.
This PR delivers one cohesive release-readiness PRD/spec, not a published
release. The parent release lane owns version selection, release PR, tagging,
publishing, production approval, and consumer verification after wave completion.

## Scope

The release owner must inventory the entire next release window, include all
three required merged PRs, publish accurate notes and artifacts through existing
release workflows, and verify a disposable consumer fixture. Review adjacent
changes for compatibility rather than claiming this release contains only the
three fixes. No intentional exclusion is proposed; exclusion requires explicit
scope review, rationale, and a revised acceptance decision.

## User Personas and Use Cases

- Release owner: proves tag ancestry, payload integrity, gates, and publication.
- Consumer maintainer: upgrades a pinned release in an isolated worktree and
  refreshes only previously selected factory-owned workflows.
- Feature author: uses `feature:` for intake and a separate qualified explicit
  delivery directive when ready; does not mistake routing for approval.

## User Experience Summary

Release notes describe `feature:` as issue/spec/draft intake, not automatic
delivery. `ship-it: <goal>` and `spec-2-prod: <goal>` are existing-intent aliases,
not consent shortcuts. Consumer instructions name an actual verified release
tag, preserve local configuration, and distinguish staged payload from active
workflow installation. A partial installation or failed verification blocks
rollout instead of producing a misleading success message.

## Functional Requirements

| ID | Requirement | Spec section / evidence |
|---|---|---|
| R1 | Release tag descends from merges #3493, #3485, #3491; disclose exclusions if scope changes. | Provenance and version selection / ancestry checks |
| R2 | Notes explain intake, explicit delivery, independent approvals, batch limits and mechanical exceptions. | Interface and governance contracts / published notes review |
| R3 | Refresh verifies installed routing, evaluator/runtime, and selected active workflows, not just upstream main. | Consumer verification / fixture assertions and logs |
| R4 | Preserve issue approval, XXL qualified human review, required checks, merge protections, production approval and rollback. | Security and failure modes / negative cases |
| R5 | Use supported rollout/onboarding, prove metadata alignment, and publish an exact verified consumer pin. | Rollout and rollback / tag, archive, provenance and upgrade PR |

## Non-Functional Requirements

Verification must be reproducible, fail closed, redact credentials, and leave
repository-owned files and unselected workflow classes unchanged. Repeat refresh
must be idempotent. Archive, source, and installed versions must agree.

## Success Criteria

- [ ] R1: all three required merge commits are ancestors of the published tag.
- [ ] R2: published notes cover both contracts and the full-refresh recommendation.
- [ ] R3: complete, staged-only, and negative consumer fixture cases have recorded
  results; installed-content assertions and repeat-refresh checks pass.
- [ ] R4: missing approval/delivery, XXL review, checks, or production evidence
  still blocks the relevant step; no synthetic approval evidence is created.
- [ ] R5: rollout instructions name the verified tag and matching installed
  version/provenance; consumer upgrade is reviewed through its normal PR gates.

These are release-owner completion criteria, intentionally unchecked until
executed. PRD/spec readiness does not close #3495 or establish release success.

## Constraints and Assumptions

Observed on 2026-10-05: latest published release is `v4.5.2`; its tag resolves to
`36243362189f2bf4582aeb8d22e167dc5ff76ba5`. The inspected `origin/main` is
`66945773`, 19 commits ahead; root metadata still says `4.5.2`. Counts are a
snapshot, not a release identifier. The next version is pending the release
owner's full-window SemVer review. Do not recommend `main`, the old tag, or an
invented next tag as the verified fix pin.

## Risks and Open Questions

Mixed staged/active workflow versions can hide missing fixes; verify both.
Auth or production-mirror failure can create partial publication; stop rollout.
The release owner resolves the final version, candidate SHA, pilot consumer,
and approval evidence URLs at execution time. No human approval is implied by
this document or by solo-dev workflow execution approval.

## Dependencies

Required code is merged in #3493, #3485, and #3491. Use the existing release
process, rollout-basecoat skill, downstream installer, installed validator, and
consumer-update selection capture. Parent coordinates queue prerequisite #3499
separately; this spec neither implements queue code nor bypasses merge gates.

## Rollout and Adoption Plan

Release owner validates the candidate and token preflight, obtains normal release
approval, and publishes via the canonical source repository. Verify source and
production mirror artifacts before pilot refresh. Preserve selected install
classes, validate installed behavior, then recommend the exact verified tag for
early adopters and broad rollout. Roll back through a consumer PR to the prior
known-good pin and owned files; older behavior is not a successful fix rollout.

## References

- Source: <https://github.com/IBuySpy-Shared/basecoat/issues/3495>
- Implementation: [#3493](https://github.com/IBuySpy-Shared/basecoat/pull/3493),
  [#3485](https://github.com/IBuySpy-Shared/basecoat/pull/3485),
  [#3491](https://github.com/IBuySpy-Shared/basecoat/pull/3491).
- [Spec](../../spec/synthesized/issue-3495-release-and-verify-gated-delivery-and-pr-decomposition-updat.spec.md)
- [Release process](../../operations/release-process.md)
- [Enterprise rollout](../../guides/enterprise-rollout.md)
- [Governance contract](../../reference/governance-contract.md)
