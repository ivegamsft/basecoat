# Data Tier Agent — Detail Reference

Full schema design conventions, migration zero-downtime strategies, query pattern rules,
indexing strategy, caching approach, and data integrity guidance for
`agents/basecoat-80-data-data-tier.agent.md`.

## Schema Design

### Naming conventions

- Table names: plural snake_case (`orders`, `order_items`, `user_accounts`).
- Column names: singular snake_case (`created_at`, `user_id`, `is_active`).
- Primary keys: `id` (surrogate, auto-increment or UUID). Never use a natural key as the primary key unless the domain explicitly requires it.
- Foreign keys: `<referenced_table_singular>_id` (e.g., `order_id`, `user_id`).
- Timestamps: include `created_at` and `updated_at` on every table. Use UTC.

### Data types

- Use the most restrictive type that fits the data. Do not use `TEXT` for a status enum with five known values.
- Store monetary values as `DECIMAL(19,4)` or integer cents — never `FLOAT`.
- Store timestamps as UTC with timezone awareness.
- Use `BOOLEAN` for binary flags, not `TINYINT(1)` or string `'Y'/'N'`.

### Normalization and denormalization

- Default to 3NF for write-heavy transactional data.
- Denormalize intentionally and document the tradeoff when a join is prohibitively expensive at scale.
- Use materialized views or summary tables for complex aggregations — do not pre-compute in application code.

### Constraints

- Enforce referential integrity with foreign key constraints unless the database or scale genuinely prevents it (document why when skipping).
- Use `NOT NULL` constraints wherever a null value has no semantic meaning.
- Use `CHECK` constraints for domain-level invariants (e.g., `amount > 0`, `status IN ('pending', 'active', 'closed')`).

## Migrations

- Every migration file has an `up` block (apply) and a `down` block (rollback). A migration without a rollback is not complete.
- Never modify an already-applied migration. Create a new migration instead.
- Zero-downtime strategies for common operations:
  - Adding a column: add nullable first, backfill, add constraint in a subsequent migration.
  - Renaming a column: add the new column, dual-write, migrate reads, drop the old column across separate migrations.
  - Dropping a column: mark deprecated in code, stop reading/writing, then drop in a later release.
- Run migrations in a transaction when the database supports transactional DDL.
- Test the `down` migration in CI as well as the `up`.

## Query Patterns

### N+1 detection

- Never query inside a loop. Use joins, batch queries, or eager loading to retrieve related data in a fixed number of queries.
- If an ORM is used, review generated SQL for unexpected per-row queries.

### Pagination

- All collection queries must be paginated. Default page size must be defined and enforced server-side.
- Use cursor-based pagination for large or frequently changing datasets. Offset pagination is acceptable for small, stable datasets.
- Never allow unbounded `SELECT * FROM table` in production paths.

### Bulk operations

- Use batch inserts, updates, and deletes when operating on multiple rows.
- Apply rate limiting or chunking for bulk operations that could block other queries.

## Indexing Strategy

- Index every foreign key column unless query patterns confirm it is never used in a join or filter.
- Create covering indexes for the most frequent query patterns (include the columns in the `SELECT` list alongside the filter columns).
- Avoid over-indexing write-heavy tables — every index adds write overhead.
- Review the query execution plan (`EXPLAIN` / `EXPLAIN ANALYZE`) for any query that touches more than 10,000 rows.
- Do not use `SELECT *` — select only the columns the query actually needs.

## Caching

- Apply caching at the data access layer, not inside service logic. The repository is the right place for cache interaction.
- Use cache-aside: read from cache, fall back to database on miss, populate cache on miss.
- Define TTL based on acceptable staleness for the data type. Do not cache without a TTL.
- Invalidate on write — don't rely solely on TTL expiry for correctness-critical data.
- Cache keys must include all discriminating factors (tenant ID, user ID, filter params) to prevent cross-tenant data leaks.

## Data Integrity

- Prefer hard deletes unless audit or recovery requirements mandate soft deletes.
- If soft deletes are used, add `deleted_at TIMESTAMP NULL` and filter `WHERE deleted_at IS NULL` at the query layer, not in application logic.
- Audit columns (`created_by`, `updated_by`) must be populated server-side, never trusted from client input.

## GitHub Issue Filing Table

| Finding | Labels |
|---|---|
| Query executed inside a loop (N+1) | `tech-debt,data,performance` |
| Missing index on a foreign key column | `tech-debt,data,performance` |
| `SELECT *` in a production query path | `tech-debt,data,performance` |
| Migration with no `down` / rollback block | `tech-debt,data,reliability` |
| Hardcoded ID or environment-specific value in a query or migration | `tech-debt,data` |
