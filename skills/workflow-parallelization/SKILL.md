---
name: workflow-parallelization
compatibility: [github-copilot-cli]
description: "Use when designing or optimizing multi-job CI pipelines, agent fan-out patterns, or multi-session sprint execution for maximum parallel throughput. USE FOR: identify parallelizable CI jobs, design parallel agent dispatch, configure fan-out/fan-in workflow patterns, enforce serialized merge pacing after parallel execution. DO NOT USE FOR: bypassing required sequential gates, implementing infrastructure, direct code changes."

category: workflow
visibility: public
metadata:
  category: workflow
  maturity: alpha
  audience:
    - developer
    - devops
allowed-tools: []
model_policy:
  fallback: true
  preferred_families:
    - gpt-5.4-mini
    - claude-sonnet
  upshift:
    allowed: true
    owner: runtime
    max_tier: reasoning
    triggers:
      - complexity
      - safety_risk
  cost_tracking:
    budget_tier: low
    chargeback_tag: workflow-parallelization
---

# Workflow Parallelization Skill

Design parallel execution for CI, agent fan-out, and multi-session delivery.

## Shortcut Phrases

- parallelize workflow
- run in parallel

## CI Job Parallelization

Two jobs can run in parallel when:

1. Job B does not consume any output artifact from job A.
2. Job B does not require environment state produced by job A.
3. Both jobs are independent of each other's side effects.

### Job Group Patterns

| Pattern | When to use | Example |
|---|---|---|
| Full fan-out | All jobs are independent | lint, typecheck, unit-test together |
| Staged parallel | Jobs depend on shared setup | setup → [lint, test, build] |
| Pipeline with merge | Parallel jobs feed a final step | [unit, integration] → coverage |

## Agent Fan-Out Pattern

1. **Decompose** — split into independent subtasks with no data dependency.
2. **Dispatch simultaneously** — launch all in a single orchestrator turn.
3. **Track states** — monitor completion; surface blockers promptly.
4. **Fan-in** — collect all results before aggregating.
5. **Serialize writes** — parallel reads, but serialize merges/commits/deployments.

## Multi-Session Sprint Execution

1. One issue per session; avoid cross-session dependencies.
2. Use `parallel-session-coordinator` to track states and enforce merge order.
3. Serialized merge pacing: one PR merges at a time.
4. After each merge, rebase dependent sessions before continuing.

## Output

- Parallelization opportunity map for the given workflow or task set
- Recommended job group layout with estimated time savings
- Fan-out dispatch plan for multi-agent or multi-session execution
- Merge serialization queue with conflict risk annotations
