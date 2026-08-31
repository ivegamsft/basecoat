# ADR-002: Agent Model Shifting and Cost Governance

**Date:** 2026-06-21

**Status:** Proposed

**Related issue:** [#1664](https://github.com/ivegamsft/basecoat/issues/1664)

---

## Context

BaseCoat agents do not have uniform reasoning demand. Some workflows are
deterministic and cost-sensitive, while others are high-risk and require
stronger reasoning models.

Issue #1664 highlighted three unresolved governance questions:

1. How agents should declare preferred vs fallback models
2. Who decides when to upshift from default
3. How cost should be tracked per agent

Current guidance defines fallback-capable policies but does not consistently
define upshift ownership or a standard spend-attribution contract.

## Decision

We standardize model governance around a capability-first `model_policy`
contract for agents and skills.

### 1. Preferred vs fallback declaration

- Assets should define:
  - `model_policy.fallback: true`
  - `model_policy.preferred_families: [...]`
- Keep `pinned_model` only for reproducibility/compliance constraints, with
  required `pin_reason`.
- Legacy `model` fields remain valid during migration but should not be the
  long-term source of routing truth.

### 2. Upshift decision ownership

- Assets that allow dynamic model shifts should declare:
  - `model_policy.upshift.allowed`
  - `model_policy.upshift.owner`
  - `model_policy.upshift.max_tier`
  - `model_policy.upshift.triggers`
- Default owner is `runtime` for deterministic rule-based shifts.
- `orchestrator` ownership is used when cross-agent dependency context is
  required.
- `human` ownership is reserved for regulated workflows where explicit approval
  is required before a higher-cost tier can be used.

### 3. Per-agent cost tracking

- Production workflows should declare:
  - `model_policy.cost_tracking.budget_tier`
  - `model_policy.cost_tracking.chargeback_tag`
- Telemetry events for agent sessions should include:
  - `agent_name`
  - `selected_model`
  - `shift_reason` (if upshift happened)
  - `input_tokens`
  - `output_tokens`
  - `estimated_cost_usd`
  - `chargeback_tag`

This enables per-agent cost accounting without forcing rigid model pinning.

## Consequences

### Positive

- Model shifts become explicit, reviewable, and auditable.
- Upshift behavior is deterministic and not hidden in prompt prose.
- Cost attribution can be aggregated by workflow/team via chargeback tags.
- Guidance aligns with capability-first migration already documented in
  BaseCoat instructions.

### Negative

- Authoring metadata becomes more verbose.
- Existing assets may require gradual metadata backfill to realize full value.

### Risks

- Inconsistent trigger semantics across teams can cause routing drift.
  Mitigation: keep trigger vocabulary constrained
  (`complexity`, `safety_risk`, `repeated_failures`, `low_confidence`).

## Rollout

1. Update authoring guidance and templates (this change).
2. Apply policy to new/updated assets first; avoid bulk rewrites.
3. Add telemetry mapping in runtime/orchestration implementations as follow-up
   implementation issues.
4. Review `model_policy` adoption in quarterly governance audits.

## Alternatives Considered

### A. Pin all agents to one model

Rejected. This blocks cost optimization and ignores role-specific cognitive
demand.

### B. Leave upshift logic implicit in agent prose

Rejected. Hidden routing logic is difficult to audit and hard to validate
consistently.

### C. Track only global token spend

Rejected. Global spend cannot explain which agent/workflow is driving cost.
