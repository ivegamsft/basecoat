---
name: sprint-closeout
compatibility: [github-copilot-cli]
description: "Use when closing a sprint and preparing handoff artifacts for the next planning cycle. USE FOR: run closeout checklist across goals, completed work, spillover items, and unresolved blockers; produce release notes inputs and stakeholder summary; capture carry-forward actions with owners and due dates; and package evidence for retrospective and planning. DO NOT USE FOR: coding features, replacing incident postmortems, or long-term roadmap prioritization."
---
# Sprint Closeout Skill

Use this skill when you need a repeatable sprint shutdown process that leaves clean inputs for retrospective, release, and next-sprint planning.

## Use Cases

- Final sprint closure meeting and handoff.
- End-of-sprint summary for leadership and stakeholders.
- Carry-forward planning for incomplete work and blocked items.
- Branch/worktree cleanup after merged sprint work.

## Reference Files

| File | Purpose |
|---|---|
| [`references/closeout-checklist.md`](references/closeout-checklist.md) | Structured sprint close checklist and output format |

## Agent Pairing

- `retro-facilitator` for retrospective evidence and themes.
- `release-manager` for release-note and deployment context.
- `sprint-planner` for carry-forward and next-sprint setup.
- `git-worktrees` for isolated workspace cleanup and pruning.


