---
name: flow-admission-control
description: "Use when defining capacity-aware intake and merge-queue admission rules to prevent queue overload. USE FOR: WIP limit policy, merge-ready admission criteria, stale PR expiration rules, and load-shedding strategy. DO NOT USE FOR: manual override of required checks, arbitrary PR closure without policy, or unrelated feature planning."
compatibility:
  - agent:flow-admission-controller
  - agent:flow-optimizer
metadata:
  domain: flow-governance
  maturity: production
  audience:
    - maintainer
    - release-manager
allowed-tools:
  - bash
  - git
  - gh
visibility: public
---

# Flow Admission Control Skill

Use this skill to keep repository flow stable by controlling how much work enters
review and merge paths relative to available capacity.

## When to Use

- Defining max open-PR, reviewer, and queue-depth limits
- Creating merge-ready admission criteria and priority lanes
- Setting stale/conflict auto-rebase and regeneration policy
- Designing load-shedding and fairness behavior during spikes

## Workflow

1. Assess intake pressure versus reviewer and CI capacity.
2. Define quantitative WIP and queue limits by stage.
3. Set admission rules and priority policy.
4. Define stale/conflict remediation timers and actions.
5. Publish enforcement and escalation playbook.

## Output

- Admission and WIP policy matrix
- Stale/conflict lifecycle rules
- Escalation and load-shedding guidance

## Related Assets

- `agents/flow-admission-controller.agent.md`
- `skills/flow-optimize/SKILL.md`
- `skills/flow-track/SKILL.md`

