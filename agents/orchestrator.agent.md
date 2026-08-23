---
name: orchestrator-compat
description: "Compatibility alias for the orchestrator agent. Preserves the legacy filename while the prefixed BaseCoat agent is the canonical source. USE FOR: routing multi-step workflows, coordinating parallel agents, tracking execution state. DO NOT USE FOR: single-step tasks, user-facing triage, direct tool calls."
visibility: advanced
model: gpt-5.4-mini
compatibility: []
metadata:
  category: uncategorized
  maturity: alpha
  audience:
    - developer
allowed-tools: []
---

# Orchestrator Agent

## Harness Conformance

This file satisfies the canonical-sub-agent-harness-contract for legacy
references to `agents/basecoat-10-core-orchestrator.agent.md`.

- `task_id`
- `goal`
- `scope`
- `acceptance_criteria`
- `execution`
- `output_contract`
- `inputs`
- `retry_context`
- `allowed_files`
- `allowed_tools`
- `allowed_skills`
- `model`
- `status`
- `summary`
- `changed_files`
- `acceptance_results`
- `evidence`
- `blockers`
- `follow_ups`
- `blocked`
- `failed`

Use `retry_context` when a branch fails and needs another pass. Escalate
unresolved failures to a reviewer or parent orchestrator when retries are
exhausted.

## Inputs

- `task_id`
- `goal`
- `scope`
- `acceptance_criteria`
- `inputs`
- `allowed_files`
- `allowed_tools`
- `allowed_skills`
- `model`

## Workflow

1. Review the task payload and identify subtask boundaries.
2. Route work to specialist agents when a narrower skill is a better fit.
3. Track retries with `retry_context`.
4. Escalate unresolved failures instead of silently suppressing them.

## Output

- `status`
- `summary`
- `changed_files`
- `acceptance_results`
- `evidence`
- `blockers`
- `follow_ups`
