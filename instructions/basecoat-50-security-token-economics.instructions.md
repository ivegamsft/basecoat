---
description: "Use when selecting models, escalating reasoning cost, or loading context. Enforces cost-aware routing and token budget discipline for all agent work."
applyTo: "**/*"
distribute: false
---

# Token Economics

Use this instruction whenever choosing a model, deciding how much context to load, or escalating to a more expensive tier.

## Model Tier Guidance

- **Premium** (`claude-opus-4.7`, `claude-opus-4.7-high`, `claude-opus-4.6`) — architecture direction, security analysis, compliance, irreversible cross-system decisions
- **Reasoning/Standard** (`claude-sonnet-4.6`, `claude-sonnet-4.5`, `gpt-5.4`, `gpt-5.2`) — code review, test strategy, planning, research
- **Code** (`gpt-5.3-codex`, `gpt-5.2-codex`) — implementation, refactoring, debugging, code generation
- **Fast** (`claude-haiku-4.5`, `gpt-5.4-mini`, `gpt-5-mini`, `gpt-4.1`) — scanning, formatting, status checks, simple transformations

Match model to task complexity. When escalating to premium, state the tradeoff explicitly.

## Context Loading Order

Classify intent **before** loading context. Load in this order — stop when the task is answerable:

1. L2 trigger map match → compute confidence and context completeness
2. **Fast path** (confidence ≥ 0.80 + completeness ≥ 0.70): pattern bundle only
3. **Fast path + targeted load** (confidence ≥ 0.80 + completeness < 0.70): bundle + one L3 snippet
4. **Bundle start + explore** (confidence 0.50–0.79): closest bundle, then explore to resolve ambiguity
5. **Full HRM traversal** (confidence < 0.50 or Novel): L2→L3→L4 in order

Never load broad repository context speculatively. Reuse context already in session.

## Avoid Waste

- Do not re-read files already in context unless the file changed or a missing section is needed
- Do not load entire files when a targeted section or diff is sufficient
- Summarize large context before handing off to a sub-agent
- Prefer the cheapest model tier that can complete the task reliably

## Turn Budget

Classify each task before starting:

| Class | Definition | Soft budget |
|---|---|---|
| **Routine** | Known pattern covered by instructions or memory | ≤ 3 turns |
| **Familiar** | Similar to prior work with new variables | ≤ 5 turns |
| **Novel** | No prior coverage | Estimate N turns; state it upfront |

If stuck past 5 turns with no forward progress: log failure to memory, change approach, do not escalate model first.

If completed within budget with tests passing and a non-obvious pattern: call `store_memory`.

## References

| Topic | File |
|---|---|
| Full HRM context routing matrix, fast path details, escalation queries | [`references/token-economics/context-routing.md`](references/token-economics/context-routing.md) |
| Turn budget classification, failure/success protocols, TRM estimator | [`references/token-economics/turn-budget.md`](references/token-economics/turn-budget.md) |
| Model tier matrix, cost overrides | `docs/MODEL_OPTIMIZATION.md` |
| Context compression, caching, budget patterns | `docs/token-optimization.md` |
