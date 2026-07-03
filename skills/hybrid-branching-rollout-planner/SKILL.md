---
name: hybrid-branching-rollout-planner
description: "Creates a dependency-aware rollout plan for adopting hybrid branching in BaseCoat or downstream repos, including baseline measurement design. USE FOR: phased migration plans, dependency and impact mapping, consumer profile rollout planning, and baseline/measurement planning. DO NOT USE FOR: changing live branch protections, executing workflow deployments, or writing product code."
compatibility:
  - github-copilot-cli
visibility: public
category: operations
metadata:
  category: flow-governance
  domain: branching-strategy
  maturity: production
  audience:
    - maintainer
    - platform-engineer
    - delivery-manager
allowed-tools:
  - git
  - gh
  - bash
---
# Hybrid Branching Rollout Planner Skill

Use this skill to generate an implementation-ready plan without executing changes.

## Workflow

1. Capture current-state constraints and chosen target profile.
2. Build dependency graph across policy, workflow, and governance changes.
3. Define phased rollout with explicit entry and exit criteria per phase.
4. Produce change-impact matrix for engineering, reliability, and operations.
5. Add baseline and post-change measurement plan with stop/go thresholds.
6. Produce issue-ready task breakdown for BaseCoat and downstream repos.

## Output contract

Every plan must include:

1. Phase plan with owners and sequencing.
2. Dependency and impact matrix.
3. Risk and rollback plan.
4. Baseline and measurement protocol.
5. Decision gates for expansion beyond pilot scope.

## References and templates

- `references/dependency-impact-checklist.md`
- `templates/rollout-plan-template.md`
- `templates/baseline-measurement-template.md`
