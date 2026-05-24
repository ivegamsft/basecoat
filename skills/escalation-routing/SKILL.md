---
name: escalation-routing
description: "Use when routing high-risk decisions to the right human approver with a PR-comment approval trail. USE FOR: release signoff, irreversible changes, compliance gates. DO NOT USE FOR: routine automation."
compatibility:
  editors:
    - vscode
  platforms:
    - github
metadata:
  category: "Governance"
  tags: ["escalation", "approval", "human-in-the-loop", "pr-comment"]
  maturity: "beta"
  audience: ["developers", "tech-leads", "reviewers"]
allowed-tools: ["bash", "git", "gh"]
visibility: "internal"
---
# Escalation Routing Skill

Use this skill to package high-risk decisions for human approval with a durable trail in GitHub.

## Reference Files

| File | Purpose |
|---|---|
| [`references/approval-packet-template.md`](references/approval-packet-template.md) | Structured decision packet and PR-comment approval template |

## When to Route

Route the decision when the work is:

- High-risk, irreversible, or compliance-sensitive
- Ambiguous enough that a human must choose between valid options
- A PR that needs explicit sign-off before merge or release
- A change that needs a traceable approval record in GitHub

## Expected Output

Return two artifacts:

1. A structured approval packet with the risk, recommendation, approver, and options
2. A PR-comment approval request that a human can answer in-thread

## Related Patterns

- `skills/human-in-the-loop` — explicit human judgment and approval gates
- `skills/decision-log-capture` — durable decision records with rationale and follow-up actions
