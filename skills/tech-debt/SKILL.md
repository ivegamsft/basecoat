---
name: tech-debt
description: "Use when inventorying, scoring, budgeting, or reducing technical debt across a repo or team. USE FOR: build technical debt register, rank cleanup work with RICE, reserve sprint capacity for remediation, compare debt items by impact and effort, track debt amortization over time. DO NOT USE FOR: implementing feature work directly, emergency production incident response."
compatibility:
  - GHCP
---
# Technical Debt Management

Inventory, score, budget, and reduce technical debt using RICE prioritization and sprint allocation.

## Reference Files

| File | Contents |
|------|----------|
| [`references/assessment.md`](references/assessment.md) | Debt register template, categories, RICE scoring rubric, visualization templates |
| [`references/remediation.md`](references/remediation.md) | Budget framework, amortization tracking, governance rules, quarterly review checklist |

## Core Concepts

| Concept | Definition |
|---------|------------|
| Debt Register | Centralized list with ID, category, effort, impact, RICE score, status, owner |
| RICE Score | (Reach × Impact × Confidence) / Effort — higher = higher priority |
| Budget | 5–30% of sprint capacity reserved for debt, scaled by team maturity |
| Amortization | Target: net debt reduction ≥ 30 SP/quarter |

## Key Rules

- Adding debt requires tech lead approval and a remediation plan
- Never let debt backlog exceed 6 months of capacity
- No new features on top of P1 debt
