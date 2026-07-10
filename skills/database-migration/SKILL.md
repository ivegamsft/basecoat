---
name: database-migration
compatibility: [github-copilot-cli]
description: "Zero-downtime database migration patterns, blue-green cutovers, and rollback strategy guidance for production data changes. USE FOR: plan expand-contract schema migration, design blue-green database cutover, write Flyway versioned migration and undo scripts, prepare rollback plan for production schema change, validate zero-downtime database release process. DO NOT USE FOR: ad hoc query tuning only, application feature design, non-production toy database setup."
category: data
metadata:
  category: data
  maturity: stable
  audience:
    - developer
allowed-tools: []
---
# Database Migration

Zero-downtime schema migration, versioning, and rollback for production databases.

## Reference Files

| File | Contents |
|------|----------|
| [`references/zero-downtime-patterns.md`](references/zero-downtime-patterns.md) | Expand-contract phases, blue-green cutover, rollback strategies |
| [`references/schema-versioning.md`](references/schema-versioning.md) | Flyway structure, migration format, undo scripts, CI/CD |
| [`references/operations-checklist.md`](references/operations-checklist.md) | Pre-migration checklist, monitoring metrics, quick-start steps |
| [`references/entra-sql-auth.md`](references/entra-sql-auth.md) | Entra-only auth, managed identity connection strings, common errors |

## Key Patterns

| Pattern | Rule |
|---------|------|
| Expand-contract | Add column → migrate data → drop old column across 3 separate deploys |
| Blue-green | Two identical DBs; switch traffic after 24–48 h; keep Blue ≥30 days |
| Dual-write | Write to both DBs; read from primary; zero data loss rollback |
| Flyway undo | `U{version}__rollback.sql` paired with every `V{version}__migrate.sql` |
| Validate first | Run `flyway validate` in CI before every `flyway migrate` |
