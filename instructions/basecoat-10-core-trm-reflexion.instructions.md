---
description: "TRM (Tiny Recursive Model) Reflexion loop for intent classification and turn budget estimation. Apply whenever classifying task intent or tracking progress against a turn budget."
applyTo: "**/*"
---

# TRM Reflexion — Intent Classification & Progress Tracking

TRM (Tiny Recursive Model) is a lightweight recursive refinement pattern that improves
intent classification accuracy and turn-budget estimation without requiring a model tier
escalation. It runs within the existing context budget using a bounded pass structure.

See `docs/research/TRM-HRM-investigation.md` for full rationale and parameter calibration.

## When to Apply

Apply TRM at two points in every task:

1. **Session start** — classify intent (fast path vs full path vs novel)
2. **Each turn** — update progress estimate and check against turn budget

TRM does NOT add a separate reasoning step; it refines the classification already being
made, using prior pass output as additional context.

## Intent Classification Loop

### Pass 1 — L2 Trigger Match

Match the user's request against the L2 trigger map in `memory-index.instructions.md`.
Compute an initial confidence score (0.0–1.0) based on keyword overlap and bundle match.

**Converge immediately (skip Pass 2) if:**

- Confidence ≥ 0.80 → route to fast path, load pattern bundle
- Confidence ≤ 0.30 → route to full path (novel or ambiguous)

### Pass 2 — L3 Refinement (0.30–0.79 band only)

Retrieve a targeted L3 snippet: last N=3 session turns on the matched topic using the
episodic SQL queries in `memory-index.instructions.md`. Re-evaluate confidence given
prior session context.

**Pass 2 constraints:**

| Parameter | Value | Reason |
|---|---|---|
| Max confidence boost | +0.15 | Prevents L3 noise from overriding strong L2 signal |
| Disagreement penalty | -0.10 | Applied when Pass 1 and Pass 2 differ AND gap > 0.20 |
| L2s discount | -0.10 | Shared org index entries are not repo-calibrated |
| Budget guard | Skip Pass 2 if TRM overhead > 15% of remaining context | Avoids recursive cost spiral |

**After Pass 2:**

- Penalized score ≥ 0.50 → fast path (with lower confidence note)
- Penalized score < 0.50 → full path

### Self-Consistency Cap (k=3)

When updating **pattern bundle confidence** (not intent routing), use self-consistency
scoring at k=3: take three independent session outcome samples and return the majority
result. Do not exceed k=3 — marginal accuracy gain beyond k=3 is negligible, and token
cost scales linearly.

```text
confidence_update = majority_vote(outcome[t-1], outcome[t-2], outcome[t-3])
```

## Progress Tracking Estimator

Update the progress estimate at the end of every turn:

```text
estimate(t) = estimate(t-1) × 0.7 + observation(t) × 0.3
```

Where `observation(t)` is the fraction of task checklist items completed this turn
(0.0 = none, 1.0 = all remaining items done).

**Early-warning checkpoint:** fires when

```text
estimate.progress / estimate.turns_remaining < 0.6
```

When the checkpoint fires: pause, reassess scope, and explicitly state remaining
blockers before continuing.

## Convergence Signals

| Signal | Condition | Action |
|---|---|---|
| Fast converge | confidence ≥ 0.80 after Pass 1 | Load pattern bundle; skip Pass 2 |
| Forced converge | k=3 reached | Accept Pass 3 result regardless of confidence |
| Budget guard | TRM overhead > 15% of remaining context | Accept Pass 1 result directly |
| Failure signal | 5 turns with no measurable progress | Log to `store_memory`, change approach |

## Reflexion — Verbal Failure Signal

When the failure signal fires (stuck after 5 turns), generate a structured reflection:

```text
REFLEXION {
  task: <one-line description>
  approach_tried: <what was attempted>
  failure_mode: <why it did not work>
  blocking_signal: <the specific error or missing piece>
  next_approach: <different strategy to try>
}
```

Store this reflection to `store_memory` with subject `failure-protocol`. The reflection
is injected into the next pass's context — this is the TRM recursive signal.

Do **not** escalate the model tier as the first response to a failure. Change the
approach first; escalate only if a different approach also fails.

## Integration with HRM Tier Resolution

TRM operates **within** each HRM tier — it is the reasoning engine that decides whether
a tier's result is sufficient to converge, or whether escalation to the next tier is
needed.

```
L2 → TRM Pass 1+2 → confidence ≥ 0.80 → CONVERGE (stay at L2)
                   → confidence < 0.50 → ELEVATE to L3
L3 → TRM Pass 1 → hit → CONVERGE (stay at L3)
              → miss → ELEVATE to L4
L4 → TRM Pass 1 → coverage found → CONVERGE
              → no coverage → GENERATE + store_memory
```

Log `ELEVATE_TO_L3` and `ELEVATE_TO_L4` escalation events to `store_memory` when they
represent patterns not already indexed.

## Review Lens

- Was intent classified before loading context? (classify first, load second)
- Did Pass 2 fire only in the 0.30–0.79 band?
- Was k capped at 3 for self-consistency scoring?
- Was the progress estimator updated each turn?
- When stuck after 5 turns, was a REFLEXION block generated and stored?
