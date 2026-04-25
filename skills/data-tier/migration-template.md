# Migration Template

Use this template for every database migration file. Fill in all sections before writing the SQL. A migration without a `down` block is not complete.

---

## Migration Header

```
Migration ID:    <YYYYMMDDHHMMSS>_<short_description>
Description:     <one sentence describing what this migration does>
Ticket/Issue:    #<issue number>
Author:          <name or alias>
Created:         YYYY-MM-DD
Zero-downtime:   Yes / No (explain why not if No)
Reversible:      Yes / No (explain why not if No)
```

---

## Pre-Migration Checklist

Complete before applying this migration in any environment.

- [ ] Migration has been reviewed by at least one other engineer.
- [ ] The `down` block has been tested in a local or staging environment.
- [ ] Destructive operations (`DROP COLUMN`, `DROP TABLE`, `TRUNCATE`) have a confirmed backup.
- [ ] Large table operations have a plan for avoiding lock contention (batching, `CONCURRENTLY`, maintenance window).
- [ ] Application code is already forward-compatible with the new schema (feature flag, dual-read/write, or deploy ordering confirmed).
- [ ] This migration does not change an existing column type without a compatibility plan.

---

## Up Migration

```sql
-- Migration: <YYYYMMDDHHMMSS>_<short_description>
-- Description: <one sentence>
-- Reversible: Yes

BEGIN;

-- Step 1: <describe what this step does>
-- Zero-downtime note: Adding a nullable column first; constraint added in a subsequent migration.
ALTER TABLE <table_name>
  ADD COLUMN <column_name> <type> NULL;

-- Step 2: <describe what this step does>
CREATE INDEX CONCURRENTLY IF NOT EXISTS <index_name>
  ON <table_name> (<column_name>);

-- Step 3: <describe what this step does>
-- Example: add a new table
CREATE TABLE IF NOT EXISTS <new_table_name> (
  id          UUID          NOT NULL DEFAULT gen_random_uuid(),
  <fk_column> UUID          NOT NULL,
  <column>    VARCHAR(255)  NOT NULL,
  created_at  TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ   NOT NULL DEFAULT NOW(),

  CONSTRAINT <new_table_name>_pkey PRIMARY KEY (id),
  CONSTRAINT <new_table_name>_<fk_column>_fkey
    FOREIGN KEY (<fk_column>) REFERENCES <referenced_table>(id) ON DELETE RESTRICT
);

CREATE INDEX IF NOT EXISTS <new_table_name>_<fk_column>_idx
  ON <new_table_name> (<fk_column>);

COMMIT;
```

---

## Down Migration (Rollback)

```sql
-- Rollback for: <YYYYMMDDHHMMSS>_<short_description>
-- Warning: rolling back drops <new_table_name>. Ensure no data has been written before rolling back.

BEGIN;

-- Reverse Step 3
DROP TABLE IF EXISTS <new_table_name>;

-- Reverse Step 2
DROP INDEX CONCURRENTLY IF EXISTS <index_name>;

-- Reverse Step 1
ALTER TABLE <table_name>
  DROP COLUMN IF EXISTS <column_name>;

COMMIT;
```

---

## Rollback Plan

Document what happens if this migration needs to be reversed in production.

| Scenario | Action |
|---|---|
| Migration fails mid-run | Transaction rolls back automatically (if transactional DDL is supported). Re-apply after fix. |
| Migration applied but application has a bug | Run the down migration. Redeploy previous application version. |
| Data was written in the new schema before rollback | Requires manual data migration to reverse. Contact DBA before proceeding. |

---

## Zero-Downtime Notes

| Operation | Zero-Downtime Strategy |
|---|---|
| Adding a column | Add as `NULL` first. Backfill with a background job. Add `NOT NULL` constraint in a later migration once all rows are populated. |
| Adding an index | Use `CREATE INDEX CONCURRENTLY` to avoid locking the table. |
| Renaming a column | (1) Add new column. (2) Dual-write. (3) Migrate reads to new column. (4) Drop old column in a later release. |
| Dropping a column | (1) Stop reading/writing in application code (deploy first). (2) Drop column in this migration. |
| Changing a column type | Never alter type in place. Add a new column with the new type, migrate data, then drop the old column. |

---

## Post-Migration Validation Queries

Run these queries after applying the migration to confirm the expected state.

```sql
-- Verify new column exists
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = '<table_name>'
  AND column_name = '<column_name>';

-- Verify new index exists
SELECT indexname, indexdef
FROM pg_indexes
WHERE tablename = '<table_name>'
  AND indexname = '<index_name>';

-- Verify new table exists and row count is as expected
SELECT COUNT(*) FROM <new_table_name>;
```
