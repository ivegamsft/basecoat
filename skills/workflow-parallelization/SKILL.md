---
name: workflow-parallelization
description: "Use when designing or optimizing multi-job CI pipelines, agent fan-out patterns, or multi-session sprint execution for maximum parallel throughput. USE FOR: identify parallelizable CI jobs, design parallel agent dispatch, configure fan-out/fan-in workflow patterns, enforce serialized merge pacing after parallel execution. DO NOT USE FOR: bypassing required sequential gates, implementing infrastructure, direct code changes."
compatibility:
  - GHCP
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

Design and optimize parallel execution patterns for CI pipelines, multi-agent task fan-out, and multi-session sprint delivery.

## Shortcut Phrases

- parallelize workflow
- fan out tasks
- run in parallel
- identify parallel jobs
- multi-session sprint

## CI Job Parallelization

### Dependency Analysis

Two jobs can run in parallel when:

1. Job B does not consume any output artifact from job A.
2. Job B does not require environment state produced by job A.
3. Both jobs are independent of each other's side effects.

### Job Group Patterns

| Pattern | When to use | Example |
|---|---|---|
| Full parallel fan-out | All jobs are independent | lint, typecheck, unit-test running simultaneously |
| Staged parallel | Jobs depend on a shared setup step | setup → [lint, test, build] in parallel |
| Pipeline with merge | Parallel jobs feed a final aggregation | [test-unit, test-integration] → coverage-report |
| Conditional parallel | Branch on change type | [docs-check] OR [build, test] based on changed files |

### GitHub Actions Parallel Job Template

```yaml
jobs:
  lint:
    runs-on: ubuntu-latest
    steps: [...]

  typecheck:
    runs-on: ubuntu-latest
    steps: [...]

  unit-tests:
    runs-on: ubuntu-latest
    steps: [...]

  # Aggregation step waits for all parallel jobs
  ci-complete:
    needs: [lint, typecheck, unit-tests]
    runs-on: ubuntu-latest
    steps:
      - run: echo "All parallel checks passed"
```

## Agent Fan-Out Pattern

For multi-agent task decomposition with parallel dispatch:

1. **Decompose** — split the task into independent subtasks with no data dependency.
2. **Dispatch simultaneously** — launch all independent subtasks in a single orchestrator turn.
3. **Track states** — monitor each subtask's completion state; surface blockers promptly.
4. **Fan-in** — collect all results before aggregating; normalize output format.
5. **Serialize writes** — even with parallel reads, serialize any write operations (merges, commits, deployments).

## Multi-Session Sprint Execution

When running parallel sessions across multiple GitHub Copilot worktrees:

1. Assign one issue per session; avoid cross-session dependencies when possible.
2. Use `parallel-session-coordinator` agent to track states and enforce merge order.
3. Apply serialized merge pacing: only one PR merges at a time.
4. After each merge, rebase dependent sessions before continuing.
5. Detect and resolve file-level conflicts before they reach the merge queue.

## Serialized Merge Pacing

Parallelism during implementation; serialization at merge time:

```text
[session-1: implementing] ──┐
[session-2: implementing] ──┼── merge queue ──► merge-1 ──► merge-2 ──► merge-3
[session-3: implementing] ──┘   (one at a time)
```

Rules:

- Confirm required CI checks are green before each merge.
- Wait for merge completion and post-merge checks before merging the next PR.
- Clean up local and remote branch state after each merge.

## Output

- Parallelization opportunity map for the given workflow or task set
- Recommended job group layout with estimated time savings
- Fan-out dispatch plan for multi-agent or multi-session execution
- Merge serialization queue with conflict risk annotations
