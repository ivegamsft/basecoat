---
issue: 3118
title: "Governance enhancement: durable per-task provenance/evidence trail to complement point-in-time audits"
status: draft
author: ibuyspy
created: 2026-09-08
labels: ["enhancement", "governance", "priority:low", "needs-triage", "synthesize-spec"]
---

# Spec: Governance enhancement: durable per-task provenance/evidence trail to complement point-in-time audits

## Problem Statement

**Gap (vs HVE):** HVE persists a durable per-task evidence trail (`.copilot-tracking` research/plans/details/changes/reviews with stable IDs) — 'file-based tracking takes precedence over memory'. basecoat auditability is mostly point-in-time posture scans (`*-audit` skills) + memory.

**Proposal:** Standardize an optional durable evidence trail per work item (research/plan/changes/review) to give continuous, replayable governance provenance.

**Existing partial coverage:** `memory-index`, audit reports under `reports/`.

Parent: #3113

## Why This Matters

*Not specified.*

## Scope

*Not specified.*

## Acceptance Criteria

- [ ] Implementation matches the scope defined above.
- [ ] Validation commands pass with no errors.
- [ ] PR references this spec.

## References

- PRD: `docs/prd/synthesized/issue-3118-governance-enhancement-durable-per-task-provenanceevidence-t.prd.md`
- Refs #3118
- Issue: <https://github.com/IBuySpy-Shared/basecoat/issues/3118>
