---
description: "Use when deciding whether work should escalate for design review, approval, or compliance sign-off."
applyTo: "**/*"
---

# Escalation Criteria

Use this instruction when a task may need human approval or a higher-level design review.

## Expectations

- Escalate when complexity is more than 3x the expected effort.
- Escalate when risk exceeds the documented threshold.
- Escalate when the architecture needs a formal design review.
- Escalate when compliance, security, or release policy requires approval.

## Approval Flow

- Identify the approver before starting the escalation.
- Document the reason for escalation in the issue or pull request.
- Keep the approval request short, specific, and actionable.
- Record the final decision in GitHub so the trail is searchable later.

## Escalation Packet

When a decision is high-risk, route it through `escalation-router` and include:

- Decision type
- Risk level
- Human approver
- Recommendation
- Options considered
- Blocking conditions
- Next action

If the request is tied to a PR, post the packet as a PR comment and ask the approver to reply in-thread using the template's reply format.

## Decision Notes

- Capture what was reviewed, what was approved, and what remains open.
- Distinguish approval for implementation from approval for release.
- If the decision is deferred, note the blocking conditions explicitly.

## Review Lens

- Is the escalation based on a clear trigger?
- Is the right approver involved?
- Can someone else find the decision later without extra context?
