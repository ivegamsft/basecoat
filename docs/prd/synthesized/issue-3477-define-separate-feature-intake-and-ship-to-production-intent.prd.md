---
issue: 3477
title: "Define separate feature-intake and ship-to-production intent contracts"
status: draft
author: ibuyspy
created: 2026-10-04
labels: ["enhancement", "priority:high", "sprint:2026-W40"]
---

# PRD: Define separate feature-intake and ship-to-production intent contracts

## Problem and Outcome

Feature execution and ship authorization use different vocabularies today.
Preserve `feature:` as design/implementation intent while preventing agents from
inferring permission to merge or deploy from it. Make explicit delivery aliases
route to the existing ship-it control plane, not a new delivery engine.

## Scope

- Preserve standalone feature implementation, bulleted log-only intake, timing
  modifiers, LOG-FIRST, plan confirmation, and existing PR lifecycle modes.
- Add `ship-it:` and `spec-2-prod:` as colon aliases for the existing canonical
  intents, slash commands, and workflow inputs.
- Separate action routing, approved scope, PR merge checks, and production
  approval; record the explicit delivery directive and its original actor.
- Align routing guidance, ship-it skill/orchestrator, packaged workflow command
  resolution, and focused tests; prevent duplicate command ownership.
- Exclude runtime changes from this PR, renaming other prefixes, a new approval
  store, blanket automation consent, or automatic delivery from `feature:` alone.

## Success Criteria

- A standalone feature can still implement after its existing gates; it does
  not invoke release dispatch, enable auto-merge, merge, or deploy on its own.
- Colon aliases resolve to exactly `ship-it` or `spec-2-prod`; slash commands and
  workflow inputs resolve to those same canonical intents with the same gates.
- Quoted/bulleted/ambiguous directives, missing evidence, and denied actors never
  promote feature work into delivery.
- An explicit directive enables only gated, in-scope progression. Issue approval
  is not PR review, production approval, or a waiver of required checks.
- Positive/negative parser, consent, plan-first, and exact gate-boundary tests in
  the spec are added before implementation rollout.

## Delivery and Risk

Introduce aliases and their guidance atomically with one dispatch owner and
compatibility tests. Rollback removes new aliases without broadening feature
authority or removing approval boundaries. Main risk is language/dispatch drift
that treats routing as consent; audit normalized intent and original directive.

## References

- Spec: [implementation contract](../../spec/synthesized/issue-3477-define-separate-feature-intake-and-ship-to-production-intent.spec.md)
- Governance: `docs/reference/governance-contract.md`
- Refs #3477
- Issue: <https://github.com/IBuySpy-Shared/basecoat/issues/3477>
