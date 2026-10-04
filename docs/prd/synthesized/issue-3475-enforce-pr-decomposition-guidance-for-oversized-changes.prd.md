---
issue: 3475
title: "Enforce PR decomposition guidance for oversized changes"
status: draft
author: ibuyspy
created: 2026-10-04
labels: ["enhancement", "priority:medium", "sprint:2026-W40"]
---

# PRD: Enforce PR decomposition guidance for oversized changes

## Problem and Outcome

The batch guideline in `instructions/basecoat-20-lang-governance.instructions.md`
is advisory: automatic size labels measure lines, not batch decomposition.
Require agents to plan and deliver reviewable batches without turning the
15-file/300-line batch guideline into a universal limit on individual features.

## Scope

- Planner-time classification and split decisions for independently deliverable
  changes bundled together; PR-time verification using authoritative GitHub counts.
- Block oversized batches unless a qualified human approves a narrow,
  reproducible mechanical exception with validation and rollback evidence.
- Reuse `BaseCoat merge eligibility` in the existing merge executor; preserve
  deterministic size labeling, all other checks, and the XXL human approval gate.
- Exclude runtime implementation from this design PR, universal feature caps,
  relaxed approval rules, and unrelated labeling or deployment changes.

## Success Criteria

- Batches with at most 15 files AND 300 additions plus deletions pass this gate;
  exceeding either boundary requires a split or the documented exception.
- Individual cohesive features are classified and auditable but are not blocked
  solely for exceeding the batch thresholds.
- Mechanical evidence cannot be asserted by an agent to bypass human review;
  missing counts, classification, or stale evidence cannot authorize merging.
- Existing line-label boundaries, including XXL above 2,000 lines, are unchanged.
- Exact boundary, revocation, failure, and security tests in the spec pass before
  enabling enforcement.

## Delivery and Risk

Pilot in reporting mode, then enforce in the existing executor and planner.
Rollback the new decomposition predicate only; retain all current merge controls.
Primary risk is misclassifying cohesive features as batches; report the decision
and source issue inventory so reviewers can correct it before enforcement.

## References

- Spec: [implementation contract](../../spec/synthesized/issue-3475-enforce-pr-decomposition-guidance-for-oversized-changes.spec.md)
- Governance: `docs/reference/governance-contract.md`
- Refs #3475
- Issue: <https://github.com/IBuySpy-Shared/basecoat/issues/3475>
