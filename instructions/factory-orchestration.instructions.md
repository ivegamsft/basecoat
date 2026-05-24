---
description: "Use when editing factory orchestration workflows, state files, escalation paths, or Workcell triggers."
applyTo: ".github/**/*"
---

# Factory Orchestration Rules

Use this instruction when work touches the factory orchestration state machine or the workflows that consume it.

## Expectations

- Treat `.github/factory-state.json` as the source of truth for orchestration state.
- Read the current state before proposing a transition.
- Only auto-proceed when the state file explicitly permits the next step.
- Escalate when a transition is ambiguous, missing, or blocked by a manual decision.

## State File Rules

- Model each state transition explicitly.
- Keep stage names stable so agents can compare state across runs.
- Store transition conditions in the state file rather than in chat history.
- Prefer deterministic machine-readable values over prose-only guidance.

## Workcell Workflow Triggers

- Trigger Workcell workflows only after the required state gate passes.
- Do not chain multiple transitions silently.
- Record the triggering state and the target workflow in the change.

## Slack Notifications

- Send concise notifications that include the current state, the next action, and the owner.
- Avoid noisy duplicate alerts for the same blocked gate.
- Use the same state name in Slack and in the repo file so the trail is searchable.

## Review Lens

- Can an agent infer the next step without guessing?
- Is the transition explicit and reversible if needed?
- Does the notification explain what changed and who owns the next action?
