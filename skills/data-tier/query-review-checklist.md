# Query Review Checklist

Use this checklist when writing or reviewing database queries. Every item must be verified before a query ships to production. Mark each: ✅ Pass, ❌ Fail (file a GitHub Issue), or N/A.

---

## 1. Correctness

- [ ] The query returns the expected rows for the target use case.
- [ ] Filters on `deleted_at IS NULL` are applied on every query against a soft-delete table.
- [ ] Multi-tenant queries filter on `tenant_id` in the `WHERE` clause — no cross-tenant data leakage.
- [ ] JOINs use the correct join type (`INNER`, `LEFT`, `RIGHT`) for the intended null-handling semantics.
- [ ] Aggregations (`GROUP BY`) include all non-aggregated columns in the `SELECT` clause.
- [ ] Date/time comparisons account for timezone (use UTC consistently).

---

## 2. N+1 Detection

- [ ] No query is executed inside a loop or per-row callback.
- [ ] Related entities are fetched with JOINs, batch queries (`WHERE id IN (...)`) or eager loading — not one query per parent row.
- [ ] If an ORM is in use, generated SQL has been inspected for unintended per-row queries (use query logging in development/test).
- [ ] Nested relationship traversal depth has been assessed. More than two levels of lazy loading is a red flag.

**Rule of thumb:** The number of database queries executed for a request should be fixed (O(1)) relative to the size of the result set, not proportional to it.

---

## 3. Pagination

- [ ] Every collection query has a `LIMIT` clause with a server-enforced maximum.
- [ ] The query cannot be called without pagination parameters (no unbounded `SELECT * FROM table`).
- [ ] Cursor-based pagination is used for large or frequently changing datasets.
- [ ] Offset-based pagination documents the known limitation (instability under concurrent inserts/deletes).
- [ ] The response includes `nextCursor` (or `hasMore` / `totalCount`) so callers can detect end-of-results.

---

## 4. Index Usage

- [ ] Run `EXPLAIN ANALYZE` (or equivalent) on the query and review the output.
- [ ] The query plan shows index scans, not sequential scans, for filtered columns on tables with more than ~1,000 rows.
- [ ] Composite index column order matches the query's filter and sort columns (leftmost prefix rule applies).
- [ ] Columns used in `WHERE`, `JOIN ON`, and `ORDER BY` have indexes unless the table is known to be small and stable.
- [ ] Every foreign key column has an index.
- [ ] The query does not use a function on an indexed column in the `WHERE` clause (e.g., `LOWER(email) = ...` — use a functional index instead).

---

## 5. Select Columns

- [ ] `SELECT *` is not used in production code paths. List only the columns the query actually needs.
- [ ] The selected columns match what the application layer actually uses — no unused columns fetched.
- [ ] Blob or large text columns (`TEXT`, `BYTEA`, `CLOB`) are excluded from list queries and fetched only in detail queries.

---

## 6. Query Safety

- [ ] All user-supplied values are passed as parameterized placeholders — no string concatenation.
- [ ] Dynamic column or table names (if unavoidable) are validated against an allowlist before use.
- [ ] Bulk `IN` clauses have a documented maximum size to prevent excessive query plan cost.

---

## 7. Bulk Operations

- [ ] Batch inserts use multi-row `INSERT` syntax, not one `INSERT` per row.
- [ ] Bulk updates and deletes apply a `WHERE` clause that limits the number of affected rows per batch.
- [ ] Long-running bulk operations are chunked to avoid locking the table for the duration.
- [ ] Bulk operations are wrapped in a transaction when atomicity is required.

---

## 8. Explain Plan Interpretation

Run `EXPLAIN ANALYZE` (PostgreSQL) or `EXPLAIN FORMAT=JSON` (MySQL) and check for:

| Signal | What it means | Action |
|---|---|---|
| `Seq Scan` on large table | No index used — full table scan | Add index on filter column |
| `Nested Loop` with high estimated rows | Possible N+1 inside the query | Restructure with JOIN or batch |
| `Sort` without index | Sort is done in memory or on disk | Add index on the ORDER BY column |
| High `actual rows` vs `estimated rows` | Stale statistics | Run `ANALYZE <table>` |
| `Hash Join` on very large tables | High memory use | Consider tuning `work_mem` or adding index |
| `rows=1` but actual rows > 1000 | Bad cardinality estimate | Check for data distribution skew; update statistics |

---

## Filing a Query Review Issue

When any item above fails, file a GitHub Issue:

```bash
gh issue create \
  --title "[Tech Debt] <short description>" \
  --label "tech-debt,data,performance" \
  --body "## Query Review Finding

**Category:** <N+1 | missing index | SELECT * | unbounded query | unsafe parameterization>
**File:** <path/to/file.ext>
**Query / Line(s):** <line range or query snippet>

### What Failed
<description of the specific problem>

### Impact
<performance risk, correctness risk, or security risk>

### Recommended Fix
<concise recommendation>

### Acceptance Criteria
- [ ] EXPLAIN ANALYZE shows index scan (not seq scan) after fix
- [ ] Query has LIMIT clause
- [ ] No N+1 queries on this path"
```
