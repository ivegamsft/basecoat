---
issue: 3631
title: "design(intent): define ship: completion and authorization contract"
status: proposal
author: ibuyspy
created: 2026-10-07
---

# Spec: design(intent): define ship: completion and authorization contract

## Status and Authority

Proposal only; `ship:` is unsupported. No release, deploy, parser, workflow,
or authorization behavior is approved. Implementation requires a separately
approved issue and spec.

## Decision Boundary

| Concern | Proposed contract |
| --- | --- |
| Publication | Make one already validated immutable artifact available at its explicitly authorized destination |
| Deployment | Separate staged operation under the existing `deploy:` contract and target authority |
| End-to-end delivery | Existing `ship-it:` / `spec-2-prod:` composition |
| Release preparation/publication | Existing `release:` process and its current owners/gates |
| Candidate `ship:` | Add only if publication has a distinct unmet boundary; do not register as an alias |
| Completion | Verify exact published payload at the named destination; production health is a separate result |

## Inputs and Immutable Identity

| Input | Required identity |
| --- | --- |
| Authority | Qualified current permission/receipt for publication and named destination |
| Source | Repository, commit/tree, approved scope, and validation run identities |
| Artifact | Immutable digest, manifest/provenance, build identity, and content |
| Release | Exact version and tag plus the existing tag/version owner and policy |
| Destination | Explicit repository, registry, or publication target; never infer from a default |
| Verification | Expected payload/metadata, evidence source, capture time, and applicable freshness policy |

Caller-supplied values must be checked against trusted source and publisher
state. If ownership or version policy is undefined, stop for a separate
decision; this proposal does not invent it.

## Scope

Read only the named source, artifact provenance, validation results, current
release/tag and publisher state, destination, and publication evidence.
Publication writes are not authorized by this proposal; if separately
implemented, use only existing approved release mechanisms for the exact
artifact and destination.

## Evidence and Freshness

Bind validation to source commit/tree and run; bind the built artifact to
digest and manifest; bind the release to exact version/tag and destination;
bind verification to the published payload and capture time. Evidence is
current only when all identities match and the applicable source freshness
policy holds. A tag, merge, dispatch marker, or internal release record alone
does not prove the intended payload reached the destination or that a
production target is healthy.

## Read and Write Matrix

| Operation | Proposed boundary |
| --- | --- |
| Read | Named source/artifact/provenance, successful current validation, release/tag state, destination state, publication proof |
| Publish | Only after separate authority and existing release gate; immutable artifact, exact version/tag, exact destination |
| Deploy | Not part of publication; requires existing deployment route, target and authority |
| Prohibited by default | Implement code, rebuild from changed source, overwrite/move a tag, retarget destination, create approval, skip release checks, deploy, or claim production health |

No additional workflow, permission, or token is proposed.

## Failure, Stop, Retry, and Resume

| Condition | Required behavior |
| --- | --- |
| Missing/revoked authority, unclear owner, source/artifact mismatch | Stop before write; report blocker |
| Failed/stale validation, missing provenance, changed artifact | Do not publish; rebuild/revalidate only under separate scope |
| Existing tag resolves to different content | Fail closed; never overwrite or retarget |
| Destination mismatch or unavailable verification evidence | Do not claim publication success |
| Timeout/uncertain publisher result | Query exact same target/version/digest before retry; preserve uncertainty if not determinable |
| Partial publication | Record each completed effect and checkpoint; report non-success |
| Retry | Same immutable artifact, version/tag, and destination only; require existing publisher idempotency |
| Recovery/rollback | Separate authority; preserve published records and do not imply automatic rollback |
| Resume | Revalidate live authority, artifact/source identity, version/tag, destination, publisher state, freshness, and budget |

Publishing does not silently implement or deploy missing work. Production
health requires separate target-specific deployment and observation evidence.

## Future Parser and Behavior Fixture Plan

Required only if a distinct route is approved and implemented.

| Case | Expected future behavior |
| --- | --- |
| Approved standalone candidate for a validated immutable artifact | Route only if registered and compose current release gates |
| Candidate with no authority, ambiguous destination, unvalidated artifact | Reject before any write |
| Quoted, fenced, bulleted, or embedded candidate or conflicting/dual prefix | Do not execute or reject as ambiguous |
| `later`, `read-only`, `no changes`, explicit stop/defer | No publication side effects |
| Tag already points to different digest, stale validation, digest mismatch | Fail closed; preserve existing tag |
| Retry after timeout with same immutable identity | Inspect existing exact target state; never retarget |
| Partial publication or missing destination proof | Preserve checkpoint; do not claim complete |
| Request adds implementation or deployment | Stop and require separate approved scope/authority |

## Distribution, Migration, and Rollout Gates

Keep `release:`, `deploy:`, and `ship-it:` / `spec-2-prod:` authoritative.
If a distinct route is approved, update the actual parser and positive/negative
fixtures, define tag/version ownership and exact publisher write gates, map
canonical docs, instructions, skills, workflows and downstream projections,
and publish migration notes without rewriting existing approval records.
Validate immutable payload identity and same-target idempotent retry in a
non-production test path before rollout; production use remains behind
existing protected release/deployment gates. This proposal itself has no
runtime or distribution migration.

## Proposal Acceptance Criteria

- [x] Immutable source/artifact/version/destination identity and evidence
  freshness are explicit.
- [x] Publication is separated from release planning, deployment, and
  end-to-end delivery; permitted and prohibited effects are clear.
- [x] Stop, idempotent same-target retry, partial failure, recovery, and
  resume are specified without claiming rollback or tag ownership.
- [x] Future parser, distribution, migration, and rollout gates preserve
  unsupported syntax.

## References

- PRD:
  [`docs/prd/synthesized/issue-3631-designintent-define-ship-completion-and-authorization-contra.prd.md`](../../prd/synthesized/issue-3631-designintent-define-ship-completion-and-authorization-contra.prd.md)
- Comparison: [`docs/design/ai-sdlc-work-units.md`](../../design/ai-sdlc-work-units.md)
- Current routes: [`docs/guides/intent-prefixes.md`](../../guides/intent-prefixes.md),
  [`docs/guides/spec-to-production.md`](../../guides/spec-to-production.md)
