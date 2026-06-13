---
name: copilot-usage-analytics
description: "Use when estimating Copilot CLI session cost, analyzing model routing efficiency, or mapping available usage APIs. USE FOR: estimate Copilot session cost, analyze expensive agent dispatches, recommend cheaper model routing, audit Copilot workflow token usage, document GitHub Copilot usage APIs. DO NOT USE FOR: general product analytics dashboards, application performance monitoring, non-Copilot billing disputes."
compatibility: GHCP
---

# Copilot Usage Analytics Skill

Estimate per-session Copilot CLI cost, analyze model-routing efficiency, track agent dispatch
patterns, and document which GitHub Copilot usage APIs exist.

## Reference Files

| File | Contents |
|------|----------|
| [`references/api-landscape-detail.md`](references/api-landscape-detail.md) | Full API source table (metrics/billing/Power BI), response format, model routing guidance table |
| [`references/cost-estimation-guide.md`](references/cost-estimation-guide.md) | 6-step estimation workflow, guardrails, agent pairing |

## Templates in This Skill

| Template | Purpose |
|---|---|
| `templates/session-cost-estimate-template.md` | Per-session cost breakdown by dispatch, model, and estimated token usage |
| `templates/model-routing-recommendation-template.md` | Recommendations for right-sizing model selection per task type |
| `templates/api-landscape.md` | Reference map of GitHub Copilot usage APIs — what exists, what is missing, and workarounds |
| `templates/usage-report.md` | Automated-style usage report with Handlebars placeholders for tooling integration |
