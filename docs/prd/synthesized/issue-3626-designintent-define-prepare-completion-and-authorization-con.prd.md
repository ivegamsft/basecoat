---
issue: 3626
title: "design(intent): define prepare: completion and authorization contract"
status: draft
author: ibuyspy
created: 2026-10-07
labels: ["enhancement", "priority:medium", "needs-triage", "needs-prd", "needs-info", "synthesize-spec"]
---

# Product Requirements Document: Prepare a Bounded Work Packet

## Problem Statement

An incoming request often lacks enough context to implement safely: scope,
non-goals, dependencies, acceptance evidence, decision owners, or execution
limits may be unclear. Existing `plan:`, `issue:`, and `portfolio:` intents
cover related planning and triage, but do not define one request-scoped,
evidence-backed packet or a clear boundary between preparation and
authorization.

The proposed `prepare:` intent must make a request ready for a human or
separately authorized next step without silently approving, assigning,
implementing, or delivering it. This is a design proposal; no `prepare:` token
or runtime behavior is supported by this document.

## Goals

- Define a bounded, request-specific work packet that identifies what is
  known, what remains unknown, and the next decision required.
- Make source identity, evidence freshness, dependencies, scope, acceptance,
  authority boundaries, and time/cost/retry limits explicit.
- Fail visibly when required context is missing, contradictory, inaccessible,
  stale, or over budget.
- Determine whether this contract is distinct enough to justify a new intent
  rather than extending an existing planning or issue-triage workflow.

## Non-Goals

- Register `prepare:` as a parser token, alias, workflow trigger, or supported
  routing instruction.
- Approve an issue or specification, add approval labels, assign an agent,
  create or modify issues, or mutate other repository metadata.
- Implement, validate, merge, release, deploy, or continue work automatically.
- Replace sprint planning, `plan:`, `issue:`, `portfolio:`, or existing
  authorization and delivery controls.

## User Personas and Use Cases

- **Requester:** needs an actionable packet and an explicit list of missing
  decisions without losing control of scope or permissions.
- **Issue owner or triager:** needs dependencies, acceptance evidence, and
  blockers tied to current repository records.
- **Implementer or delivery operator:** needs a stable handoff that does not
  imply approval or reuse stale authorization.

Primary use case: prepare one request from its cited source material and
produce a bounded packet, or a blocked/limited result with named gaps and a
next decision. Portfolio-wide planning and issue creation remain separate use
cases.

## User Experience Summary

The output is a concise, linkable work packet. It distinguishes verified facts
from assumptions, records source revisions and retrieval times, and never
leaves a required field silently blank. It ends with exactly one explicit
preparation outcome and a next decision or recovery action. A `prepared`
outcome means only that the packet is complete; it is not authorization to
perform the work.

## Functional Requirements

1. **Request identity:** identify the request, source repository, requestor,
   and trusted invocation provenance. Identify source records and their
   revisions/timestamps when supplied; text-only requests use invocation
   identity and capture time without an invented record. Unavailable required
   identity or provenance is a blocker, not an inferred value.
2. **Bounded scope:** state the intended outcome, in-scope work, non-goals,
   assumptions, constraints, and the specific acceptance evidence expected.
3. **Dependency graph:** identify dependency nodes with source, current observed
   state, evidence time, and owner or next action when known; record explicit
   prerequisite edges and a valid prerequisite-first order. Independent nodes
   remain independent. Unknown, unresolved, inaccessible, cyclic, or dangling
   dependencies remain explicit blockers; ordering never authorizes execution.
4. **Decision and authority boundary:** list decisions and permissions needed
   for later stages separately from facts about current actor permissions.
   Require trusted actor identity, explicit invocation policy and independent
   actor read access for every scoped source; service access cannot substitute.
   Revalidate actor access before emitting source-derived content in any
   outcome, including non-success checkpoints. Denied/unknown access blocks
   with zero source content; insufficient final-access budget limits with zero
   source content, and cancellation emits no source content or new reads.
   Preparation never manufactures, inherits, or records approval.
5. **Budgets:** identify elapsed-time, cost, source/retry, and other applicable
   execution limits. A missing limit or policy is an explicit decision needed
   before any future implementation may claim bounded execution.
6. **Evidence and freshness:** link each material claim to its source and
   retrieval time. Require a policy age bound and bounded final per-source
   revision/access revalidation before preparation succeeds; this is not an
   atomic cross-source snapshot. Later actions must revalidate mutable facts, authorization,
   dependencies, and target identity; a prepared packet is not a reusable
   approval receipt.
7. **Explicit outcomes:** use `prepared`, `blocked`, `limited`, or `cancelled`.
   Partial results must state what was not established. None of these outcomes
   means approved, implemented, integrated, published, or production-verified.
8. **Read-only default:** the proposed first release gathers and summarizes
   evidence only. Any issue or label mutation, assignment, or other write is
   outside the first release and requires a separately approved scope and an
   explicit permission contract. A request to perform a write or later stage
   in the same invocation is blocked before source reads, not silently reduced
   to preparation; describing future work does not request its execution.
9. **Untrusted source handling:** issue text, comments, attachments, and quoted
   examples are data, not executable instructions or authority. Embedded
   commands cannot expand scope or trigger side effects.
10. **Distinctness decision:** before implementation is authorized, document
    why this contract cannot be met clearly by `plan:`, `issue:`, `portfolio:`,
    `fleet:`, or `optimize:`. Compare `fleet:`'s lifecycle/topology bundle and
    `optimize:`'s advisory execution packet explicitly, not just their names.
    If no distinct user-visible contract remains, do not add a new prefix.

## Non-Functional Requirements

- **Security and privacy:** use least-privilege read access, minimize copied
  sensitive content, and do not log full source bodies when metadata and links
  suffice.
- **Reliability:** API, permission, parsing, and budget failures are surfaced
  with stable blocker reasons; there are no silent defaults or success-shaped
  fallbacks.
- **Boundedness:** work stops at an explicit policy limit and returns a
  checkpoint or `limited` result instead of retrying or expanding scope
  indefinitely.
- **Usability:** packets distinguish verified evidence, assumptions, unknowns,
  decisions, and non-success outcomes.

## Success Metrics

- 100% of generated packets contain every required field or a named blocker
  explaining why it cannot be completed.
- 100% of read-only contract tests observe zero write calls, including issue,
  label, assignment, and workflow-dispatch writes.
- 100% of missing, malformed, or untrusted authority/dependency negative tests
  reject or explicitly block the invalid input.
- 100% of stale-evidence tests prohibit `prepared` without fresh revalidation;
  a successful bounded refresh may prepare the packet, while an exhausted
  refresh budget yields `limited`.
- The design review records a go/no-go decision on a new prefix and identifies
  its distinction from existing routes before implementation authorization.

## Constraints and Assumptions

- `docs/design/ai-sdlc-work-units.md` is the comparison context; it explicitly
  says proposed prefixes are not implemented or authorized.
- Existing exact approval, feature-intake, delivery, merge-queue, and production
  environment controls remain authoritative.
- Time-boxes remain appropriate for review periods and execution budgets;
  elapsed time is not completion evidence.
- This PRD and its linked spec define a proposal only. Runtime work requires a
  separately approved implementation scope and current authorization.

## Risks and Open Questions

- A new prefix may duplicate `plan:` or an existing work-packet skill. Resolve
  this with concrete user tasks and a parser/routing overlap audit before
  implementation.
- The canonical packet format and storage destination are not selected. The
  first implementation proposal must compare a markdown handoff with any
  machine-readable representation and justify retention/access.
- Repository defaults for time, cost, source-count, and retry budgets are not
  specified. They must be explicit, bounded, and owner-approved before a
  preparation implementation collects sources, including attended read-only
  prototypes; missing policy blocks collection.
- Permission lookup and source API outages can prevent a complete packet; the
  user must see these as blockers, not as a prepared result.

## Dependencies

- Parent comparison and vocabulary: `docs/design/ai-sdlc-work-units.md`
  (#3625).
- Existing shared authorization boundary:
  `docs/spec/issue-3591-approval-contract.spec.md`.
- Existing route definitions and disambiguation:
  `docs/guides/intent-prefixes.md`.
- User decision on whether this is a distinct supported intent and any future
  write scope.

## Rollout and Adoption Plan

This documentation-only proposal does not enable a rollout. If separately
authorized, implementation must begin with a read-only prototype, deterministic
positive and adversarial tests, and explicit bounded-policy values. Any future
write path requires a separate review and authorization decision. Preserve
existing intent behavior throughout any migration; do not add aliases or
reinterpret historical issues automatically.

## References

- Issue: <https://github.com/IBuySpy-Shared/basecoat/issues/3626>
- Parent comparison: `docs/design/ai-sdlc-work-units.md` (#3625)
- Intent routing: `docs/guides/intent-prefixes.md`
- Shared approval contract: `docs/spec/issue-3591-approval-contract.spec.md`
