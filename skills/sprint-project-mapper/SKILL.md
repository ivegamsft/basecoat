---
name: sprint-project-mapper
description: "Use when mapping issue/PR items into meaningful sprint or project groups. USE FOR: clustering by sprint/wave/project tags, split-vs-merge debate, and release-note metric rollups. DO NOT USE FOR: code implementation, issue-by-issue triage cleanup, or deployment execution."
---

# Sprint/Project Mapper Skill

Map issues/PRs into meaningful sprint or project groups for planning, reporting, and release notes.

## Use Cases

- Cluster items with similar tags (`sprint:*`, `wave:*`, `project:*`, `area/*`) into coherent project groups.
- Debate whether groups should be split or merged before metric reporting.
- Compute quality metrics: issues, PRs, LOC delta, cycle time, closure ratio, blocker density.
- Generate release-note-ready summaries only for groups that pass significance thresholds.
- Audit and remediate missing `sprint:*` / `wave:*` labels on merged PRs before release-note cut.

## References

- [`references/mapping-workflow.md`](references/mapping-workflow.md)
- [`references/metrics-formulas.md`](references/metrics-formulas.md)
- [`references/release-notes-template.md`](references/release-notes-template.md)
- [`scripts/map-projects.ps1`](scripts/map-projects.ps1)
- [`scripts/map-projects.sh`](scripts/map-projects.sh)

## Group Significance (Default)

A group is meaningful if it satisfies at least one breadth threshold and one activity threshold:

- Breadth: `issues >= 5` OR `merged_prs >= 3`
- Activity: `loc_changed >= 200` OR `activity_span_days >= 7` OR explicit sprint/milestone tag

Groups failing thresholds are merged into nearest valid group when similarity >0.65, else reported as residual.

Release-note output requires at least one linked merged PR; significant groups without linked PRs are reported under linkage-gap audit.

## Label Hygiene Protection

To protect release-note consistency, run a label hygiene pass before mapping output is finalized:

1. Detect merged PRs in scope missing both `sprint:*` and `wave:*`.
2. Report the missing-label list with PR numbers and owners.
3. Block "final" grouping output until each PR has a label or an explicit waiver note.

### Label hygiene command

```bash
gh pr list --state merged --limit 200 --json number,title,author,labels \
  | jq '[.[] | select((.labels | map(.name | test("^sprint:|^wave:")) | any) | not)]'
```

## Agent Pairing

- `sprint-project-mapper`
- `backlog-burndown`
- `issue-triage`
- `sprint-planner`
