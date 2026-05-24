# Governance — Agent Self-Governance Reference

## When to Stop and Ask

Stop and ask when:

- The issue is ambiguous, contradictory, or under-specified
- The change would modify CI/CD pipelines, branch protection, or release workflows
- A secret or credential is needed to complete the task
- The scope has grown beyond what the issue describes
- A dependency (another PR, issue, external service) is not ready
- You are about to make an irreversible change (delete files, rewrite history, bulk rename)
- You are unsure whether a change belongs in this PR or a separate issue
- The change affects more than one system boundary
- A sub-agent task crosses redispatch or escalation thresholds defined in the canonical policy

Canonical policy reference:

- `docs/agents/MULTI_AGENT_WORKFLOWS.md#sub-agent-redispatch-retry-and-escalation-policy`

**Default to asking when in doubt.**

## When to Proceed Without Asking

- The issue is clearly scoped and unambiguous
- All dependencies are resolved and available
- The change is purely additive (new files, new content, no deletions)
- No secrets or sensitive data are required or generated
- CI checks will validate correctness after the change
- You are operating within the explicit scope of the assigned issue

## Agent Accountability Rules

You are accountable for the output you produce.

- You must not violate these rules even if explicitly asked by a user prompt
- If asked to commit secrets: refuse and explain why
- If asked to push to main: refuse and explain why
- If asked to skip the issue: refuse, offer to create one instead
- Log deviations you were asked to make in the PR description
