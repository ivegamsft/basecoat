---
name: flow-audit
compatibility: [github-copilot-cli]
description: "Use when auditing PR/merge/CI delivery flow for bottlenecks and governance drift. USE FOR: merge queue bottleneck scans, stale PR analysis, CI waste detection, throughput baseline creation, and severity-ranked findings. DO NOT USE FOR: implementing product features, force-merging changes, or direct workflow mutation without review."

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
# Flow Audit Skill

Use this skill to baseline repository delivery health and identify where PR and
CI flow is slowing down.

## When to Use

- Auditing merge queue delay, PR age, and stale branch pressure
- Measuring CI cancellation waste and rerun/flaky overhead
- Ranking bottlenecks by impact on approved-to-merged time
- Building an evidence set before proposing remediations

## Workflow

1. Gather PR lifecycle and CI execution signals.
2. Map delays to intake, review, queue, and merge stages.
3. Score each bottleneck by severity and blast radius.
4. Separate transient incidents from structural policy gaps.
5. Produce an issue-ready findings summary.

## Mandatory exports

Every flow audit must include exported evidence for:

- Branch protection configuration
- Required status checks
- Environment protection rules
- Merge queue configuration
- Runner group permissions
- Who can dispatch production workflows

## Output

- Bottleneck findings table
- Severity-ranked remediation candidates
- Baseline KPI snapshot for tracking
- Audit export package for governance review

## Related Assets

- `agents/flow-auditor.agent.md`
- `agents/flow-tracker.agent.md`
- `skills/flow-track/SKILL.md`


