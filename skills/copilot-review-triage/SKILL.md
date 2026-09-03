---
name: copilot-review-triage
compatibility: [copilot-chat, copilot-coding-agent, github-copilot-cli]
description: "Triage inbound automated Copilot pull request review threads by the impact of accepting each suggestion. USE FOR: sizing Copilot review threads, validating bounded review suggestions, recording accepted or declined decisions, resolving safe threads, and escalating must-fix findings. DO NOT USE FOR: initial code review, auto-applying security or contract changes, or bypassing unresolved review-thread protections."
visibility: public
metadata:
  category: quality
  maturity: alpha
  audience:
    - developer
allowed-tools: []
---

# Copilot Review Triage

Process inbound Copilot review threads without silently discarding feedback.
Read unresolved threads first. Never force-push or resolve before recording outcomes.
Treat security, authorization, API, schema, and deployment-contract suggestions as
Large unless a human scoped the change.

## Impact Sizing

| Size | Signals | Default disposition |
|---|---|---|
| Small | Cosmetic, local, and behavior-preserving | Apply if trivially correct; otherwise reply with a reason and resolve. |
| Medium | Bounded edge case, refactor, validation, or test change | Rubber-duck validate; apply if sound and in scope, otherwise decline with a reason and resolve. |
| Large | Cross-cutting, security-sensitive, contractual, ambiguous, or scope-expanding | Never auto-apply; summarize risk, escalate, and leave open. |

## Per-Thread Decision Loop

1. Classify the suggestion and its acceptance impact.
2. Apply or decline Small items with a recorded reason, then resolve.
3. Rubber-duck validate Medium items; apply or decline with a reason, then resolve.
4. Do not edit or resolve Large items; escalate its surface, risk, and decision.
5. Batch accepted Small and Medium work into one focused commit.

## Completion Gate

After applying a batch:

1. Run relevant validation and a `code-review` risk pass.
2. Reply with a commit SHA or decline reason.
3. Auto-merge only if no Large items remain and required checks pass.

## Recorded Decision Format

Use a reply that makes the disposition auditable:

```text
Impact: Medium
Decision: Declined and resolved
Reason: The suggested validation duplicates the existing boundary check and
would not change the observable behavior.
```

For applied work, give the commit SHA and validation evidence. For Large work,
state `Decision: Escalated; left open`.

## Anti-Patterns

- Silently ignoring a declined suggestion.
- Auto-applying a Large item.
- Evading required review-thread resolution.
