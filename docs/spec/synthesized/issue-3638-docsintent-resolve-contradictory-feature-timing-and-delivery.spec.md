---
issue: 3638
title: "docs(intent): resolve contradictory feature timing and delivery-family classification"
status: documentation
author: ibuyspy
created: 2026-10-07
labels: ["documentation", "priority:high", "priority:low", "needs-triage", "needs-prd", "needs-info", "synthesize-spec"]
---

# Spec: docs(intent): resolve contradictory feature timing and delivery-family classification

## Problem Statement

The same feature prefix is described as immediate implementation, backlog work, and part of a delivery family.

## Why This Matters

Different normative directions for identical input make the handoff unsafe.
This correction makes existing context rules consistent without extending
the supported prefix set or execution authority.

## Scope

Update the canonical instruction's enforcement rule and vocabulary row, the
guide's vocabulary/family/modifier descriptions and deterministic examples.
Regenerate the tracked instruction blob SHA in the asset manifest.

## Timing Contract

| Context | Result |
| --- | --- |
| Standalone `feature:` | Immediate design/implementation after LOG-FIRST and plan-first |
| Bulleted `feature:` | Log/triage; no implementation even with a timing word |
| Explicit `later`, `backlog`, `next sprint` | Defer, regardless of ordinary prefix default |
| Standalone explicit `now` | Immediate gated implementation |
| Immediate and stop/defer conflict | Block; do not select a winner |
| Quoted/fenced/embedded example | Data, not an invocation |

All implementation outcomes stop at a draft handoff without separate delivery
authority. Approval and green checks never imply ready promotion, merge, tags
or deployment. Existing solo-dev XS-XL and XXL policies are unchanged.

## Alternatives and Ownership

Making all features backlog-only would contradict the existing standalone
rule. Making bullets executable would violate triage-only handling.
Keep context-sensitive timing with the canonical instruction as owner, and
link the guide to it rather than adding another parser or authority mechanism.

## Validation and Failure Handling

Lint changed documentation/instructions, run routing guardrails and structure
validation, regenerate asset-manifest.json and verify only the intended
instruction record changed. Build documentation and disclose baseline strict
warnings rather than calling the strict build green. Hosted required checks
and native queue remain mandatory.

No runtime prefix parser is changed; examples verify the documented contract,
not a new executable route. Invalid or ambiguous requests remain non-success
handoffs with named reasons and no implied mutation permission.

## Rollout and Risks

Normal asset sync distributes the canonical instruction. Existing downstream
aliases continue pointing to that owner. No label, approval, spec or workflow
migration is required. Revert this correction and manifest record together
if downstream instruction interpretation regresses.

The remaining risk is consumer drift: compare both tables during instruction
updates, and keep timing independent from authority. No production behavior
or healthy-service claim follows from this documentation publication.

## Acceptance Criteria

- [x] Canonical and guide timing agree for each context in the matrix.
- [x] Feature family no longer implies delivery authority.
- [x] Existing supported tokens and feature-origin gates are preserved.
- [x] Distribution and rollback include the asset-manifest identity.

## References

- PRD: `docs/prd/synthesized/issue-3638-docsintent-resolve-contradictory-feature-timing-and-delivery.prd.md`
- Refs #3638
- Issue: <https://github.com/IBuySpy-Shared/basecoat/issues/3638>
