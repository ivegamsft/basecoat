# Data Pack Contract

Each generated pack should include:

```text
local-dev/data-pack/
  artifacts/
    <scenario>/
      manifest.yaml
      postgres/
      sqlserver/
      cosmos/
```

## Manifest fields

- `version`: contract version (for example `1`).
- `scenario`: `minimal`, `integration`, or `perf-lite`.
- `stores`: list of active stores included in this pack.
- `reset_mode`: `reuse-volumes` or `drop-and-reseed`.
- `generated_at_utc`: ISO 8601 timestamp. The template ships an explicit
  `__REPLACE_WITH_CURRENT_UTC_ISO8601__` placeholder that `generate` must
  substitute with the current UTC time; `validate` rejects a pack that still
  carries the unreplaced placeholder.
- `supported_operations`: lifecycle modes allowed for this pack (`generate`, `validate`, `update`, `delete`).
- `checks`: expected verification thresholds (rows/docs per dataset).

## Store-specific payload rules

1. PostgreSQL: SQL artifacts must be idempotent (`CREATE TABLE IF NOT EXISTS`, upsert patterns where possible).
2. SQL Server: SQL artifacts should support reruns without destructive failures.
3. Cosmos: container definition + items with explicit partition key fields.

## Determinism rules

- Stable sample IDs across runs.
- Stable sort order in JSON arrays.
- No environment-specific secrets in pack files.
