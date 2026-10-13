---
issue: 3630
title: "design(intent): define deliver: completion and authorization contract"
status: proposal
author: ibuyspy
created: 2026-10-07
---

# Spec: design(intent): define deliver: completion and authorization contract

## Status and Authority

Proposal only; `deliver:` is unsupported. No route, alias, executor,
authorization, or workflow behavior is approved. Implementation requires a
separately approved source issue and implementation spec.

## Decision Boundary

| Question | Proposed contract |
| --- | --- |
| Purpose | Reach the exact authorized outcome through governed implementation, integration, publication, and target verification |
| Existing supported route | `ship-it:` / `spec-2-prod:` and their current control plane |
| Candidate distinctness | Demonstrate an unmet outcome boundary; same route and effects mean alias, so do not add it |
| Completion | Exact approved acceptance evidence at the named target, not a PR merge, issue closure, or dispatch event |
| Default authority | None from this proposal or candidate word; current qualified delivery evidence remains required |

## Required Inputs

| Input | Required identity / rule |
| --- | --- |
| Authority | Qualified live receipt, actor, source comment/record, and current permission; re-fetch at each side-effect boundary |
| Source | Issue identifier, approved scope and non-goals, exact issue/spec revision or digest |
| Work | Exact change/head/tree, dependencies, expected files/outputs, budget and stop conditions |
| Destination | Repository, integration branch, release/version, deployment environment and target |
| Acceptance | Named checks and target-specific production evidence, with source identity and capture time |

Reject missing or ambiguous inputs. Never accept caller assertions, generated
text, labels alone, or stale receipts as authorization.

## Scope

Only perform actions within the exact approved scope, through existing
governed mechanisms. Parallel preparation does not permit concurrent merges
or relax dependency ordering.

## Evidence and Freshness

Bind every check to its commit/tree or integration tree, workflow/run, and
result. Bind publication to immutable version/tag, source commit, artifact
digest, and destination. Bind production verification to the named target,
observed behavior, and capture time. Evidence is current only when identities
match the requested scope and target and the relevant system's freshness
policy is satisfied. Revalidate authority, dependencies, checks, target, and
budget before each irreversible boundary. No global TTL is implied.

## Read and Write Boundaries

| Class | Proposed boundary |
| --- | --- |
| Read | Approved issue/spec/receipt, declared dependencies, exact-head checks, integration queue state, and explicitly named release/production evidence |
| Write | Only operations necessary for the approved scope through existing authorized delivery controls, each gate preserved |
| Never implied | Apply approval labels, assign an agent, alter issue authority, expand scope, skip checks/review/XXL gates, bypass queue, retarget release/deployment, or perform destructive rollback |

The eventual implementation spec must enumerate exact write APIs and gate
owners. This document adds none.

## Lifecycle and Non-Success Outcomes

| State | Exit evidence / behavior |
| --- | --- |
| Prepared | Scope, exact identities, dependencies, target, acceptance, authority, and budgets recorded; no execution consent inferred |
| Authorized | Existing qualified live delivery evidence matches source and scope |
| Executing | Only in-scope actions; record boundary evidence and any in-flight effect |
| Verified | Required acceptance evidence is fresh for the exact target and artifact |
| Blocked / partial | Record completed boundaries, blocker, unexamined scope, and checkpoint; never label as delivered |
| Stopped / cancelled | No new effects after the stop; preserve state and report irreversible/in-flight effects |
| Resumed | Re-read current authority, scope/spec, dependencies, head, target, checks, and budget before acting |

Stop on revoked or stale authority, changed source/spec/dependency, failed or
missing required check, target mismatch, permission loss, explicit hold/stop,
or exhausted budget. Rollback is not implied; use only separately authorized
recovery. Resume invalidates evidence affected by changed identity.

## Future Parser and Behavior Fixture Plan

These fixtures are required only if a distinct route is separately approved.

| Case | Expected future behavior |
| --- | --- |
| Standalone candidate with fully qualified current delivery authority | Route only if explicitly registered; compose existing controls |
| Candidate without authority, with issue approval only, or with caller-supplied receipt | Reject before side effects |
| Quoted, fenced, bulleted, or embedded candidate; conflicting/dual prefix | Do not execute or reject as ambiguous |
| `later`, `read-only`, `no changes`, explicit stop/defer | No delivery effects |
| Revoked receipt, changed scope/spec, blocked dependency, missing/failed checks | Stop before next boundary; retain checkpoint |
| Wrong release/deployment target, stale evidence, failed production verification | Do not claim completion; report target-specific blocker |
| Partial action with exhausted budget | Preserve completed/in-flight effects and resume evidence; no success-shaped fallback |
| Request for out-of-scope implementation or destructive rollback | Reject; require separate approved authority |

## Distribution, Migration, and Rollout Gates

Keep existing `ship-it:` / `spec-2-prod:` authoritative unless a distinct
contract is approved. An implementation must extend the actual parser fixture
suite, use existing receipt validation and gate owners, document every read
and write, map canonical instructions/skill/workflow behavior, and update
consumer projections and migration examples. No dual-prefix alias or
automatic source migration. Test fail-closed holds, stale identity,
revocation, partial completion, exact-target verification, and recovery before
any rollout. Proposal publication itself has no runtime migration.

## Proposal Acceptance Criteria

- [x] Inputs, authority, exact scope, target, evidence identity/freshness, and
  completion evidence are explicit.
- [x] Read/write and prohibited effects preserve existing delivery governance.
- [x] Blocked, partial, stop, cancellation, and resume behavior are explicit.
- [x] Positive and negative parser cases and distribution/rollout gates are
  defined without registering the candidate.

## References

- PRD:
  [`docs/prd/synthesized/issue-3630-designintent-define-deliver-completion-and-authorization-con.prd.md`](../../prd/synthesized/issue-3630-designintent-define-deliver-completion-and-authorization-con.prd.md)
- Comparison: [`docs/design/ai-sdlc-work-units.md`](../../design/ai-sdlc-work-units.md)
- Existing delivery trace: [`docs/guides/spec-to-production.md`](../../guides/spec-to-production.md)
- Shared contract summary: [`docs/reference/intent-work-unit-contracts.md`](../../reference/intent-work-unit-contracts.md#deliver-delivery)
- Source proposal: #3630
