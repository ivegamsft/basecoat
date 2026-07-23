---
name: ship-it-control-loop
compatibility: [github-copilot-cli]
description: "Use when running persistent ship-it or fleet delivery waves with bounded cycle state and explicit stop conditions. USE FOR: cycle-by-cycle status summaries, transient retry and escalation policy, dry-run planning of loop actions, and handoff continuity between planning and execution phases. DO NOT USE FOR: unmanaged infinite loops, skipping required checks, or replacing release governance gates."
category: workflow
visibility: public
metadata:
  category: workflow
  maturity: alpha
  audience:
    - developer
allowed-tools: []
---

# Ship-it Control Loop Skill

Persistent control-loop contract for fleet-style ship-it execution.

## Shortcut Phrases

- execute next wave
- continue ship-it loop
- run next control-loop cycle
- fleet ship-it cycle

## Inputs

1. `goal`
2. `target_repo`
3. `max_cycles`
4. `max_retries`
5. `dry_run`
6. `stop_conditions` (optional override set)

## Process

1. Capture current loop state (`cycle_id`, phase, objective).
2. Build status snapshot from active tasks, in-scope PRs, and required checks.
3. Select and run one next action based on blockers and dependency ordering.
4. Apply retry policy for transient failures.
5. Escalate when retry budget is exhausted or deterministic policy blockers remain.
6. Emit a cycle summary and evaluate stop conditions.

## Retry and Escalation Rules

1. Retry only transient failures.
2. Cap retries per subtask at `max_retries`.
3. Escalate after retry exhaustion with explicit owner and unblock action.
4. In `dry_run`, produce planned retry/escalation actions only.

## Stop Conditions

1. Complete: tasks done + PRs merged/closed + required checks green.
2. Blocked: unresolved dependency/policy gate.
3. Max cycles reached.
4. Manual stop.

## Output

- Cycle summary markdown packet
- Structured loop status object
- Stop-condition status and next action
