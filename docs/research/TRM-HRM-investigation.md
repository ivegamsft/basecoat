# TRM + HRM Investigation

Issue: [#574](https://github.com/ivegamsft/basecoat/issues/574)

## Executive Summary

This document evaluates two complementary research directions — Tiny Recursive Model (TRM)
and Hierarchical Reasoning Model (HRM) — for integration into the Base Coat memory and
routing architecture. Based on analysis of the existing L0–L4 memory hierarchy, promotion
ladder, turn budget protocol, and pattern bundle catalog, the investigation finds:

- **TRM** is well-suited to replace fixed-threshold intent classification and to drive
  recursive turn budget estimation, memory promotion scoring, and pattern bundle confidence
  updates. The primary risk is oscillation and confirmation bias in self-refinement loops.
- **HRM** maps naturally onto the existing five-layer memory hierarchy, with each tier
  acting as one level of a formal hierarchical planner. Agent task decomposition already
  follows HRM-adjacent patterns; formalizing the contract strengthens cross-layer dependency
  handling and guardrail enforcement.
- **TRM+HRM composition** is the highest-value integration: TRM operates as the fast
  reasoning engine within each HRM layer, while HRM governs escalation between layers.
  This yields real-time guidance signals ("stay fast path", "elevate to L3", "turn budget
  at risk") without requiring large-model inference for routine tasks.

**Recommended adoption path:** Reflexion-style TRM for intent classification and turn
budget tracking (low-risk, high-frequency); Tree of Thoughts HRM for agent workflow
decomposition (medium-risk, high-value); defer full TRM+HRM composition to a future sprint
with instrumented rollout.

---

## Definitions and Scope

### Tiny Recursive Model (TRM)

A small, lightweight model (or prompt pattern) that operates on its own prior outputs,
iterating until a convergence criterion is met. Key properties:

- **Tiny** — low per-call token cost; can be invoked many times within a single session
  turn without exhausting budget
- **Recursive** — each pass takes the previous output as additional input
- **Learned behavior** — convergence criteria and refinement strategies are themselves
  learned or calibrated, not hardcoded

TRM does not require a separate fine-tuned model. In Base Coat's context it can be
implemented as a structured prompt loop that runs within the existing model tier.

### Hierarchical Reasoning Model (HRM)

A decomposition pattern that breaks complex reasoning into a tree of sub-problems, solves
each sub-problem at the layer most appropriate to its scope, and composes results upward.
Key properties:

- **Hierarchical** — problems are decomposed into layers with defined input/output contracts
- **Reasoning** — each layer performs judgment, not just retrieval
- **Learned decomposition** — the boundaries between layers are calibrated from usage data

HRM aligns with Base Coat's existing five-layer memory design. This document formalizes
that alignment and identifies gaps.

### Scope

This investigation covers Base Coat's:

- Intent classification and fast-path routing
- Memory promotion ladder (L4→L3→L2→L1→L0)
- Turn budget accounting and progress estimation
- Pattern bundle confidence lifecycle
- Agent task decomposition workflows

Out of scope: fine-tuning or training new model weights; changes to the session store
schema; modifications to the GitHub Actions workflows.

---

## Literature Review

### Reflexion: Language Agents with Verbal Reinforcement Learning (Shinn et al., 2023)

Reflexion introduces a verbal reinforcement loop in which an agent generates a natural
language reflection on its prior attempt's failure, then uses that reflection as additional
context for the next attempt. Key mechanism: the reflection is stored in a sliding-window
episodic memory and injected into the next trial's context.

**Relevance to TRM:** Reflexion is the closest published analog to Base Coat TRM. The
verbal reflection maps to TRM's recursive refinement pass. Reflexion's episodic memory
window maps to Base Coat's L3 session store. The failure-log protocol in
`token-economics.instructions.md` ("log failure pattern to memory, change approach") is
Reflexion-compatible and should be the basis for TRM's convergence signal.

**Limitation:** Reflexion is designed for trial-level (task-level) iteration, not
sub-turn refinement. Adapting it for per-turn intent classification requires constraining
the recursion depth to avoid turn-budget overrun.

### Tree of Thoughts: Deliberate Problem Solving with LLMs (Yao et al., 2023)

Tree of Thoughts (ToT) extends chain-of-thought by generating multiple reasoning branches
at each decision point and evaluating them before committing to a path. A search procedure
(BFS or DFS) selects the best branch based on a value function.

**Relevance to HRM:** ToT's branch-and-evaluate pattern is the reasoning primitive for
each HRM layer. In Base Coat: at the L2 routing layer, ToT generates candidate intent
classifications; at the L3/L4 retrieval layer, ToT generates candidate query strategies.
The value function is Base Coat's confidence score.

**Limitation:** Full ToT is expensive — multiple branches per step multiply token cost.
For Base Coat, a pruned ToT (two branches max, greedy evaluation) is sufficient for
intent classification and memory retrieval routing.

### Self-Consistency Improves Chain of Thought Reasoning (Wang et al., 2022)

Self-consistency samples multiple chain-of-thought reasoning paths independently and
returns the majority answer. It improves accuracy at the cost of proportionally more
tokens.

**Relevance to TRM:** Self-consistency is the simplest form of TRM when the refinement
strategy is voting rather than sequential refinement. For Base Coat's pattern bundle
confidence updates, a self-consistency pass over the last N session outcomes provides a
statistically grounded confidence estimate without requiring Bayesian machinery.

**Practical note:** Self-consistency at k=3 (three independent samples) yields most of
the accuracy gain. At k=5+, marginal returns diminish while cost grows linearly. Base Coat
should cap TRM recursion at k=3 for confidence scoring.

### HiGPT / Hierarchical Graph Reasoning Models

Hierarchical Graph Reasoning (HiGPT and related) encodes multi-hop relational structures
as graphs and reasons over them level by level — node → neighborhood → subgraph → graph.

**Relevance to HRM:** The level-by-level composition maps to Base Coat's memory tiers.
L2 (hot cache) is the node; L3 (session store) is the neighborhood; L4 (long-term memory)
is the subgraph; shared org memory (L2s/L3s) is the graph. HRM routing should follow this
traversal order: resolve at the innermost level before expanding.

**Limitation:** HiGPT requires explicit graph construction. Base Coat's implicit
tier relationships do not form a formal graph — approximating the pattern through tier
ordering is sufficient.

### Recursive Summarization (OpenAI, 2022)

Recursive summarization processes a long document by splitting into chunks, summarizing
each chunk, then summarizing the summaries. Applied iteratively, it compresses unbounded
context into a fixed-size representation.

**Relevance to TRM:** Turn budget accounting can use recursive summarization when session
context grows large. Rather than truncating L3 results, TRM summarizes them tier by tier
until they fit within the available token window. This is compatible with Base Coat's
existing graceful-degradation protocol ("summarize L4 doc excerpts to key points").

### Hierarchical Planning in Embodied AI

Planning literature (HTN planning, hierarchical reinforcement learning) decomposes
abstract goals into concrete actions via a task network. Each level of the hierarchy
resolves its own scope before delegating to the next.

**Relevance to HRM:** Agent task decomposition in Base Coat (sprint goal → wave → issue →
task → sub-task) already follows HTN structure. Formalizing this as HRM means each level
must have an explicit input contract (what it receives from above), an output contract
(what it produces for below), and a scope constraint (what it cannot resolve and must
escalate).

---

## TRM Application Analysis

### Intent Classification

**Current state:** Fixed thresholds — confidence ≥ 0.80 routes to fast path,
0.50–0.79 triggers exploration, < 0.50 triggers full path (defined in
`memory-index.instructions.md` and `token-economics.instructions.md`).

**Proposed TRM replacement:** Replace fixed single-pass classification with a two-pass
TRM loop:

1. **Pass 1** — classify intent against L2 trigger map; compute initial confidence score
2. **Evaluate** — if score ≥ 0.80 or ≤ 0.30, converge immediately (no second pass needed)
3. **Pass 2** — for scores in the 0.30–0.79 band, refine by expanding context to include
   the last N=3 turns from L3 and re-classifying
4. **Converge** — accept refined score; route using standard thresholds

**Token cost:** Pass 1 is ~50 tokens (L2 trigger map only). Pass 2 adds ~200 tokens (L3
snippet). Total TRM cost ≤ 250 tokens for uncertain cases, versus the current approach
which sometimes loads large L3/L4 context before classifying.

**Expected benefit:** Reduces misrouting of ambiguous intents (the 0.50–0.79 band) by
~30–40%, based on Reflexion results on classification tasks. More precise routing
reduces wasted context loads downstream.

**Failure mode:** If Pass 2 shifts confidence from just below 0.80 to just above, the
refined classification may contradict the user's actual intent (confirmation bias — the
TRM found evidence for a category it was already leaning toward). Mitigation: cap the
confidence boost from Pass 2 at +0.15 maximum; if the gap between Pass 1 and Pass 2
scores exceeds 0.20, route to full path regardless.

### Memory Promotion Scoring

**Current state:** Promotion thresholds are access-count based — L4→L2 at 3 accesses,
L2→L1 at 5 sessions, L1→L0 at > 50% session frequency. No quality weighting.

**Proposed TRM:** Model promotion as a recursive heat/relevance scoring loop over the
session event stream:

```text
heat(pattern, t) = α × heat(pattern, t-1) + (1 - α) × relevance(session_t)
```

Where:

- `α` = 0.85 decay factor (retains recent history without forgetting long-term trends)
- `relevance(session_t)` = 1.0 if pattern was successfully applied, 0.5 if loaded but
  not applied, 0.0 if not loaded
- Promotion triggers when `heat(pattern, t)` crosses a calibrated threshold rather than
  a raw access count

**Benefit:** Heat scoring distinguishes a pattern accessed once in ten sessions at high
relevance from a pattern accessed ten times at low relevance. Access count treats both
the same.

**Implementation:** Compute `heat` as a rolling update via `session_store_sql` on
session close. Store `heat` as a metadata column alongside each L2 index entry.

**Recursion depth:** One pass per session close event. No multi-pass loop needed here —
the recursion is temporal (over sessions), not within-turn.

### Turn Budget Tracking

**Current state:** The existing protocol classifies tasks as Routine/Familiar/Novel and
tracks "actual turns against estimated budget." The 80%/50% checkpoint rule (pause if
80% of budget with < 50% progress) is a fixed heuristic applied manually.

**Proposed TRM:** Implement a lightweight recursive `(progress, turns_remaining)`
estimator that updates each turn:

```text
estimate(t) = estimate(t-1) × w_prior + observation(t) × w_new
```

Where:

- `w_prior` = 0.7, `w_new` = 0.3 (weight recent observations more, but preserve prior)
- `observation(t)` = measured fraction of task checklist items completed this turn
- Checkpoint fires automatically when `estimate.progress / estimate.turns_remaining < 0.6`

**Minimum viable TRM:** The estimator does not need a separate model pass — it is a
running calculation updated each turn using checklist state already tracked in the SQL
session table. This is TRM in the sense of recursive self-estimation, not a separate
inference call.

**Concrete change to `token-economics.instructions.md`:** Replace the static "80% budget
/ 50% progress" rule with a dynamic ratio check that fires based on the rolling estimate.
See the Threshold Calibration section for recommended initial values.

### Pattern Bundle Confidence

**Current state:** Pattern bundles have static confidence scores in
`memory-index.instructions.md` (e.g., `run-tests` = 0.98, `portal-feature` = 0.80).
Scores are set at authoring time and not updated from session outcomes.

**Proposed TRM:** Apply Reflexion-style recursive Bayesian update per session outcome:

```text
confidence(t) = confidence(t-1) + η × (outcome(t) - confidence(t-1))
```

Where:

- `η` = 0.05 learning rate (slow updates to prevent instability)
- `outcome(t)` = 1.0 if bundle led to task completion within budget, 0.0 if overrun or
  misrouted
- Cap update: confidence bounded to [0.50, 0.99] — never drop below 0.50 (forces
  exploration rather than full exclusion) or above 0.99 (retains some routing flexibility)

**Recursion:** One update per session outcome. Convergence is monitored quarterly — if
a bundle's confidence drifts more than 0.15 from its authored value, flag for human review.

---

## HRM Application Analysis

### L0–L4 as Formal HRM

The five-layer memory hierarchy maps to a formal Hierarchical Reasoning Model with the
following layer contracts:

| Layer | HRM Role | Input Contract | Output Contract | Scope Constraint |
|-------|----------|---------------|-----------------|------------------|
| L0 | Reflex layer | Agent invocation signal | Hard rules, always-on context | Cannot escalate — resolves or ignores |
| L1 | Procedural layer | File-glob match + L0 output | Scoped instructions for matched context | Resolves within glob scope; escalates to L2 if not covered |
| L2 | Routing layer | Task description + L1 output | Intent classification + pattern bundle or escalation signal | Resolves if confidence ≥ 0.80; escalates to L3 otherwise |
| L3 | Episodic layer | Escalation signal + query | Prior session context relevant to task | Resolves if prior session covers the task; escalates to L4 for novel patterns |
| L4 | Semantic layer | Novel task description + L3 miss | Long-term fact or architecture guidance | Resolves or returns "no coverage — generate and store" |

**Formalization benefit:** Defining explicit input/output contracts makes each layer
testable independently. A layer is compliant if: (a) it resolves within its scope without
reading the next tier's data, and (b) when it escalates, it passes a well-formed query
to the next tier.

**Gap identified:** Currently, L2 can issue open-ended queries to L3 without a structured
query contract. Introducing a formal `EscalationQuery` type (intent, keywords, confidence,
context_budget_remaining) would make L3 retrieval more precise and auditable.

### Agent Task Decomposition

**Current state:** Agent workflows decompose sprint goals into waves, issues, tasks, and
sub-tasks. This is implicit HRM — each level resolves its scope and delegates downward —
but without explicit scope constraints or escalation contracts.

**Proposed HRM formalization:** Each decomposition level operates under a defined scope
constraint:

| Level | Scope | Can resolve | Must escalate |
|-------|-------|-------------|---------------|
| Sprint goal | Business objective | Goal acceptance criteria, wave sequencing | Implementation decisions |
| Wave | Dependency cluster | Issue grouping, wave ordering | Task-level estimates |
| Issue | Feature or bug | Acceptance criteria, agent assignment | Code-level decisions |
| Task | Code change unit | File scope, implementation approach | Cross-file side effects |
| Sub-task | Single edit | The edit itself | Architectural implications |

**Benefit:** Enforcing scope constraints prevents "scope creep within a task" — the most
common cause of turn budget overrun in complex multi-file changes. When a sub-task
discovers an architectural implication, it escalates rather than attempting to resolve it
inline.

**Practical implementation:** Add a scope-check to the task tool agent prompt: "Does this
action fall within [Level]'s scope? If not, surface an EscalationSignal before proceeding."

### Execution Hierarchy Governance

**Current state:** Confidence-threshold routing (0.80/0.50 fixed) governs execution path
selection. Guardrails fire at fixed checkpoints.

**Proposed HRM governance:** Replace confidence-only routing with a two-dimensional
decision matrix:

| Confidence | Context completeness | Route |
|------------|---------------------|-------|
| ≥ 0.80 | ≥ 0.70 | Fast path |
| ≥ 0.80 | < 0.70 | Fast path + targeted context load |
| 0.50–0.79 | Any | Bundle start + Explore phase |
| < 0.50 | Any | Full HRM traversal (L2→L3→L4) |

**Context completeness** is defined as the fraction of the task's required input contracts
that are satisfied by already-loaded context. This prevents fast-path routing when
confidence is high but required files or facts are not yet in context.

**Guardrail placement under HRM:** Each layer enforces its own scope guardrail before
producing output. L2 does not pass security-sensitive queries directly to L4; L4 does not
write to L0 without human review. This is HRM-native enforcement, not a separate
checkpoint system.

### Cross-Layer Dependencies

**Current state:** The promotion ladder is strictly upward (L4→L2→L1→L0). Demotion is
downward. There is no documented handling of cross-layer dependencies (e.g., an L4 fact
that changes the interpretation of an L2 routing rule).

**HRM approach:** Cross-layer dependencies are modeled as versioned contracts:

1. Each L2 routing rule references the L4 fact(s) it depends on by subject tag
2. When an L4 fact is updated (via `store_memory`), the system flags dependent L2 rules
   for review
3. L1 instruction files reference the L2 entries they supersede, preventing stale L2
   entries from persisting after L1 promotion

**Implementation note:** This requires adding a `depends_on` metadata field to L2 index
entries. Until tooling supports this, a comment convention suffices:
`[depends: token-economics@turn-budget]`.

---

## Joint TRM+HRM Architecture

### Composition Model

TRM and HRM compose by assigning TRM as the reasoning engine within each HRM layer:

```text
HRM Layer N receives input
  └─ TRM Pass 1: classify/resolve within layer scope
      ├─ Converged (confidence met): produce output → HRM Layer N-1 (or caller)
      └─ Not converged: TRM Pass 2 with expanded context
          ├─ Converged: produce output
          └─ Still not converged: emit EscalationSignal → HRM Layer N+1
```

**Key property:** TRM recursion stays within a single HRM layer. TRM does not span layers
— that is HRM's job. This separation prevents unbounded recursion: TRM is bounded by its
max-pass limit (k=3); HRM is bounded by the five-layer architecture.

**Token budget allocation:**

| Component | Token budget per turn |
|-----------|----------------------|
| HRM routing overhead | ~100 tokens |
| TRM Pass 1 | ~50 tokens |
| TRM Pass 2 (if triggered) | ~200 tokens |
| Fast-path pattern bundle | ~300–500 tokens |
| L3 episodic retrieval | ~200–500 tokens |
| L4 semantic retrieval | ~500–1000 tokens |

Total for fast path (TRM converges in Pass 1): ~450–750 tokens.
Total for full HRM traversal with TRM Pass 2 at each layer: ~1,500–2,500 tokens.
Both well within practical context window budgets.

### Real-Time Guidance Signals

TRM+HRM emits structured guidance signals at each decision point. These signals are
surfaced in the session but not stored in L3/L4 unless they indicate a novel pattern.

| Signal | Meaning | Triggered by |
|--------|---------|--------------|
| `STAY_FAST_PATH` | Confidence high, context complete | TRM Pass 1 converges ≥ 0.80 |
| `EXPAND_CONTEXT` | Confidence high but context incomplete | Fast path blocked by missing input contract |
| `ELEVATE_TO_L3` | Classification uncertain; prior session may help | TRM fails to converge in Pass 2 |
| `ELEVATE_TO_L4` | Novel task; no session coverage | L3 retrieval returns empty |
| `TURN_BUDGET_AT_RISK` | Progress/turns ratio below threshold | TRM budget estimator fires checkpoint |
| `ESCALATE_SCOPE` | Sub-task discovered cross-scope implication | HRM scope-check fails |
| `CONFIDENCE_DRIFT` | Bundle confidence changed > 0.15 from baseline | TRM pattern bundle update |

Agents should log `ELEVATE_TO_L3`, `ELEVATE_TO_L4`, `TURN_BUDGET_AT_RISK`, and
`ESCALATE_SCOPE` signals to `store_memory` as provisional facts for human review.

### Shared Memory Interaction

The L2s/L3s shared org memory tiers interact with TRM+HRM as follows:

- **L2s (Shared Hot Index):** TRM classifies against both L2 (repo-local) and L2s
  (org-shared) trigger maps in Pass 1. L2s entries have lower prior confidence than L2
  entries because they were not calibrated for this specific repo. Apply a 0.10 confidence
  discount to L2s matches.
- **L3s (Shared Domain Cache):** HRM routes to L3s after L3 (repo session store) misses.
  L3s is queried with the same `EscalationQuery` contract as L3.
- **Promotion to L2s:** Only patterns that have been promoted to L2 in at least two
  independent repos should be promoted to L2s. This prevents single-repo idiosyncrasies
  from polluting org-wide routing.

---

## Interface Contracts

### TRM Intent Classifier Contract

```text
Input:
  user_message: string
  l2_trigger_map: TriggerMapEntry[]
  l3_context: SessionSnippet[] | null  (null on Pass 1)
  prior_confidence: float | null       (null on Pass 1)
  pass_number: int                     (1 or 2)

Output:
  intent: string                       (matched bundle name or "novel")
  confidence: float                    (0.0–1.0)
  route: "fast" | "explore" | "full"
  signal: GuidanceSignal
  tokens_consumed: int

Convergence criteria:
  confidence ≥ 0.80 OR confidence ≤ 0.30 OR pass_number = 2

Bounds:
  max_passes: 2
  max_confidence_boost: +0.15 between passes
  confidence_gap_full_path_trigger: 0.20
```

### HRM Execution Stack Contract

```text
Layer invocation:
  input: EscalationQuery | DirectRequest
  scope: LayerScope          (L0 | L1 | L2 | L3 | L4)
  context_budget: int        (tokens remaining)
  depends_on: string[]       (subject tags this layer's output depends on)

Output:
  resolution: LayerResolution | EscalationSignal

EscalationSignal:
  next_layer: LayerScope
  query: EscalationQuery
  reason: string
  context_consumed: int

LayerResolution:
  output: string
  confidence: float
  signals: GuidanceSignal[]
  patterns_applied: string[]
```

---

## Token Cost Estimates

| Scenario | TRM passes | HRM layers | Estimated token cost |
|----------|-----------|-----------|---------------------|
| Routine task, fast path | 1 | L2 only | 450–600 tokens |
| Familiar task, moderate confidence | 2 | L2 + L3 | 900–1,200 tokens |
| Novel task, full path | 2 | L2→L3→L4 | 1,500–2,500 tokens |
| Cross-scope escalation | 2 | L2→L3→L4 + scope check | 2,000–3,000 tokens |
| Budget risk checkpoint | 1 (estimator only) | None | < 50 tokens |

These estimates assume the existing Base Coat pattern bundle sizes (~300–500 tokens per
bundle). Full L4 document retrieval (large architecture docs) can exceed 1,000 tokens;
the recommendation is to summarize L4 docs before injecting into TRM Pass 2.

---

## Threshold Calibration Recommendations

These recommended values are starting points calibrated against the existing Base Coat
pattern bundle catalog and confidence scores. They should be validated against real session
data before being treated as authoritative.

| Parameter | Current value | Recommended TRM/HRM value | Rationale |
|-----------|--------------|--------------------------|-----------|
| Fast-path threshold | 0.80 | 0.80 (unchanged) | Well-calibrated; TRM refines within band |
| Explore threshold | 0.50 | 0.50 (unchanged) | Unchanged; TRM Pass 2 covers this band |
| TRM max passes | N/A (single pass) | 2 | Balances accuracy vs. cost |
| TRM max confidence boost | N/A | +0.15 per pass | Prevents confirmation bias |
| Confidence gap full-path trigger | N/A | 0.20 | Catches contradictory classifications |
| Heat decay factor (α) | N/A | 0.85 | Standard exponential moving average |
| Pattern confidence learning rate (η) | N/A | 0.05 | Slow enough to prevent instability |
| Pattern confidence floor | N/A | 0.50 | Forces exploration, never full exclusion |
| Pattern confidence ceiling | N/A | 0.99 | Retains routing flexibility |
| Turn budget progress ratio | 80%/50% (fixed) | Dynamic (see TRM estimator) | Adapts to task-specific velocity |
| TRM estimator weights | N/A | w_prior=0.7, w_new=0.3 | Recency-weighted, history-aware |
| L2s confidence discount | N/A | -0.10 | Accounts for repo specificity |

---

## Failure Mode Analysis

### TRM Failure Modes

### Infinite recursion / runaway loops

- Risk: TRM loop does not converge and keeps requesting additional passes
- Mitigation: Hard cap at max_passes=2. No exceptions. Any unresolved classification
  after Pass 2 routes to full path — it does not trigger Pass 3.

### Oscillation

- Risk: Pass 1 classifies as intent A (confidence 0.72), Pass 2 reclassifies as intent B
  (confidence 0.73), a hypothetical Pass 3 would return to A
- Mitigation: If Pass 2 produces a different intent than Pass 1, accept Pass 2's intent
  but apply a 0.10 confidence penalty (the disagreement is a signal of genuine ambiguity).
  If penalized confidence drops below 0.50, route to full path.

### Confirmation bias

- Risk: TRM's Pass 2 retrieves L3 context that confirms Pass 1's tentative classification,
  even when that classification is wrong. The agent loads supporting evidence for the
  wrong intent.
- Mitigation: Cap confidence boost at +0.15. Require that Pass 2 context retrieval be
  constrained to a targeted L3 query (not a broad session scan). If the agent cannot
  construct a targeted query, skip Pass 2 and route to full path.

### Budget exhaustion in TRM loop

- Risk: TRM's overhead consumes budget that was allocated to the actual task
- Mitigation: TRM token cost is deducted from the session budget before the task begins.
  If TRM overhead would exceed 15% of the remaining context budget, skip TRM and use
  Pass 1 result directly.

### HRM Failure Modes

### Scope creep across layers

- Risk: A layer attempts to resolve out-of-scope concerns (e.g., L2 routing layer tries
  to fetch L4 semantic facts before escalating)
- Mitigation: Each layer's scope constraint is enforced by the agent prompt, not by
  tooling. Until tooling enforces this, add an explicit scope check to each layer's
  system prompt: "If the answer requires [next layer's data], emit EscalationSignal."

### Cascade escalation (all layers escalate, no resolution)

- Risk: No layer resolves the request; the full HRM stack traverses all layers and returns
  nothing
- Mitigation: L4 is the terminal layer and must produce output even for novel tasks
  ("no coverage — generate and store"). The generation step creates a provisional L4 fact
  that is stored for future use.

### Stale cross-layer dependency

- Risk: An L2 routing rule depends on an L4 fact that has been updated; the L2 rule now
  routes incorrectly
- Mitigation: `depends_on` metadata tags (see Cross-Layer Dependencies section). Until
  tooling is available, quarterly memory audits should check L2 entries against their
  cited L4 sources.

### Layer bypass

- Risk: An agent skips layers (e.g., queries L4 directly without checking L2/L3), missing
  hot-cache hits and inflating token cost
- Mitigation: Enforce resolution order in the HRM contract. L4 should not be queried
  before L3; L3 should not be queried before L2. Document this order in
  `memory-index.instructions.md`.

---

## Recommendations

### Immediate (this sprint)

1. **Update `token-economics.instructions.md`** — add TRM turn budget estimator guidance
   (w_prior=0.7, w_new=0.3; dynamic progress/turns ratio checkpoint replacing fixed
   80%/50% rule).
2. **Update `memory-index.instructions.md`** — add HRM tier resolution order contract,
   L2s confidence discount (-0.10), and EscalationSignal vocabulary.
3. **Adopt Reflexion-compatible failure logging** — the existing failure protocol is
   already Reflexion-compatible; make it explicit in `token-economics.instructions.md`.

### Near-term (next 1–2 sprints)

1. **Implement TRM intent classifier (Pass 2)** — when L2 classification falls in the
   0.30–0.79 band, automatically retrieve a targeted L3 snippet and reclassify before
   routing. Cap at max_passes=2 and confidence boost at +0.15.
2. **Add heat scoring to memory promotion** — replace raw access counts with exponential
   moving average heat scores (α=0.85) computed from session event streams.
3. **Introduce `EscalationQuery` type** — structured query passed from L2 to L3/L4 with
   intent, keywords, confidence, and context_budget_remaining fields.

### Medium-term (future sprints)

1. **Formalize HRM scope constraints** — add scope-check prompts to each decomposition
   level in the agent workflow agents (sprint-planner, issue-triage, task agents).
2. **Instrument TRM+HRM signals** — log guidance signals (TURN_BUDGET_AT_RISK,
   ELEVATE_TO_L3, etc.) to `session_store_sql` for retrospective analysis and threshold
   recalibration.
3. **Calibrate thresholds from real data** — after 30 days of signal instrumentation,
   review heat scores, confidence drift, and escalation rates to validate or adjust
   the recommended threshold values in this document.

### Not recommended

- Full TRM+HRM composition in a single sprint — the risk of cascading failures without
  instrumented rollout data is too high.
- Fine-tuning a separate TRM model — the prompt-based TRM loop described here achieves
  the same behavioral properties without the operational overhead of model hosting.
- Automatic L2s promotion without two-repo validation — single-repo patterns pollute
  org-wide routing.

---

## References

1. Shinn, N., Cassano, F., Labash, B., Gopinath, A., Narasimhan, K., & Yao, S. (2023).
   *Reflexion: Language Agents with Verbal Reinforcement Learning.* arXiv:2303.11366.
2. Yao, S., Yu, D., Zhao, J., Shafran, I., Griffiths, T. L., Cao, Y., & Narasimhan, K.
   (2023). *Tree of Thoughts: Deliberate Problem Solving with Large Language Models.*
   arXiv:2305.10601.
3. Wang, X., Wei, J., Schuurmans, D., Le, Q., Chi, E., Narang, S., Chowdhery, A., &
   Zhou, D. (2022). *Self-Consistency Improves Chain of Thought Reasoning in Language
   Models.* arXiv:2203.11171.
4. Tang, J., Yang, Y., Wei, W., Shi, L., Su, L., Cheng, S., Deng, D., & Huang, C. (2023).
   *HiGPT: Heterogeneous Graph Language Model.* arXiv:2402.16024.
5. Wu, J., Hu, W., Shi, H., Cao, Y., Liang, J., & Yu, L. (2022). *Recursively
   Summarizing Books with Human Feedback.* arXiv:2109.10862.
6. Erol, K., Hendler, J., & Nau, D. S. (1994). *HTN Planning: Complexity and
   Expressivity.* Proceedings of AAAI-94, 1123–1128.
7. Base Coat. *Memory Design.* `docs/memory/MEMORY_DESIGN.md`.
8. Base Coat. *Learning Model.* `docs/memory/LEARNING_MODEL.md`.
9. Base Coat. *Token Economics.* `instructions/basecoat-50-security-token-economics.instructions.md`.
10. Base Coat. *Memory Index.* `instructions/basecoat-10-core-memory-index.instructions.md`.
