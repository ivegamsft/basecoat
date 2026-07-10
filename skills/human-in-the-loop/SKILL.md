---
name: human-in-the-loop
compatibility: [github-copilot-cli]
description: "Use when agent workflows need explicit human judgment for destructive, ambiguous, high-stakes, or low-confidence actions, with approval gates and escalation patterns. USE FOR: add approval step before production deploy, define escalation triggers for risky automation, design asynchronous human review workflow, defer destructive action pending approval, document graceful degradation when reviewers are unavailable. DO NOT USE FOR: fully autonomous low-risk tasks, replacing security policy, general chatbot conversation design."
category: operations
metadata:
  category: operations
  maturity: stable
  audience:
    - developer
allowed-tools: []
---
# Human-in-the-Loop

Patterns for agent workflows that require explicit human judgment before taking destructive, ambiguous, high-stakes, or low-confidence actions.

## Reference Files

| File | Contents |
|------|----------|
| [`references/patterns.md`](references/patterns.md) | Confirmation gate pattern, escalation triggers, approval workflows (sync/async/delegated), graceful degradation, anti-patterns |

## When to Involve Humans (Quick Reference)

| Trigger | Action |
|---------|--------|
| Destructive operation | Gate: present plan, impact, rollback — wait for approval |
| Ambiguous requirements | Escalate: enumerate interpretations, ask for clarification |
| High-stakes change | Gate: security/data/public-facing changes require explicit sign-off |
| Low confidence | Escalate: delegate to more capable agent or human |
| Error threshold exceeded | Escalate: 3+ failures on same task |
| Token budget near limit | Escalate: hand off to fresh session or human |
