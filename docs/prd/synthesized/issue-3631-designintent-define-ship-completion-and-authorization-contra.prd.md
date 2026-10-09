---
issue: 3631
title: "design(intent): define ship: completion and authorization contract"
status: proposal
author: ibuyspy
created: 2026-10-07
---

# PRD: design(intent): define ship: completion and authorization contract

## Proposal Status

Documentation proposal only. `ship:` is not registered or supported syntax.
No release, deployment, parser, workflow, or authorization behavior is
approved here. This proposal is ready for design review, not implementation.

## Problem Statement

BaseCoat already separates release planning/publication (`release:`), staged
deployment (`deploy:`), and governed end-to-end delivery (`ship-it:` /
`spec-2-prod:`). A candidate `ship:` could clarify a publication-only
boundary, but may duplicate those supported compositions or suggest broader
authority than intended.

## Why This Matters

Publishing a release and deploying it are different side effects. Both must
be bound to the exact validated artifact, version, destination, and current
authority. A tag or successful publication alone does not prove target health.

## Scope

In scope: define publication-only boundaries, compare `ship:` with existing
release/deployment/delivery routes, specify immutable evidence and permissions,
failure/retry/recovery behavior, future parser fixtures, and adoption gates.

Out of scope: registering `ship:`; implementing code; creating or changing
versions, tags, releases, packages, or deployments; selecting an environment;
expanding implementation scope; bypassing release, deployment, or production
gates.

## Alternatives and Recommendation

| Alternative | Benefit | Cost / risk |
| --- | --- | --- |
| Compose existing `release:` and `deploy:` under current governance | Preserves publication/deployment separation and reuses existing gates | Requires clear handoff and artifact identity in the docs |
| Add `ship:` as an alias for `release:` or `ship-it:` | Short, familiar word | Duplicates routing and risks confusing publication with end-to-end delivery or deployment |
| Add a distinct publication-only `ship:` | Could make immutable-artifact publication independently discoverable | Must prove a unique boundary and define ownership, version/tag policy, evidence, and recovery |

Recommendation: do not add an alias. Use existing `release:` for governed
release preparation/publication and `deploy:` for staged deployment, composed
only when their current authority and gates permit. Retain `ship-it:` /
`spec-2-prod:` for governed end-to-end delivery. Reconsider `ship:` only if a
distinct publication-only need cannot be expressed by that composition.

## Bounded Proposal Contract

If separately approved, publication input is a previously validated immutable
artifact plus a qualified current publication authority, exact version/tag,
source commit/tree, artifact and manifest digests, intended repository or
registry, and verification requirements. The requested destination and
version/tag owner must be explicit. Reads may inspect only those identities,
validation results, current release state, and target publication evidence.

Writes, if later approved, are limited to existing release publication
operations for that exact artifact and destination. No implementation,
source-branch change, retagging, target selection, deployment, issue approval,
or permission expansion is implied. Do not invent a tag owner or version
policy; resolve those in the implementation spec against existing release
governance.

Evidence must bind the validated commit/tree and validation runs to the
artifact digest, version/tag, destination, published payload, and captured
verification result. Production deployment and health are separate evidence
and require their own existing authority. A tag, merge, or dispatch marker
alone is not proof of publication or production success.

## Failure, Stop, Retry, and Recovery

Stop before writing if authority is absent/revoked; version, tag, digest, or
destination is ambiguous or mismatched; validation is stale or failed; the
tag already identifies different content; or required publication evidence
is unavailable. Record a checkpoint and partial state. Retry only against
the same immutable artifact/version/destination with idempotency verified by
the existing publisher; never retarget or overwrite a tag to make retry pass.
A partial publication is not success. Recovery or rollback requires its
applicable separate authority and must preserve the immutable release record.
Resume by revalidating permission, source/artifact identity, version/tag,
target, existing publication state, and budget.

## Proposal Acceptance Criteria

- [x] Publication, release planning, deployment, and end-to-end delivery are
  distinguished; recommendation avoids an unjustified alias.
- [x] Immutable artifact/version/destination identity, freshness, permissions,
  and production-evidence boundary are explicit.
- [x] Stop, same-target retry, partial failure, recovery, and resume rules are
  explicit without inventing tag ownership or rollback authority.
- [x] Parser, distribution/migration, and rollout gates preserve unsupported
  candidate status.

## Future Adoption and Rollout Gates

Require a separate approved implementation issue/spec, a demonstrated
publication-only gap, explicit release/tag ownership and immutable identity
rules, and a precise composition with `release:`, `deploy:`, and existing
delivery governance. Add actual-parser positive/negative fixtures and
publisher tests for identity mismatch, existing-tag collision, same-target
retry, partial publication, and recovery. Update canonical and distributed
instructions, skills, workflows, examples, and migration guidance together.
Do not roll out until the existing release pipeline can verify the exact
payload and destination. This documentation proposal performs no migration.

## References

- Source proposal: #3631
- Comparison: [`docs/design/ai-sdlc-work-units.md`](../../design/ai-sdlc-work-units.md)
- Current routes: [`docs/guides/intent-prefixes.md`](../../guides/intent-prefixes.md),
  [`docs/guides/spec-to-production.md`](../../guides/spec-to-production.md)
