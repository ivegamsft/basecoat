# Hybrid branching strategy feature design, gap analysis, and learnings

**Date:** 2026-06-26
**Parent issues:** #2138, #2139, #2140, #2141, #2142
**Related design track:** #1661-#1669

## Scope

Design a hybrid branching model for AI and agent-based development that combines:

1. Trunk-based delivery speed for day-to-day integration.
2. GitFlow-style control for release and hotfix management.
3. Per-agent lane isolation to reduce CI/CD contention and blast radius.

This document captures design updates only. No implementation is included.

## Current state snapshot (baseline context)

From recent CI/CD snapshots:

1. Delivery speed recovered (high PR throughput and faster merge flow).
2. Reliability has improved from the 2026-06-14 baseline, but remains uneven across workflows.
3. Publish-to-production remains under-observed in the latest sample window and has historically been unstable.
4. Merge lane architecture is designed (#1661) but not yet operationalized.

## Feature set design

| Feature | Design update | Depends on | Downstream impact |
|---|---|---|---|
| Hybrid branch taxonomy | Define `main`, `release/*`, `hotfix/*`, `agent/*`, `feature/*`, `maintenance/*` with explicit transition rules. | #2138, #2139 | Consumer repos can adopt profile-based branch sets instead of one-size-fits-all governance. |
| Two-stage merge flow | Keep lane admission parallel and main finalization serialized. | #1661, #2139 | Reduces queue coupling; preserves auditable integration point on `main`. |
| Agent branch contract | Standardize branch naming, PR metadata, and escalation thresholds for agent-created work. | #1663, #2141 | Improves traceability for AI-created changes in consumer repos. |
| Release and hotfix controls | Add explicit promotion and backport policy for release and emergency paths. | #2139 | Supports controlled releases without slowing trunk integration. |
| Consumer profile guidance | Ship "minimum", "standard", and "strict" adoption profiles. | #2140 | Enables staged rollout based on team maturity and compliance needs. |
| Scorecard and guardrails | Define SLOs, stop/go criteria, and cadence before rollout. | #2142 | Prevents policy changes without measurable improvement evidence. |

## Gap analysis

| Area | Current state | Target state | Gap | Update issue |
|---|---|---|---|---|
| Branch policy | Partial guidance; no unified hybrid policy contract. | One explicit branch policy matrix with allowed transitions and controls. | Missing formal contract and transition matrix. | #2139 |
| Agent workflows | PR-only and lane concepts exist, but branch lifecycle contract is incomplete. | Agent branch lifecycle with deterministic metadata and escalation. | Missing lifecycle, metadata contract, and failure-routing protocol. | #2141 |
| Consumer repos | Existing rollout guidance focuses on sync and governance, not hybrid branching operations. | Consumer-ready adoption profiles and migration runbook. | Missing profile-driven branch guidance and migration checklist. | #2140 |
| Measurement | Point-in-time snapshots exist, but no standardized baseline/control methodology for branch-strategy changes. | Baseline + treatment measurement plan with thresholds and review cadence. | Missing controlled experiment design and stop/go policy. | #2142 |
| Cross-feature dependency map | Dependencies are implied across #1661-#1669 and #2138-#2142. | Explicit dependency graph and rollout sequence. | Missing sequencing contract for design-to-implementation handoff. | #2138 |

## Learnings log

1. **Velocity can hide governance drift.** Throughput improvements are not enough without branch and gate health signals.
2. **Lane design without branch policy is incomplete.** Per-agent lanes need explicit source/target transition rules.
3. **Agent autonomy needs strict metadata contracts.** Without structured PR metadata, auditability collapses under scale.
4. **Release controls must be explicit and separate.** Trunk optimization and release safety should be tuned independently.
5. **Consumer repos require profile-based guidance.** A single enterprise policy is too heavy for many downstream teams.
6. **Measurement must be designed before rollout.** Post-change snapshots alone cannot prove causal improvement.
7. **Dependency mapping is a first-class deliverable.** Parallel design issues create ambiguity unless sequencing is explicit.

## Design-phase plan (no implementation)

### Phase 1: Debate consolidation

1. Resolve open decisions in #2138 using the issue design template.
2. Confirm branch classes and transition constraints.
3. Agree default policy profile for BaseCoat and downstream profile variants.

### Phase 2: Contract authoring

1. Finalize branch policy matrix in #2139.
2. Finalize agent branch lifecycle and PR metadata contract in #2141.
3. Finalize consumer migration guidance and profile pack in #2140.

### Phase 3: Measurement readiness

1. Lock baseline and treatment metrics in #2142.
2. Publish stop/go thresholds and rollback triggers.
3. Define review cadence and owners.

### Phase 4: Implementation handoff package

1. Open implementation issues mapped 1:1 to approved design decisions.
2. Include dependency order and expected impact per issue.
3. Require each implementation PR to link back to the design issue it satisfies.

## Dependency and impact matrix

| Dependency | Why it matters | If delayed | Impact class |
|---|---|---|---|
| #1661 lane scheduler/finalizer design | Core non-blocking merge architecture. | Hybrid policy lacks execution model. | Critical |
| #1666 CI preflight/guardrails | Reliable gate surface before branch-policy tightening. | Increased false negatives/positives during rollout. | High |
| #1665 local/cloud test routing | Keeps branch policy changes from inflating CI costs. | Slower feedback and higher queue contention. | High |
| #2140 consumer guidance | Enables safe external adoption. | Internal-only strategy with low downstream reuse. | Medium |
| #2142 scorecard/SLOs | Proves effectiveness and controls rollback. | Changes proceed without measurable confidence. | Critical |
