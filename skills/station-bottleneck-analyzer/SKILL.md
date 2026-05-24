---
name: station-bottleneck-analyzer
description: "Use when analyzing takt-time JSON to calculate queue length and throughput by station, rank bottlenecks, and draft the weekly bottleneck report issue. USE FOR: station-level queue pressure, throughput trends, bottleneck ranking, and weekly issue filing. DO NOT USE FOR: dispatching work or changing routing policy."
compatibility:
  editors:
    - vscode
  platforms:
    - github
metadata:
  category: "Process"
  tags: ["takt-time", "queue", "throughput", "bottleneck", "issue-reporting"]
  maturity: "beta"
  audience: ["developers", "project-managers", "tech-leads"]
allowed-tools: ["bash", "git", "gh", "grep", "find"]
visibility: "internal"
---
# Station Bottleneck Analyzer Skill

Analyze takt-time exports to identify the stations that are backing up flow.

## Workflow

1. Read the weekly takt-time JSON export.
2. Group events by station and time window.
3. Calculate queue length and throughput for each station.
4. Rank stations by queue pressure, low throughput, and sustained dwell time.
5. Draft or update the weekly bottleneck report issue.

## Reference Files

| File | Purpose |
|---|---|
| [`references/analysis-workflow.md`](references/analysis-workflow.md) | Calculation flow and ranking rules |
| [`references/weekly-report-template.md`](references/weekly-report-template.md) | Issue template and filing checklist |

## Agent Pairing

- `takt-time-tracker` for upstream dwell-time exports.
- `issue-triage` for report follow-up and labeling after filing.
