# Guardrail: Database Deployment Concurrency

> **Rule:** Any workflow that runs database migrations or schema changes **MUST** set `cancel-in-progress: false` in its concurrency group.

## Why

Cancelling a running database deployment can leave the database in a **partially-migrated, corrupted state**. Unlike application code — where a cancelled deploy simply means the old version keeps running — a half-applied migration may have:

- Created tables or columns without populating them
- Dropped or renamed objects that downstream queries depend on
- Left migration-tracking metadata (e.g., `__MigrationHistory`, `schema_migrations`) out of sync with the actual schema
- Applied irreversible DDL (e.g., `DROP COLUMN`) without completing compensating steps

A new deployment triggered against this broken state will likely fail or make the corruption worse. Recovery requires manual intervention, not just re-running the pipeline.

## Required Pattern

```yaml
concurrency:
  group: db-deploy-${{ github.ref }}
  cancel-in-progress: false  # NEVER cancel DB migrations
```

Every workflow (or reusable workflow / composite action) that performs database work **must** include a concurrency group with `cancel-in-progress: false`. If the workflow already has a concurrency group for another reason, ensure `cancel-in-progress` is explicitly set to `false`.

## What Counts as a Database Deployment

This guardrail applies whenever a workflow performs any of the following:

| Activity | Examples |
|---|---|
| **Schema migrations** | EF Core `dotnet ef database update`, Flyway `migrate`, Liquibase `update`, Alembic `upgrade`, Rails `db:migrate` |
| **Schema changes** | Raw DDL scripts (`ALTER TABLE`, `CREATE INDEX`, `DROP COLUMN`) executed via `sqlcmd`, `psql`, `mysql`, or similar |
| **Seed scripts** | Data population scripts that insert or upsert reference/lookup data |
| **Stored procedure deployments** | Deploying or altering stored procedures, functions, views, or triggers |
| **Database project publishes** | SSDT `SqlPackage /Action:Publish`, DACPAC deployments |

If you are unsure whether your workflow qualifies, **treat it as a DB deployment** and set `cancel-in-progress: false`.

## Remediation if a Migration Is Cancelled

If a database migration is interrupted (cancelled, timed out, or crashed), follow these steps:

### 1. Detect Partial Migrations

- **Check migration history table:** Compare the last recorded migration in `__MigrationHistory` / `schema_migrations` / equivalent against the expected target migration.
- **Inspect schema diff:** Run your migration tool's status command (e.g., `dotnet ef migrations list`, `flyway info`, `alembic current`) and compare against the actual database schema.
- **Look for orphaned objects:** Search for tables, columns, or indexes that exist in the database but don't correspond to any completed migration.

### 2. Rollback Strategies

| Strategy | When to Use |
|---|---|
| **Re-run the migration** | If the migration tool supports idempotent operations or the failed migration left no partial changes (e.g., the entire migration was wrapped in a transaction). |
| **Manual rollback script** | If the migration tool cannot safely re-run, write a targeted SQL script to undo the partial changes. Test it against a copy of the database first. |
| **Restore from backup** | If the damage is extensive or the schema state is unknown. Requires that pre-migration backups are taken automatically (they should be). |
| **Mark migration as applied** | Only if you have manually verified the schema matches the expected post-migration state. Use your tool's force/mark command (e.g., `flyway repair`, `alembic stamp`). |

### 3. Prevent Recurrence

- Confirm the workflow has `cancel-in-progress: false`.
- Add a pre-migration backup step if one does not already exist.
- Wrap migrations in transactions where the database engine supports transactional DDL (e.g., PostgreSQL).
- Add a post-migration health check step that validates schema state before the workflow completes.

## References

- [GitHub Actions concurrency documentation](https://docs.github.com/en/actions/using-jobs/using-concurrency)
- Governance: [`instructions/basecoat-20-lang-governance.instructions.md`](/instructions/basecoat-20-lang-governance.instructions.md)
