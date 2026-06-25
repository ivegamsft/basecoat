---
name: data-tier
compatibility: [github-copilot-cli]
description: "Use when designing schemas, writing migrations, reviewing queries, or defining repository and indexing patterns for an application's data layer. USE FOR: design a relational schema, write migration with rollback support, review SQL for N+1 or missing indexes, build a data dictionary, define repository or data access patterns. DO NOT USE FOR: business UI copywriting, infrastructure-only deployment tasks, debugging frontend CSS."
---
# Data Tier Skill

Schema design, database migrations, query review, indexing strategy, and data access pattern definition.

## Templates in This Skill

| Template | Purpose |
|---|---|
| `schema-design-template.md` | Schema design: entities, attributes, relationships, constraints, and indexes |
| `migration-template.md` | Migration scaffold with up/down blocks, rollback plan, and zero-downtime notes |
| `query-review-checklist.md` | Query review: N+1 check, index usage, pagination, explain plan guidance |
| `data-dictionary-template.md` | Data dictionary: table, column, type, nullable, description, and example values |

## Agent Pairing

Use with `data-tier` agent. Schema changes require coordination with `backend-dev` to keep repository patterns aligned.
