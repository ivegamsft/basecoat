---
issue: 3638
title: "docs(intent): resolve contradictory feature timing and delivery-family classification"
status: documentation
author: ibuyspy
created: 2026-10-07
labels: ["documentation", "priority:high", "priority:low", "needs-triage", "needs-prd", "needs-info", "synthesize-spec"]
---

# PRD: docs(intent): resolve contradictory feature timing and delivery-family classification

## Problem Statement

The same feature prefix is described as immediate implementation, backlog work, and part of a delivery family.

## Why This Matters

Conflicting defaults cause either unrequested work or stalled implementation.
Family names must not manufacture delivery consent.

## Scope

Align the canonical instruction and user guide with the existing syntax rule:
standalone requests act now after LOG-FIRST and plan-first gates; bullets and
explicit defer modifiers are triage/backlog only. Conflicting immediate/stop
directions block. Rename the guide family to implementation and infrastructure
so it cannot imply feature merge or deployment consent.

## Non-goals

No new intent, alias, workflow, approval, agent assignment or production
authorization. Preserve feature-origin draft handoff and separate delivery
directives. Source #3638 can close only after this documentation correction
merges, not when a proposal or green check is generated.

## Success Criteria

- [x] Canonical rule and vocabulary agree on standalone versus backlog timing.
- [x] Standalone, bulleted, deferred and immediate examples are deterministic.
- [x] Family membership does not grant merge or deployment authority.
- [x] Distributed instruction identity is regenerated and structure validated.

## References

- Refs #3638
- Issue: <https://github.com/IBuySpy-Shared/basecoat/issues/3638>
