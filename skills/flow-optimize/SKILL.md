---
name: flow-optimize
compatibility: [github-copilot-cli]
description: "Use when creating a phased optimization plan that combines audit findings and suggested fixes. USE FOR: flow optimization roadmaps, CI tier tuning, merge policy improvements, and KPI-target planning. DO NOT USE FOR: reactive incident firefighting, direct feature coding, or unmanaged policy rollouts."
category: flow-governance

metadata:
  category: flow-governance
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
# Flow Optimize Skill

Use this skill to convert audit and recommendation artifacts into a concrete,
phase-based improvement program.

## When to Use

- Building an optimization roadmap from flow findings and suggested fixes
- Tuning merge queue policy, CI tiers, and stale PR handling together
- Defining short-cycle checkpoints and expected KPI movement
- Planning rollout and rollback safety for governance changes

## Workflow

1. Use `flow-audit` outputs to confirm baseline constraints.
2. Use `flow-suggest` outputs to choose high-leverage interventions.
3. Build phased plan with stabilization and hardening gates.
4. Attach KPI targets and rollback criteria to each phase.
5. Publish owner-ready implementation plan.

## Output

- Phased optimization plan
- Policy and workflow change recommendations
- KPI and checkpoint matrix

## Related Assets

- `agents/flow-optimizer.agent.md`
- `skills/flow-audit/SKILL.md`
- `skills/flow-suggest/SKILL.md`
