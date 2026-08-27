# Orchestrator — Detail Reference

## Routing Logic

1. Analyze the user request for domain signals: code, infrastructure, docs, testing, security, architecture, product, or mixed-domain execution.
2. Map each domain to a primary agent and at least one alternate.
3. Prefer the specialist with the closest capability match, lowest current load, and clearest output contract.
4. If the preferred specialist is unavailable, overloaded, or repeatedly fails, route to an alternate.
5. Fall back to a general-purpose agent when no specialist clearly matches.

| Domain signal | Primary agent | Alternate agents |
| --- | --- | --- |
| Code quality and regression risk | `code-review` | `backend-dev`, `frontend-dev` |
| Infrastructure, CI/CD, environments | `devops-engineer` | `solution-architect`, `config-auditor` |
| Documentation and communication | `tech-writer` | `product-manager`, `agent-designer` |
| Manual, exploratory, or release testing | `manual-test-strategy` | `exploratory-charter`, `performance-analyst` |
| Security and threat assessment | `security-analyst` | `config-auditor`, `code-review` |
| System design and decomposition | `solution-architect` | `agent-designer`, `backend-dev` |

## Orchestration Patterns

- **Sequential pipeline** — use `A → B → C` when each step depends on prior output, such as generate → validate → publish.
- **Parallel fan-out** — dispatch `A`, `B`, and `C` simultaneously when subtasks are independent, then merge results into one response.
- **Conditional routing** — branch based on runtime signals, such as routing to `security-analyst` for auth or secrets concerns and to `devops-engineer` for deployment concerns.
- **Iterative refinement** — run a generate → review → revise loop when the task benefits from critique and correction before final delivery.

## Result Aggregation

- Normalize output structure before merging so every subtask reports scope, status, evidence, and recommendations.
- Deduplicate overlapping findings and preserve the strongest supporting evidence.
- Keep specialist detail where it matters, but present one user-facing narrative rather than a stack of unrelated agent transcripts.
- Mark partial results explicitly so the user can distinguish completed work from degraded coverage.

## Conflict Resolution

- Compare contradictory outputs against source evidence, tests, logs, or repository state.
- Prefer the conclusion with the strongest verifiable evidence and the narrowest unsupported assumptions.
- If evidence is mixed, run a targeted tie-break pass with the most relevant reviewer agent.
- If the conflict remains unresolved, surface both interpretations, identify the uncertainty, and recommend the next check.

## Harness Conformance

- Use the orchestrator lifecycle sequence, states, and conflict decision points in `docs/agents/multi-agent-workflows.md#orchestrator-lifecycle-dispatch-fan-in-and-conflict-resolution`.
- Use the canonical sub-agent harness contract in `docs/agents/multi-agent-workflows.md#canonical-sub-agent-harness-contract`.
- Dispatch every subtask with a task envelope containing `task_id`, `goal`, `scope`, `acceptance_criteria`, `execution`, and `output_contract`.
- Include optional task envelope fields when relevant: `inputs` and `retry_context`.
- Ensure `execution` includes `allowed_files`, `allowed_tools`, `allowed_skills`, and `model`.
- Require sub-agent response envelopes with `task_id`, `status`, `summary`, `changed_files`, `acceptance_results`, and `evidence`.
- Require `blockers` when `status` is `blocked` or `failed`; include `follow_ups` when additional actions are recommended.
- On retry, set `retry_context` with prior failure reasons and focused re-dispatch guidance.
- Escalate unresolved ambiguity or repeated branch failure to a review or tie-break pass before final delivery.
- Apply policy checks from `docs/reference/guardrails/tool-confirmation-policy.md` before executing side-effecting actions.

## Failure Handling

- Retry transient failures once by default and twice at most for flaky or timeout-prone subtasks.
- Route around failed agents by assigning the subtask to a defined alternate.
- Deliver partial completion when some subtasks succeed and others fail, with clear status markers for each branch.
- Gracefully degrade by handling the work in the orchestrator or with a general-purpose agent when a specialist is unavailable.

## Configuration

Maintain an explicit orchestration configuration that includes the agent registry, routing rules, timeout policy, and budget allocation.

```yaml
agent_registry:
  code-review:
    capabilities: [code, regression, review]
    fallback: [backend-dev, frontend-dev]
  devops-engineer:
    capabilities: [infra, ci-cd, deployment]
    fallback: [solution-architect, config-auditor]
  tech-writer:
    capabilities: [docs, summaries, handoff]
    fallback: [product-manager]
routing_rules:
  code: code-review
  infra: devops-engineer
  docs: tech-writer
  testing: manual-test-strategy
  security: security-analyst
timeout_policy:
  per_agent_seconds: 600
  overall_seconds: 1800
budget_allocation:
  strategy: weighted-by-complexity
  reserve_for_aggregation_percent: 20
```

Configuration guidelines:

- **Agent registry** — keep a current list of available agents, their capabilities, alternates, and expected output formats.
- **Routing rules** — define domain-to-agent mappings and mixed-domain fan-out rules.
- **Timeout policy** — set both per-agent and overall orchestration limits, plus timeout escalation behavior.
- **Budget allocation** — split token or execution budget by task complexity, reserving budget for retries and final aggregation.
