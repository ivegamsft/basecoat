---
name: s4-deployment-checklist
description: "Use when preparing an S4 cutover, shadow-mode soak, rollback validation, or deployment readiness review. USE FOR: checklist-driven release gating, rollback testing, monitoring readiness, and team briefing. DO NOT USE FOR: generic release notes or unrelated sprint planning."
compatibility:
  editors:
    - vscode
  platforms:
    - github
metadata:
  category: "Uncategorized"
  tags: ["uncategorized"]
  maturity: "beta"
  audience: ["developers"]
allowed-tools: ["bash", "git", "grep", "find"]
visibility: "internal"
---
# S4 Deployment Checklist Skill

Prepare a cutover checklist that makes rollout readiness, shadow-mode proof, rollback testing, and monitoring explicit.

## Templates in This Skill

| Template | Purpose |
|---|---|
| `deployment-checklist.md` | S4 cutover checklist covering shadow mode, rollback, monitoring, and team readiness |

## Core Rules

- Require shadow-mode validation before cutover.
- Confirm rollback is testable before any 100% traffic shift.
- Make monitoring and alerting part of the go/no-go decision.
- Record ownership for on-call review and team briefing.

## Agent Pairing

Use with deployment and release-management agents that need a concrete cutover checklist rather than broad release advice.
