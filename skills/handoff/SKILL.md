---
name: handoff
compatibility: [github-copilot-cli]
description: "Use when ending a session or transferring work so another agent or future session can resume with preserved reasoning, exact files, commands, and blockers. USE FOR: create end-of-session handoff, transfer task between agents, summarize unfinished work with next steps, capture commands and validations run, package follow-up deployment context. DO NOT USE FOR: solving the task itself, long-term project planning, writing user-facing release notes."
category: operations
---
# Handoff Skill

Transfer work cleanly when a session ends or context rotates — so another agent or future session can resume without losing reasoning or state.

## Two-Layer Approach

A good handoff captures both layers:

- **Semantic summary** — what the task was, why decisions were made, what failed, what tradeoffs matter.
- **Mechanical state** — exact file paths, commands run, validations completed, blockers, and concrete next steps.

## Templates in This Skill

| Template | Purpose |
|---|---|
| `handoff-template.md` | Session handoff covering status, completed work, failed approaches, decisions, dependencies, files modified, and commands run |
