---
issue: 3628
title: "design(intent): define build: completion and authorization contract"
status: proposal
author: ibuyspy
created: 2026-10-07
labels: ["enhancement", "priority:medium", "needs-triage", "needs-prd", "synthesize-spec"]
---

# Spec: design(intent): define build: completion and authorization contract

## Status and Decision

This is a complete design proposal, not an approved executable routing spec.
Neither `build:` nor `implement:` becomes supported by merging this document.
Retain current `feature:` behavior; prefer the conceptual word implementation
over adding an ambiguous synonym. Reconsider a prefix only if evidence shows
the existing route cannot express the bounded outcome.

## Why This Matters

An implementation handoff must prove approved scope without manufacturing
delivery consent. Compilation is a validation activity, not that handoff.

## Scope

Define a future implementation contract and its adoption gates. This change
only publishes proposal documentation; canonical/distributed runtime assets
remain unchanged.

## Alternatives

| Option | Benefit | Cost / disposition |
| --- | --- | --- |
| Keep `feature:` | Existing provenance and authorization machinery | Recommended; clarify implementation as a work unit |
| Adopt `build:` | Familiar term | Reject for now: ambiguous compilation versus implementation |
| Adopt `implement:` | More precise outcome | Candidate only if distinctness is demonstrated; no alias today |

## Input Contract

A future execution packet must bind repository, source issue, approved spec
path and immutable revision/digest, approved scope/non-goals, authorized actor
and live evidence, base/head identities, dependencies and execution budgets.
Re-read authority and dependencies before writes or resume. Missing, revoked,
wrong-repository or changed-scope evidence produces a blocked result.

## Permitted Writes and Outputs

After valid implementation authority, allow only the named in-scope source and
test changes, an isolated branch/worktree, attributed commits and a draft PR.
Record changed-file inventory, spec/issue identities, head/base SHA, exact
commands/results and a reproducible resume checkpoint.

Implementation authority does not permit ready promotion, auto-merge, merge,
tagging, deployment or approval labels. Existing feature-origin markers and
separate validated delivery directives remain mandatory. Solo-dev requires no
routine human review through XL once applicable authority exists; XXL and
other explicit human boundaries remain.

## Exit and Failure Contracts

| State | Evidence and next action |
| --- | --- |
| Implemented | In-scope diff and draft handoff; validation may still be pending |
| Validated | Positive/negative tests and checks for exact head; no delivery consent implied |
| Blocked | Name unmet authority, dependency, scope or validation condition and recovery action |
| Paused / limited | Durable checkpoint, remaining budget and outstanding effects; not success |
| Cancelled | Stop new side effects; do not assume permission to revert external changes |

Resume revalidates live actor permissions, source/spec identity, current diff,
dependencies and budget. Changed scope or revision invalidates affected test
evidence. A stale green run cannot be reused for a different head.

## Future Routing and Distribution Gates

Before adopting either prefix, add actual-parser positive and negative
fixtures for standalone mixed-case input, empty goals, quoted/fenced/bulleted
examples, embedded commands, lookalikes, dual authoritative prefixes, defer
and stop modifiers, unauthorized actors and compilation-only ambiguity.
Until adoption, tests must assert these candidates remain unsupported.

An approved adoption spec must name canonical instruction ownership, public
guidance, skill/workflow consumers and their distributed counterparts.
Generate the asset manifest for affected distributed assets and test sync
parity and old downstream compatibility. Do not create pointer aliases or
silent synonyms during documentation publication.

## Validation, Rollout and Observability

For this proposal, lint both artifacts, build documentation and verify no
runtime files changed. Required hosted checks and native queue govern merging.
Publication does not test or deploy a new router.

A future runtime rollout needs exact source/head-bound handoff records,
observable blocked reasons and fixture evidence. Start with an explicitly
authorized scope, preserve old supported routes, and revert the new route on
authority ambiguity. Roll back this documentation-only change by reverting
its commit; no migration or operational cleanup is required.

## Risks

Readers may confuse a published proposal with approved syntax. The status,
decision and non-goals explicitly prevent this. The main unresolved product
decision is whether another prefix earns a distinct contract; #3628 retains
that decision rather than inventing approval during queue recovery.

## Acceptance Criteria

- [x] Input/output, identity binding and permitted writes are explicit.
- [x] Compilation, implementation and delivery meanings are distinct.
- [x] Stop/resume and evidence invalidation rules are testable.
- [x] Parser fixture inventory and distribution/migration gates are defined.
- [x] Documentation-only rollout preserves unsupported token status.

## References

- PRD: `docs/prd/synthesized/issue-3628-designintent-define-build-completion-and-authorization-contr.prd.md`
- Refs #3628
- Issue: <https://github.com/IBuySpy-Shared/basecoat/issues/3628>
