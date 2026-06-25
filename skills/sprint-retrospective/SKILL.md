---
name: sprint-retrospective
compatibility: [github-copilot-cli]
description: "Use when generating evidence-based sprint retrospectives with metrics, timelines, and actionable improvement tips. USE FOR: create sprint retrospective document, summarize merged PR and issue metrics, analyze time-to-merge trends, identify rework or PR size patterns, produce improvement actions from sprint data. DO NOT USE FOR: sprint planning or estimation, writing code changes."
---
# Sprint Retrospective Skill

Knowledge pack for the `@sprint-retrospective` agent — templates, metrics formulas, and a tips taxonomy for generating structured retrospective documents.

## Reference Files

| File | Contents |
|------|----------|
| [`references/template-formulas.md`](references/template-formulas.md) | Retrospective document template, metrics formulas, tips taxonomy, GitHub API queries |

## Key Metrics (Quick Reference)

| Metric | Formula |
|--------|---------|
| Time-to-merge | `PR merged_at − PR created_at` (exclude draft time) |
| Parallel dispatch ratio | `max concurrent open PRs / total PRs` |
| Velocity | `issues closed / calendar days` |
| Churn rate | `lines removed / lines added` — high churn signals rework |


