---
name: flow-suggest
description: "Use when translating flow-audit findings into prioritized fixes and issue-ready recommendations. USE FOR: remediation prioritization, high-confidence auto-issue creation, issue drafting, acceptance-criteria definition, and execution-wave planning. DO NOT USE FOR: direct code implementation, unreviewed governance enforcement, or broad roadmap planning without audit input."
compatibility:
  - agent:flow-suggester
  - agent:flow-optimizer
metadata:
  category: flow-governance
  domain: flow-governance
  maturity: production
  audience:
    - maintainer
    - triager
allowed-tools:
  - bash
  - git
  - gh
visibility: public
---

# Flow Suggest Skill

Use this skill after a flow audit to convert findings into practical fixes with
clear implementation targets.

## When to Use

- Converting audit findings into issue-ready backlog items
- Auto-creating high-confidence issues while drafting lower-confidence items
- Prioritizing queue, CI, and stale-branch remediation work
- Defining measurable acceptance criteria and KPI impact targets
- Sequencing improvements into low-risk waves

## Workflow

1. Ingest findings from `flow-audit`.
2. Normalize remediation options and estimate impact.
3. Prioritize fixes by urgency, effort, and dependency risk.
4. Auto-create high-confidence issues; draft medium-confidence candidates.
5. Publish a sequenced recommendation slate.

## Output

- Prioritized fix list
- Issue-ready recommendation drafts
- Suggested execution waves

## Related Assets

- `agents/flow-suggester.agent.md`
- `skills/flow-audit/SKILL.md`
- `skills/flow-optimize/SKILL.md`
