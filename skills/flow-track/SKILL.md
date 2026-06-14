---
name: flow-track
description: "Use when tracking PR/merge/CI flow metrics over time and generating metric-backed corrective suggestions. USE FOR: trend scorecards, regression alerts, threshold monitoring, and action recommendations tied to metrics. DO NOT USE FOR: one-off static audits without history, ad hoc coding work, or replacing SRE incident procedures."
compatibility:
  - agent:flow-tracker
  - agent:flow-auditor
metadata:
  domain: flow-governance
  maturity: production
  audience:
    - maintainer
    - ops-lead
allowed-tools:
  - bash
  - git
  - gh
visibility: public
---

# Flow Track Skill

Use this skill to monitor delivery flow continuously and trigger early corrective
guidance when metrics trend in the wrong direction.

## When to Use

- Producing weekly or sprint flow scorecards
- Detecting sustained drift in queue delay or PR age
- Tracking CI waste and flaky rerun trends over time
- Suggesting corrective actions based on metric movement

## Workflow

1. Gather time-series flow metrics.
2. Compare current values to baseline and target thresholds.
3. Flag regressions and identify correlated flow-stage changes.
4. Propose corrective actions with expected KPI impact.
5. Publish trend report and escalation notes.

## Output

- Time-based flow scorecard
- Regression and threshold alert set
- Action recommendations with expected KPI lift

## Related Assets

- `agents/flow-tracker.agent.md`
- `skills/flow-audit/SKILL.md`
- `skills/flow-suggest/SKILL.md`
