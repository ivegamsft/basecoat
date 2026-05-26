---
name: sprint-project-mapper
description: "Use when mapping issue/PR items into meaningful sprint or project groups. USE FOR: clustering by sprint/wave/project tags, split-vs-merge debate, and release-note metric rollups. DO NOT USE FOR: code implementation, issue-by-issue triage cleanup, or deployment execution."
compatibility:
  editors:
    - vscode
  platforms:
    - github
metadata:
  category: "Project Management & Planning"
  tags: ["sprint", "wave", "project", "clustering", "release-notes", "metrics", "portfolio"]
  maturity: "production"
  audience: ["developers", "tech-leads", "engineering-managers", "program-managers"]
allowed-tools: ["bash", "git", "gh"]
---

# Sprint/Project Mapper Skill

Use this skill to convert scattered issues and PRs into statistically meaningful project groups for planning, reporting, and release notes.

## Use Cases

- Cluster items with similar tags (`sprint:*`, `wave:*`, `project:*`, `area/*`) into coherent project groups.
- Debate whether groups should be split or merged before metric reporting.
- Compute quality metrics: issues, PRs, LOC delta, cycle time, closure ratio, blocker density.
- Generate release-note-ready summaries only for groups that pass significance thresholds.

## Reference Files

| File | Purpose |
|---|---|
| [`references/mapping-workflow.md`](references/mapping-workflow.md) | End-to-end grouping and debate workflow |
| [`references/metrics-formulas.md`](references/metrics-formulas.md) | Metric definitions and significance rules |
| [`references/release-notes-template.md`](references/release-notes-template.md) | Structured release-note output template |

## Scripts

| Script | Purpose |
|---|---|
| [`scripts/map-projects.ps1`](scripts/map-projects.ps1) | PowerShell mapper for Windows/macOS/Linux with `gh` CLI (`-NoLabelWarning` suppresses unmapped-label warning) |
| [`scripts/map-projects.sh`](scripts/map-projects.sh) | Bash equivalent for Linux/macOS |

## Group Significance (Default)

A group is meaningful if it satisfies at least one breadth threshold and one activity threshold:

- Breadth: `issues >= 5` OR `merged_prs >= 3`
- Activity: `loc_changed >= 200` OR `activity_span_days >= 7` OR explicit sprint/milestone tag

Groups failing thresholds are merged into nearest valid group when similarity >0.65, else reported as residual.

Release-note output requires at least one linked merged PR; significant groups without linked PRs are reported under linkage-gap audit.

## Agent Pairing

- `sprint-project-mapper` for project grouping and debate outcomes.
- `backlog-burndown` for velocity and spillover analysis.
- `issue-triage` for quality cleanup before metric baselining.
- `sprint-planner` to convert mapped groups into next-sprint commitments.
