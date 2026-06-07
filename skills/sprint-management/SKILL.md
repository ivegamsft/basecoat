---
name: sprint-management
description: "Use when planning or running sprint ceremonies, backlog refinement, and commitment tracking. USE FOR: plan sprint capacity and goals, run backlog grooming session, prepare sprint review agenda, track velocity against commitments, facilitate sprint ceremony workflow. DO NOT USE FOR: writing implementation code, annual roadmap strategy only."
---

# Sprint Management Skill

Use this skill when the task involves sprint ceremony facilitation, backlog management, branch cleanup coordination, or sprint lifecycle activities.

## When to Use

- Planning a new sprint (capacity, goals, story selection)
- Running a sprint retrospective
- Facilitating backlog grooming / refinement sessions
- Tracking sprint velocity and commitments
- Preparing for sprint demos or reviews
- Coordinating branch/worktree cleanup after sprint closeout

## How to Invoke

Reference this skill by attaching `skills/sprint-management/SKILL.md` to your agent context, or instruct the agent:

> Use the sprint-management skill. Apply the sprint planning template to set up Sprint 15.

## Templates in This Skill

| Template | Purpose |
|---|---|
| `sprint-planning-template.md` | Sprint planning ceremony — goals, capacity, story selection, and commitments |
| `retrospective-template.md` | Sprint retrospective — what went well, what to improve, action items |
| `backlog-grooming-template.md` | Backlog refinement — story review, estimation, acceptance criteria validation |

## Branch Cleanup and Worktree Hygiene

- Treat branch cleanup as part of sprint closeout, not an ad hoc afterthought.
- Use `instructions/references/governance/workflow-rules.md` for verify → merge → prune → close/report steps.
- Use `skills/git-worktrees/SKILL.md` when the team is working in parallel worktrees.
- Use `scripts/cleanup-branches.ps1` for audit-first stale branch and orphaned branch cleanup.
- Prefer dry-run review before deleting branches or pruning worktrees.

## Agent Pairing

This skill is designed to be used alongside the following agents:

- **sprint-planner** — Drives sprint planning and velocity tracking
- **product-manager** — Provides prioritized stories and acceptance criteria
- **issue-triage** — Feeds triaged and prioritized issues into the backlog
- **retro-facilitator** — Facilitates retrospective ceremonies
- **git-worktrees** — Handles isolated worktrees and cleanup for parallel sprint work

For release-level coordination, pair with the `release-manager` agent.
