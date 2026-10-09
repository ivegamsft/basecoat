---
issue: 3628
title: "design(intent): define build: completion and authorization contract"
status: proposal
author: ibuyspy
created: 2026-10-07
labels: ["enhancement", "priority:medium", "needs-triage", "needs-prd", "synthesize-spec"]
---

# PRD: design(intent): define build: completion and authorization contract

## Problem Statement

Implementation, compilation and delivery are different outcomes. A broad
`build:` prefix could ambiguously mean any of them and accidentally inherit
merge or deployment authority. Existing `feature:` already covers design,
implementation and validation without implicit delivery consent.

## Why This Matters

Users need a bounded implementation handoff whose evidence names the approved
scope and exact revision. Green checks demonstrate validation, not authority
to promote a feature-origin draft or ship it.

## Scope

This PRD and its companion spec define a documentation-only proposal for the
implementation boundary, alternative names, observable exits and future
acceptance fixtures. They do not register `build:` or `implement:`, modify
runtime routing, approve source work, or assign a coding agent.

The recommended decision is to retain the existing `feature:` route and treat
implementation as a work-unit concept until a distinct prefix is justified.
Reserve ordinary build terminology for compilation/artifact production.
Any future route requires a separately approved implementation contract.

## Users and Outcome

Solo developers and their agents need to implement authorized scope in an
isolated branch/worktree and produce a draft PR plus exact-revision validation
evidence. They must be able to pause, resume or report a blocker without
claiming successful delivery.

## Non-goals

- No new intent parser, alias, skill, workflow, label or approval behavior.
- No merge, tag, release, deployment or source-issue closure based on tests.
- No new routine human PR review for authorized XS through XL work.
- No automatic authorization inherited from synthesized documents.

## Success Criteria

- [x] Separate implementation, compilation and delivery meanings.
- [x] Compare existing `feature:`, proposed `build:` and `implement:`.
- [x] Define source identity, allowed writes, evidence freshness and stop states.
- [x] Specify positive/negative routing fixtures before any runtime change.
- [x] Preserve existing solo-dev and feature-origin delivery boundaries.

## Planning and Handoff

Documentation finalization is part of the #3690 queue-recovery wave.
Future runtime adoption remains unassigned under #3628; no implementation
sprint or approval is inferred. Proposal publication is complete when these
documents pass documentation checks and merge, not when a prefix executes.

## References

- Refs #3628
- Issue: <https://github.com/IBuySpy-Shared/basecoat/issues/3628>
- Comparison: [AI SDLC Work Units](../../design/ai-sdlc-work-units.md)
- Current contract: [Intent Prefixes](../../guides/intent-prefixes.md)
