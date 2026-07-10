# Memory Index — Algorithms Reference

## Promotion Ladder Algorithm

```text
heat_score(t) = Σ(access_weight_i × recency_decay_i)
  access_weight: read=1, write=2, apply=3
  recency_decay: e^(-0.05 × days_since_access)
```

| heat_score | Action |
|---|---|
| ≥ 8.0 | Promote to L2 (hot index entry) |
| 4.0–7.9 | Stay in current tier |
| < 2.0 | Demote or evict — mark stale |
| = 0 (unread 90 days) | Evict from tier |

## TRM Two-Pass Classification

**Pass 1 (fast):** Keyword match against pattern bundle catalog (L2). Assigns intent label
and initial confidence score. If confidence ≥ 0.85: take fast path immediately.

**Pass 2 (slow):** Semantic re-scoring of Pass 1 classification using full task context.
Applies adjustments:

- If Pass 1 and Pass 2 disagree on intent AND confidence gap > 0.20:
  apply -0.10 penalty; route to full path if penalized score < 0.50
- Apply -0.10 discount to matches from L2s (shared org index) vs L2 (repo-local)

## EscalationQuery Contract

```text
EscalationQuery {
  intent:                   string       // classified intent label
  keywords:                 string[]     // matched trigger keywords
  confidence:               float        // current TRM confidence score [0.00, 1.00]
  context_budget_remaining: int          // tokens remaining in session budget
  originating_layer:        L0 | L1 | L2 | L3 | L4
  reason:                   string       // why fast path was not taken
}
```

Receiving layer responds with a `GuidanceSignal`:
`STAY_FAST_PATH` | `EXPAND_CONTEXT` | `ELEVATE_TO_L3` | `ELEVATE_TO_L4` |
`TURN_BUDGET_AT_RISK` | `ESCALATE_SCOPE` | `CONFIDENCE_DRIFT`

See `instructions/basecoat-10-core-hrm-execution.instructions.md` for signal definitions.

## Pattern Bundle Confidence Update Formula

```text
confidence(t) = confidence(t-1) + η × (outcome(t) - confidence(t-1))
  η = 0.05 (learning rate)
  outcome: 1.0 = success, 0.0 = failure
  bounds: [0.50, 0.99]
```

**Quarterly drift review:** Flag bundles where `|confidence(t) - authored_value| > 0.15`.
Bundles marked `[pin]` are exempt from confidence decay.

## TRM Progress Estimator

```text
estimate(t) = estimate(t-1) × 0.7 + observation(t) × 0.3
```

Where `observation(t)` = fraction of task checklist items completed this turn.
Checkpoint fires when `estimate.progress / estimate.turns_remaining < 0.6`.

If TRM overhead would exceed 15% of remaining context budget, skip Pass 2, accept Pass 1 result.
