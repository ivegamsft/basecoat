---
issue: 3630
title: "design(intent): define deliver: completion and authorization contract"
status: proposal
author: ibuyspy
created: 2026-10-07
---

# PRD: design(intent): define deliver: completion and authorization contract

## Proposal Status

Documentation proposal only. `deliver:` is not registered or supported
syntax. No implementation, delivery, authorization, parser, or workflow
behavior is approved here. This proposal is ready for design review, not
implementation.

## Problem Statement

BaseCoat already routes governed end-to-end delivery through `ship-it:` and
`spec-2-prod:`. A candidate `deliver:` could describe the completion-based
outcome, but risks creating a second executor, weakening existing consent
checks, or duplicating those supported routes.

## Why This Matters

An end-to-end outcome must be bound to approved scope and exact evidence at
each consequential boundary. A successful build or merge is not verified
production completion, and an authorization to deliver one scope cannot
silently expand to other work.

## Scope

In scope: define a proposed bounded delivery contract, compare it with
`ship-it:` / `spec-2-prod:`, identify evidence, permissions, stop/resume
conditions, future parser fixtures, and migration gates.

Out of scope: register `deliver:`; create a second execution engine; approve
or assign source issues; broaden authorization; change solo-dev policy;
implement code; bypass checks, reviews, XXL boundaries, merge queue, release,
deployment, or environment gates.

## Alternatives and Recommendation

| Alternative | Benefit | Cost / risk |
| --- | --- | --- |
| Keep `ship-it:` / `spec-2-prod:` as the governed delivery routes | Reuses the existing authorization receipt, scope, boundary revalidation, and release gates | Requires accurate documentation that these routes already represent the outcome |
| Add `deliver:` as an alias | Outcome-oriented wording | Adds no new contract and may route around or drift from current controls |
| Add a distinct `deliver:` contract | Could express a genuinely different bounded outcome | Must prove distinct lifecycle/ownership and map to existing controls without a second executor or broader authority |

Recommendation: do not add an alias. Keep `ship-it:` / `spec-2-prod:` as the
supported delivery composition. Reconsider a distinct `deliver:` only if a
specific outcome boundary is not expressible today and its contract can be
implemented by composing existing governed controls.

## Bounded Proposal Contract

If separately approved, delivery begins with a qualified, current authority
receipt; an exact source issue/spec revision and approved scope; explicit
non-goals, dependencies, destination, and acceptance evidence; and stated
execution budgets. Reads may cover only those source records, named
dependencies, current checks, and authorized target/release evidence.

Potential writes are limited to the existing governed operations necessary to
complete that scope. Each operation must use its existing gate and permission
path. This proposal grants no permission to create approval labels, assign
agents, expand scope, skip required checks, review/merge outside policy, change
release targets, or deploy without target-specific authority. The
implementation-boundary choice and precise write matrix require approval in
the implementation spec.

Every handoff records immutable source/spec identity, approved scope, actor and
qualified authority evidence, target, current head/tree, check/run identity,
release/version identity, and production evidence with capture time. Re-fetch
and revalidate authority, scope, dependencies, target, and evidence at each
side-effect boundary. A caller-supplied identity or generated text is not
authority.

## Failure, Stop, and Resume

Stop before the next side effect when authority is missing, ambiguous, revoked,
or stale; scope/spec or dependency changed; required checks are missing or
failed; target identity changed; or budget is exhausted. Record completed
boundaries, in-flight effects, exact evidence, blocker, and safe next action.
Partial execution is not completion. Resume only from that checkpoint after
revalidating live authority, approved scope, dependencies, target, current
head, required checks, and budgets. Never infer rollback permission from
delivery permission; destructive recovery needs its own applicable authority.
Completion requires the approved acceptance evidence for the exact target,
not issue closure, merge, or a dispatch marker alone.

## Proposal Acceptance Criteria

- [x] Existing delivery routes, alias risk, and a distinctness test are
  documented with a recommendation against an unjustified synonym.
- [x] Bounded scope, identity/freshness, read/write boundary, verified
  production exit, and failure/stop/resume behavior are specified.
- [x] Future parser fixtures, distribution/migration, and rollout gates are
  explicit and do not claim current support.
- [x] No implementation authority is inferred from this documentation.

## Future Adoption and Rollout Gates

Require a separately approved implementation issue/spec; evidence that
existing `ship-it:` / `spec-2-prod:` cannot express the outcome; explicit
reuse of their qualified authority and boundary gates; actual-parser and
negative authorization fixtures; target-specific success/failure tests; and
review of downstream/distributed mappings. Roll out only after those gates,
with bounded observation and a documented recovery plan. No migration or
runtime rollout is part of this proposal.

## References

- Source proposal: #3630
- Comparison: [`docs/design/ai-sdlc-work-units.md`](../../design/ai-sdlc-work-units.md)
- Current governed delivery route:
  [`docs/guides/intent-prefixes.md`](../../guides/intent-prefixes.md),
  [`docs/guides/spec-to-production.md`](../../guides/spec-to-production.md),
  `skills/ship-it/SKILL.md`
