# Fleet Dispatch Policy

## Overview

This document defines guardrails and decision criteria for parallel sub-agent dispatch in autopilot (fleet) mode. Fleet dispatch enables autonomous, fault-tolerant parallel execution of multiple agents on independent, well-defined subtasks — but only when conditions are right. Misapplied fleet dispatch causes wasted resources, cascading failures, and context thrash.

**This is the reference playbook for when to dispatch and when to defer.**

---

## Core Principle

**Dispatch only when the task is deterministic, single-issue, time-bounded, and can fail independently without blocking the primary goal.**

---

## When to Dispatch (✓ Good Candidates)

### Dispatch Checklist

Fleet dispatch is appropriate when **all** of these are true:

1. **Deterministic outcome** — the subtask has a well-defined, measurable success criterion (not "investigate something interesting" or "brainstorm ideas")
2. **Single issue scope** — each agent handles exactly one, non-overlapping domain (no handoffs between agents; results are merged, not composed)
3. **Independent failure** — if one agent fails, the others can still complete and report (failure of agent A does not block agent B)
4. **Time-bounded** — each agent has a clear timeout, and work fits within complexity limits (see matrix below)
5. **No mutual dependencies** — agents do not need results from each other to proceed
6. **Pre-validated scope** — the problem has been analyzed upfront; dispatch is not "explore and find out"
7. **Fallback is clear** — if all agents fail, you have a known recovery strategy (not "try again and hope")

### Dispatch Profile Examples

| Task | Profile | Rationale |
|------|---------|-----------|
| **File search** | `explore` agent in parallel over 5 independent codebases | Each codebase is isolated; failures don't cascade |
| **Code review** agent × 3 on separate PRs | `code-review` agents on independent repos | Each PR is self-contained; reviews do not depend on each other |
| **Parallel linting** on different modules | `task` agents on independent modules | Lint results aggregate without interaction |
| **Fetch schema** from 4 APIs | `explore` agents on different endpoints | Each endpoint is independent; timeouts are ~30s each |

---

## When to Defer (✗ Bad Candidates)

### Deferral Indicators

**Do NOT dispatch if any of these apply:**

1. **Judgment call or trade-off required** — e.g., "decide between architecture A or B" — requires human or consolidated reasoning, not parallel workers
2. **Research / discovery phase** — e.g., "explore the codebase and find opportunities" — outcome is not deterministic upfront
3. **Sequential dependency** — agent B must use output from agent A (e.g., "first find files, then analyze them")
4. **Multi-decision gate** — the task requires evaluating tradeoffs and picking one path (e.g., database platform selection)
5. **High-stakes or irreversible** — changes to security, permissions, or infrastructure that may cascade in production
6. **Ambiguous success criterion** — "improve code quality" or "refactor for readability" — subjective and hard to validate
7. **Resource contention** — agents compete for the same resource (token budget, API quota, file lock)
8. **Tight time window** — user is waiting synchronously; fleet overhead is unjustified

### Deferral Examples

| Task | Why defer | Better approach |
|------|-----------|-----------------|
| "Decide between React vs Vue" | Requires tradeoff analysis and judgment | Use interactive mode; have one agent reason through options |
| "Explore the API and suggest endpoints" | Outcome unknown upfront; not deterministic | Have one agent explore fully; results are documented for user review |
| "Add authentication to 3 services" | May require coordination if they share auth config | Analyze dependency chain first; dispatch only if truly independent |
| "Optimize database queries" | Requires understanding full schema and query patterns | Have one agent build full context; then optimize |
| "Create infrastructure on 3 clouds" | Risk of misconfigured secrets, resource conflicts | Deploy to one cloud; test; then parallel-scale if safe |

---

## Complexity Matrix

**Task duration estimates drive timeout and failure recovery strategy.**

### By Tier

| Tier | Duration | Example | Timeout | Fallback | Batch Size |
|------|----------|---------|---------|----------|-----------|
| **Quick** | ≤ 2 min | File search, schema fetch, simple lint | 3–5 min | Retry once with backoff | 10–20 agents |
| **Medium** | ≤ 5 min | Code review, simple analysis, data aggregation | 8–10 min | Log failure; report to user | 5–10 agents |
| **Complex** | ≤ 15 min | Full codebase audit, refactor plan, integration test | 20–30 min | Escalate to interactive mode | 1–3 agents |
| **Deferred** | \> 15 min | Major architecture redesign, cross-team coordination | N/A — do not dispatch | Use interactive or autopilot in single-agent mode | N/A |

### Decision Rule

1. **Estimate task duration per agent** — Be conservative; add 20–30% buffer
2. **Select tier** — Use table above
3. **Multiply by batch size** — Estimate total wall-clock time (agents run in parallel, but account for orchestration overhead ~10–15%)
4. **Total time > 5 min?** — Re-evaluate if this should be dispatched or deferred

### Examples

- **10 file searches at ~30 sec each** = ~1 min total (quick tier, safe to dispatch 10 in parallel)
- **5 code reviews at ~2 min each** = ~2 min total (medium tier, safe to dispatch 5 in parallel)
- **3 architectural analyses at ~10 min each** = ~10 min total (complex tier, dispatch only 1–2; defer others)
- **8 refactor tasks at ~12 min each** = ~12 min total (complex tier, exceeds comfort; consider interactive mode instead)

---

## Pre-Dispatch Checklist

### Before calling `fleet` or launching parallel agents, verify

```text
□ Deterministic outcome: Can you describe success/failure in one sentence?
□ Independent scope: Each agent owns exactly one, non-overlapping domain?
□ Failure isolation: Agent A failure does NOT block agent B?
□ Time-bounded: Estimated duration ≤ limit in complexity matrix?
□ No dependencies: Agents do not read each other's output?
□ Scope pre-validated: Problem is understood; dispatch is not exploration?
□ Fallback defined: If N% of agents fail, what's the recovery plan?

→ If ANY box is unchecked, defer dispatch.
```

---

## Decision Tree: Should This Be Dispatched?

```text
                        Task Identified
                              |
                              v
                    Is outcome deterministic?
                         /         \
                       NO            YES
                       |              |
                    DEFER        Independent scope?
                       ^            /        \
                       |           NO         YES
                       |           |           |
                       └───────────┘      Time-bounded?
                                          /       \
                                        NO        YES
                                        |          |
                                     DEFER    Mutual deps?
                                        ^        /    \
                                        |      YES     NO
                                        |       |       |
                                        └───────┘   Fallback clear?
                                                      /       \
                                                    NO        YES
                                                    |          |
                                                 DEFER      DISPATCH ✓
                                                    ^
                                                    |
                                            (Plan fallback
                                             and retry strategy)
```

---

## Good vs. Bad Dispatch Examples

### Example 1: Parallel Code Review (✓ GOOD DISPATCH)

**Scenario:** Three PRs open in independent repos; you want code review on all three.

**Profile:**

- **Deterministic?** Yes — each PR gets reviewed; output is review comments
- **Independent?** Yes — PRs are in separate repos
- **Fail-safe?** Yes — one review failure doesn't block others
- **Time-bounded?** Yes — ~2 min per review (medium tier)
- **Dependencies?** None

**Dispatch decision:** ✓ DISPATCH (3 `code-review` agents in parallel)

**Timeout:** 5–8 minutes total  
**Fallback:** If 1 fails, keep 2; report to user

---

### Example 2: Parallel Codebase Exploration (✗ BAD DISPATCH)

**Scenario:** "Explore 5 different services and suggest refactoring opportunities."

**Profile:**

- **Deterministic?** No — "suggest opportunities" is exploratory; outcome varies
- **Independent?** Unclear — some opportunities may span services
- **Fail-safe?** No — one service's patterns may inform others
- **Time-bounded?** Unknown — discovery phase has no bound
- **Dependencies?** Implicit — cross-service opportunity discovery

**Dispatch decision:** ✗ DEFER (use interactive mode; have one agent explore all services holistically)

**Why it fails:** Agents waste time duplicating discovery; opportunities are disconnected; user doesn't get a coherent refactoring plan.

**Better approach:** Use single interactive agent to explore all 5 services, build dependency graph, then present coherent refactoring roadmap.

---

### Example 3: Parallel File Search (✓ GOOD DISPATCH) → Fixed Bad Version

**Scenario:** Find all usage of deprecated API `OldDataFetcher` in 3 monorepo packages.

**Profile (GOOD):**

- **Deterministic?** Yes — "find all usages" is deterministic
- **Independent?** Yes — each package is independent
- **Fail-safe?** Yes — one package's search failure doesn't affect others
- **Time-bounded?** Yes — ~1 min per package (quick tier)
- **Dependencies?** None

**Dispatch decision:** ✓ DISPATCH (3 `explore` agents, each searching one package)

**Timeout:** 3–5 minutes total  
**Fallback:** If 1 fails, report partial results; user can manually search that package

---

**If misapplied (✗ BAD):** "Find usages AND refactor them in parallel across 3 packages"

**Why it fails:**

- Refactoring requires understanding the full API surface (dependency on search results)
- Changes in one package may affect another (not independent)
- Conflicting refactors could break shared interfaces

**Fix:** Dispatch search in parallel (find usages); then defer refactor to interactive mode with full context.

---

### Example 4: Parallel Security Audit (✗ BAD DISPATCH)

**Scenario:** "Audit security in 4 microservices and apply fixes."

**Profile:**

- **Deterministic?** No — audit scope and fixes are evolving
- **Independent?** No — shared auth config, secrets, API gateway may affect all
- **Fail-safe?** No — one service's fix may break another (e.g., permission changes)
- **Time-bounded?** Unknown — "fix" scope is undefined
- **Dependencies?** Yes — services share infrastructure

**Dispatch decision:** ✗ DEFER (use interactive mode; have one agent audit all 4 holistically and present plan for approval)

**Why it fails:** Parallel agents making security changes can create conflicts (e.g., overlapping secret rotations) or miss interdependencies.

**Better approach:**

1. Have one agent audit all 4 services and build a dependency map
2. Present audit results and proposed fixes to user for review
3. If approved, dispatch fixes **after** validating no conflicts exist

---

## Timeout and Fallback Strategy

### Timeouts by Tier

| Tier | Per-Agent Timeout | Total Timeout | Grace Period |
|------|------------------|---------------|-------------|
| Quick | 3–5 min | 5 min | 30 sec |
| Medium | 8–10 min | 12 min | 1 min |
| Complex | 20–30 min | 35 min | 2 min |

**Grace period** = time to allow agent to clean up after timeout signal.

### Timeout Handling

1. **Set per-agent timeout** — Agent context includes explicit timeout
2. **Monitor heartbeat** — Check agent status every 30–60 sec
3. **Trigger grace period** — If timeout reached, send termination signal and wait grace period
4. **Force termination** — If agent doesn't stop after grace, forcibly kill session
5. **Collect partial results** — Even if some agents timeout, aggregate results from those that succeeded

### Fallback Strategies

#### Strategy A: Retry with Backoff (Quick tier)

```python
if any_agent_failed:
  wait random(1, 5) seconds
  retry_failed_agents (max 2 attempts)
  if still_failed:
    report to user with partial results
```

#### Strategy B: Partial Success (Medium tier)

```python
if >50% agents succeeded:
  aggregate results from successful agents
  report to user with "some tasks incomplete" warning
  offer: (a) retry failed, (b) continue with partial
else:
  fall back to interactive mode
  have user select which tasks to retry/defer
```

#### Strategy C: Escalate to Interactive (Complex tier)

```python
if any_agent_failed:
  save checkpoint of successful work
  escalate to interactive mode
  present user with: "Fleet dispatch incomplete. Resume with:"
    (a) Continue with single agent + context
    (b) Retry specific failed agents
    (c) Defer to manual
```

### Fallback Decision Logic

```python
failure_rate = failed_agents / total_agents

if failure_rate == 0:
  SUCCESS — aggregate all results

if 0 < failure_rate ≤ 0.2:  # ≤ 1 out of 5 failed
  PARTIAL — use strategy A or B

if failure_rate > 0.2:  # > 1 out of 5 failed
  ESCALATE — use strategy C
```

---

## Implementation Checklist for Agent Authors

When authoring agents intended for fleet dispatch:

```text
□ Define explicit, measurable success/failure criteria in agent frontmatter
□ Set realistic timeout estimates in agent metadata
□ Include graceful shutdown hooks (cleanup code on timeout)
□ Log structured results (JSON or CSV) for aggregation
□ Avoid side effects that affect other agents (no shared state writes)
□ Include retry logic for transient failures (network, rate limits)
□ Document assumptions about scope and dependencies
□ Test agent in parallel with 2–3 identical copies
□ Include "dry-run" or "report-only" mode for safety
□ Add monitoring/observability hooks for fleet orchestrator
```

---

## Summary

**Golden Rule for Fleet Dispatch:**

> Dispatch only when you can describe the task in one sentence, estimate its duration precisely, and explain how partial failure recovers gracefully.

If you cannot meet this standard, defer to interactive mode.

---

## References

- [Intent Prefixes Guide](../guides/intent-prefixes.md) — Routing behavior and dispatch context
- [OPERATIONAL_RUNBOOK.md](OPERATIONAL_RUNBOOK.md) — Operational procedures
- [Autopilot Mode Documentation](https://github.com/IBuySpy-Shared/basecoat/blob/main/README.md) — Autopilot and fleet mode overview
