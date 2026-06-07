# Execution Hierarchy

Defines the layered execution stack for all BaseCoat agents. Every task traverses this stack in order — layers cannot be skipped, only the context load depth varies based on intent classification.

> Related: `instructions/basecoat-50-security-token-economics.instructions.md`, `instructions/basecoat-10-core-memory-index.instructions.md`, `instructions/basecoat-20-lang-governance.instructions.md`
>
> **For forks:** The Pattern Bundle Catalog (Layer 3a) ships with BaseCoat's own patterns as a reference. Replace or extend it with your team's patterns. The stack architecture and confidence lifecycle are framework guidance — keep those. Pattern confidence scores reflect BaseCoat's own history; reset them to `0.80` (provisional) when adopting.

---

## The Stack

```text
┌─────────────────────────────────────────────────────────────────┐
│  Layer 0 — System Instructions                                  │
│  Set by the host/IDE. Defines model role and capabilities.      │
│  Immutable. Not accessible to agents.                           │
├─────────────────────────────────────────────────────────────────┤
│  Layer 1 — BaseCoat Guardrails  [always-on, structural]         │
│  governance · security · agent-behavior · no-secrets            │
│  These are circuit breakers, not context. They fire at fixed    │
│  checkpoints regardless of which execution path is taken.       │
├─────────────────────────────────────────────────────────────────┤
│  Layer 2 — Intent Classification  [pre-context]                 │
│  Parse user message + L2 memory index trigger map.              │
│  Output: intent class + pattern confidence score.               │
│  Cost: ~0 tokens (in-context, no new loads required).           │
│                                                                 │
│  confidence ≥ 0.80 → FAST PATH                                  │
│  confidence < 0.80 → FULL PATH                                  │
├──────────────────────────┬──────────────────────────────────────┤
│  Layer 3a — FAST PATH    │  Layer 3b — FULL PATH               │
│                          │                                      │
│  Load pre-built pattern  │  Layered context load:              │
│  bundle for this intent  │  1. L2 index → subject map          │
│  (instructions + docs    │  2. L3 episodic → prior sessions    │
│  already scoped to this  │  3. L4 semantic → docs on demand    │
│  pattern type)           │  4. Broad repo exploration          │
│                          │                                      │
│  Turn budget: from prior │  Turn budget: estimated N           │
│  successful executions   │  (Novel learning cost)              │
│  (≤3 for Routine)        │                                      │
├──────────────────────────┴──────────────────────────────────────┤
│  Layer 4 — Task Execution                                       │
│  Guardrail checkpoints fire here:                               │
│  • Before first implementation step: issue-first check          │
│  • Before any file with credential patterns: no-secrets check   │
│  • Before any git commit: PR-only check                         │
├─────────────────────────────────────────────────────────────────┤
│  Layer 5 — Post-Execution Learning                              │
│  • Success + within budget + tests pass + novel:                │
│    store_memory → update pattern bundle confidence ↑            │
│  • Failure + >5 turns + no progress:                            │
│    store_memory failure → demote bundle confidence ↓            │
│  • Bundle confidence < 0.5 after 3 overruns: retire fast path   │
└─────────────────────────────────────────────────────────────────┘
```text

---

## Layer 1 — Guardrails as Circuit Breakers

Guardrails are **not** part of the context loading sequence. They are always-active rules that fire at fixed execution checkpoints. A fast-path routing cannot lower their priority or skip them.

| Checkpoint | Rule | Source |
|---|---|---|
| Session start | Read governance.instructions.md before any action | `governance.instructions.md` |
| Before implementation | Issue must exist — hard stop if not | `governance.instructions.md §1` |
| Before writing any file with auth/credential patterns | No secrets check | `governance.instructions.md §2` |
| Before any `git commit` or `git push` | PR-only; no direct main commits | `governance.instructions.md §3` |
| Before third retry of same command | Stop, change approach | `agent-behavior.instructions.md` |
| Before escalating model tier | Change approach first | `token-economics.instructions.md` |

These checkpoints fire on **both** fast path and full path. Speed is in context loading, not in bypassing safety checks.

---

## Layer 2 — Intent Classification

Intent classification uses only what is already in context — the user message and the L2 memory index trigger map. No additional file loads are needed.

### Classification Algorithm

```text
1. Extract intent keywords from the user message
2. Scan the L2 trigger map (memory-index.instructions.md) for matches
3. If match found:
     confidence = match_strength × bundle_confidence
     if confidence ≥ 0.80 → assign pattern, take FAST PATH
     if confidence 0.50–0.79 → assign pattern tentatively, FULL PATH with bundle pre-loaded
     if confidence < 0.50 → FULL PATH, no bundle
4. If no match: Novel task → FULL PATH, estimate turn budget
```text

### Confidence Score Inputs

| Factor | Weight | Notes |
|---|---|---|
| Keyword match depth | 40% | How many trigger keywords match |
| Prior bundle success rate | 40% | Ratio of on-budget completions for this bundle |
| Context similarity | 20% | Whether active files/branch match bundle's typical scope |

### Classification Examples

| User message | Intent class | Confidence | Path |
|---|---|---|---|
| "run the tests" | `run-tests` | 0.95 | Fast |
| "fix the lint errors" | `fix-lint` | 0.90 | Fast |
| "compile the agentic workflow" | `compile-aw` | 0.92 | Fast |
| "add a new agent for X" | `new-agent` | 0.85 | Fast |
| "fix the failing CI" | `fix-ci` | 0.60 | Full (root cause unknown) |
| "refactor the portal auth flow" | `portal-feature` | 0.55 | Full (scope unclear) |
| "integrate Azure Service Connector" | Novel | 0.20 | Full (no bundle) |

---

## Layer 3a — Fast Path: Pattern Bundles

A pattern bundle is a pre-scoped execution package for a known intent. It contains:

- **Context set**: which instruction files and doc sections to load (already narrowed)
- **Turn budget**: validated from prior successful executions
- **Verification criteria**: how to confirm success
- **Confidence**: degrades if bundle leads to overruns

### Confidence Lifecycle

```text
New bundle: confidence = 0.80 (provisional)
Each on-budget success:  confidence += 0.05 (max 1.0)
Each overrun (>budget):  confidence -= 0.15
Each failure (>5 turns, no progress): confidence -= 0.25
confidence < 0.50: demote to tentative (0.50–0.79 zone — triggers full path)
confidence < 0.30: retire bundle, remove from fast-path catalog
```text

### BaseCoat Pattern Bundle Catalog

| Bundle ID | Intent keywords | Context set | Turn budget | Confidence |
|---|---|---|---|---|
| `run-tests` | run tests, validate, check tests | `instructions/governance` + test commands | 1 turn | 0.98 |
| `fix-lint` | lint, markdown lint, MD0xx, fix warnings | `instructions/governance` + lint commands | 2 turns | 0.92 |
| `new-agent` | new agent, create agent, add agent | `instructions/agents`, `instructions/governance`, agent template | 3 turns | 0.88 |
| `new-instruction` | new instruction, add instruction, create instructions | `instructions/governance`, frontmatter spec | 2 turns | 0.90 |
| `compile-aw` | compile, agentic workflow, gh aw | `docs/agentic-workflows.md`, `instructions/governance` | 2 turns | 0.90 |
| `merge-pr` | merge, dependabot, merge PR | `instructions/governance` + gh commands | 3 turns | 0.85 |
| `release` | release, version bump, tag, CHANGELOG | `docs/RELEASE_PROCESS.md`, `version.json`, `CHANGELOG.md` | 4 turns | 0.87 |
| `clean-branches` | clean branches, stale branches, delete branches | git commands only | 2 turns | 0.95 |
| `portal-feature` | portal, component, hook, frontend | `instructions/frontend`, `instructions/testing`, portal src | 5 turns | 0.80 |

### Adding a New Bundle

When a Novel task completes successfully within budget and `store_memory` is called, create a bundle candidate:

```markdown
Bundle ID: <kebab-case-id>
Intent keywords: <2-5 trigger phrases>
Context set: <list of files/docs needed>
Turn budget: <actual turns taken>
Confidence: 0.80 (provisional — elevates with reuse)
```text

---

## Layer 3b — Full Path: Layered Context Load

Used when intent is Novel, confidence is below threshold, or the fast path bundle was retired.

Load in this order, stopping when context is sufficient:

```text
1. L2 trigger map (already loaded) → identify relevant subjects
2. L3 episodic: session_store_sql → prior sessions on this subject
3. L4 semantic: targeted docs sections (not full files)
4. Broad exploration only as last resort
```text

Set an estimated turn budget at start:

- No prior sessions found: estimate 6–8 turns (full learning cost)
- Prior sessions found but failed: estimate 4–6 turns (partial learning)
- Prior sessions found and succeeded: reclassify as Familiar, estimate 4–5 turns

---

## Layer 5 — Post-Execution Learning

After every task, regardless of path taken:

| Outcome | Action |
|---|---|
| Success + within budget + novel solution | `store_memory` → increment bundle confidence |
| Success + within budget + known pattern | Increment bundle confidence only |
| Success + overran budget | Note overrun; don't store unless solution was non-obvious |
| Failure + >5 turns + no progress | `store_memory` failure pattern; decrement bundle confidence |
| Fast path led to overrun 3×  | Demote bundle confidence below 0.50 → retires from fast path |

---

## Guardrail vs. Context: The Distinction

| Type | Example | Behavior |
|---|---|---|
| **Guardrail** | "No direct commits to main" | Fires at fixed checkpoint; cannot be routed around |
| **Context** | "Load token-economics.instructions.md" | Loaded based on intent class; fast path loads less |
| **Bundle** | "For `run-tests`: load test commands + governance" | Pre-scoped context load for known intent |
| **Fallback** | "No match: load layered context" | Full path when pattern confidence is low |

The guardrails live at Layer 1. Context loading starts at Layer 3. A fast path can load less context — it cannot skip Layer 1.
