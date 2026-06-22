---
name: queue-rebalancer
description: "Use when active blockers are buried in the queue and work must be reshuffled by dependency to unblock builds quickly. USE FOR: blocker-first ordering, focused unblock group formation, cherry-picking minimal fixes, and post-unblock return to normal order. DO NOT USE FOR: proposing standalone feature roadmaps, broad redesign work, or promoting feature changes without tests and check-in."
compatibility:
  - GHCP
category: workflow
metadata:
  category: workflow
  maturity: alpha
  audience:
    - developer
allowed-tools: []
---
# Queue Rebalancer Skill

Use this skill to run a fast unblock lane when older PRs or issues are breaking downstream work.

## Workflow

1. Build a dependency graph from open PRs and issues (`Blocks`, `Blocked by`, `Depends on`, linked close references).
2. Rank blockers by unblock impact (most blocked dependents first).
3. Form a small unblock group from both issue queue and PR queue.
4. Cherry-pick or merge only minimal fix commits required to unblock.
5. Run targeted tests and verify blocker resolution.
6. Return remaining work to regular dependency order.

## Unblock Group Rules

- Group only contains items that unblock active breakage.
- Prefer existing fix commits over new broad changes.
- Keep scope narrow and execution speed high.
- Do not include independent non-blocking backlog items.

## Scope and Safety Gates

- If a proposed fix expands into new feature scope, pause and request explicit human check-in before proceeding.
- Do not redesign or spec a brand-new feature set while executing unblock work.
- Feature-introducing changes require matching tests before promotion.
- If tests are missing, mark as blocked (`gate:no-tests`) and keep out of the unblock group.

## Output

- Reordered blocker-first queue
- Unblock group list (issues + PRs selected for fast lane)
- Gated items requiring tests or explicit check-in
- Verification summary and handoff back to regular queue order
