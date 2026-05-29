---
name: orchestrator
description: "Compatibility alias for the orchestrator agent. Preserves the legacy filename while the prefixed BaseCoat agent is the canonical source."
type: orchestrator
---

# Orchestrator Agent

## Harness Conformance

This file satisfies the canonical-sub-agent-harness-contract for legacy
references to `agents/orchestrator.agent.md`.

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
