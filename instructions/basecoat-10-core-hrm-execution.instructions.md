---
description: "HRM Phase 2 — Formal layer contracts, two-dimensional routing matrix, guidance signals, and agent decomposition scope rules for the BaseCoat execution hierarchy."
applyTo: "**/*"
distribute: false
---

## HRM Execution — Formal Layer Contracts

> This file defines the Hierarchical Reasoning Model (HRM) execution contract for BaseCoat.
> It implements the HRM Phase 2 adoption path from `docs/research/TRM-HRM-investigation.md`.
> TRM intent classification details are in `instructions/trm-reflexion.instructions.md`.

---

## L0–L4 Scope Table

Each memory tier operates as one HRM layer with defined scope. A layer resolves within its
scope or emits an `EscalationSignal` to the next tier. It must **never** read the next
tier's data before attempting local resolution.

| Layer | Role | Input | Output | Scope Constraint |
|-------|------|-------|--------|-----------------|
| **L0** | Reflex | Agent invocation signal | Hard rules, always-on context | Cannot escalate — resolves or ignores |
| **L1** | Procedural | File-glob match + L0 output | Scoped instructions for matched context | Resolves within glob scope; escalates if not covered |
| **L2** | Routing | Task description + L1 output | Intent + pattern bundle, or EscalationSignal | Resolves if confidence ≥ 0.80; escalates to L3 otherwise |
| **L3** | Episodic | EscalationSignal + query | Prior session context relevant to task | Resolves if prior session covers the task; escalates for novel patterns |
| **L4** | Semantic | Novel task + L3 miss | Long-term fact or architecture guidance | Resolves or returns "no coverage — generate and store" |

---

## EscalationQuery Type

When a layer escalates, it must pass a well-formed `EscalationQuery` to the next tier:

```text
EscalationQuery:
  intent:                   string       — matched bundle name or "novel"
  keywords:                 string[]     — top 3–5 task keywords
  confidence:               float        — confidence score at point of escalation (0.0–1.0)
  context_budget_remaining: int          — estimated tokens remaining in current turn
  originating_layer:        L0|L1|L2|L3 — layer that generated this escalation
  reason:                   string       — one-sentence reason for escalation
```

A layer that receives an `EscalationQuery` uses `intent` + `keywords` for retrieval,
not a free-form search, ensuring precise and auditable cross-layer queries.

Cross-layer dependency notation: when an L2 routing rule depends on an L4 fact, annotate
the rule with `[depends: <subject>@<fact-key>]` so stale dependencies can be detected.

---

## Two-Dimensional Routing Matrix

Route decisions combine **confidence** (from TRM Pass 1/2) with **context completeness**
(fraction of task's required input contracts already in context).

| Confidence | Context Completeness | Route |
|---|---|---|
| ≥ 0.80 | ≥ 0.70 | **Fast path** — execute from pattern bundle |
| ≥ 0.80 | < 0.70 | **Fast path + targeted load** — load missing context before executing |
| 0.50–0.79 | Any | **Explore** — bundle start + targeted L3 retrieval |
| < 0.50 | Any | **Full HRM traversal** — L2 → L3 → L4 |

**Context completeness** is satisfied when: required files are already in context AND the
task's key facts (schema, API contract, etc.) have been resolved at or above L2.

---

## Guidance Signals

Emit one of these signals at each routing decision point. Signals in bold must be logged
via `store_memory` as provisional facts for human review.

| Signal | Meaning | Triggered By |
|--------|---------|--------------|
| `STAY_FAST_PATH` | Confidence high, context complete | TRM Pass 1 ≥ 0.80, completeness ≥ 0.70 |
| `EXPAND_CONTEXT` | Confidence high but context incomplete | Fast path blocked by missing input contract |
| `ELEVATE_TO_L3` | Classification uncertain; prior session may help | TRM fails to converge in Pass 2 |
| **`ELEVATE_TO_L4`** | Novel task; no session coverage | L3 retrieval returns empty |
| **`TURN_BUDGET_AT_RISK`** | Progress/turns ratio below threshold | TRM budget estimator fires checkpoint |
| **`ESCALATE_SCOPE`** | Sub-task discovered cross-scope implication | HRM scope-check fails |
| **`CONFIDENCE_DRIFT`** | Bundle confidence changed > 0.15 from baseline | TRM pattern bundle update |

---

## Agent Task Decomposition Scope Table

Each level of the sprint → sub-task hierarchy has a defined scope. A level that discovers
a concern outside its scope must emit `ESCALATE_SCOPE` rather than resolve it inline.

| Level | Scope | Can Resolve | Must Escalate |
|-------|-------|------------|---------------|
| Sprint goal | Business objective | Goal acceptance criteria, wave sequencing | Implementation decisions |
| Wave | Dependency cluster | Issue grouping, wave ordering | Task-level estimates |
| Issue | Feature or bug | Acceptance criteria, agent assignment | Code-level decisions |
| Task | Code change unit | File scope, implementation approach | Cross-file side effects |
| Sub-task | Single edit | The edit itself | Architectural implications |

**Scope-check protocol**: Before acting at any level, confirm: "Does this action fall
within this level's scope?" If not, emit `ESCALATE_SCOPE` and surface it to the caller
before proceeding.

---

## Cross-Layer Dependency Notation

When an L2 routing rule or L1 instruction depends on an L4 long-term fact:

```text
<!-- [depends: token-economics@turn-budget] -->
<!-- [depends: hrm-execution@fast-path-threshold] -->
```

When `store_memory` updates an L4 fact, search L2 entries for matching `[depends: ...]`
tags and flag them for human review. This prevents stale L2 rules from persisting after
underlying facts change.

---

## Token Budget by Route

| Route | HRM Layers | TRM Passes | Estimated Token Cost |
|-------|-----------|-----------|---------------------|
| Fast path (STAY_FAST_PATH) | L2 only | 1 | 450–600 |
| Fast path + targeted load | L2 + targeted file | 1 | 600–900 |
| Explore (bundle + L3) | L2 + L3 | 1–2 | 900–1,200 |
| Full HRM traversal | L2 → L3 → L4 | 2 | 1,500–2,500 |
| Cross-scope escalation | L2 → L3 → L4 + scope check | 2 | 2,000–3,000 |

If the projected route cost would exhaust > 40% of the remaining context budget,
emit `TURN_BUDGET_AT_RISK` before proceeding and confirm scope with the user.

---

## See Also

- `instructions/trm-reflexion.instructions.md` — TRM Pass 1/Pass 2, Reflexion signal, k=3 cap
- `instructions/memory-index.instructions.md` — L0–L4 index structure, EscalationQuery contract
- `instructions/token-economics.instructions.md` — Turn budget taxonomy, 2D routing matrix reference
- `docs/research/TRM-HRM-investigation.md` — Full TRM+HRM investigation and threshold calibration
