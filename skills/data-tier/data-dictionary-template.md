# Data Dictionary Template

Use this template to document every table and column in the service's schema. Keep this document in source control alongside migrations. Update it whenever a migration adds, changes, or removes columns.

---

## Data Dictionary Overview

| Field | Value |
|---|---|
| **Service / Domain** | `<service name>` |
| **Database** | `<database name>` |
| **Schema** | `public` / `<schema name>` |
| **Last Updated** | `YYYY-MM-DD` |
| **Migration Baseline** | `<last migration ID applied>` |

---

## Table: `<table_name>`

**Description:** One sentence describing what this table stores and its role in the domain.

**Retention policy:** `<permanent | N days | archived after N months | purged on deletion>`

**Multi-tenant:** Yes — isolated by `tenant_id` column. / No.

**Soft delete:** Yes — `deleted_at IS NULL` filters active records. / No.

### Columns

| Column | Type | Nullable | Default | Description | Example Value |
|---|---|---|---|---|---|
| `id` | `UUID` | No | `gen_random_uuid()` | Primary key — surrogate UUID | `"a1b2c3d4-..."` |
| `tenant_id` | `UUID` | No | — | Foreign key to `tenants.id`. Isolates data per tenant. | `"9f8e7d6c-..."` |
| `name` | `VARCHAR(255)` | No | — | Human-readable display name. Validated: non-empty, max 255 characters. | `"Acme Corporation"` |
| `status` | `VARCHAR(50)` | No | `'pending'` | Lifecycle status. Enum: `pending`, `active`, `suspended`, `closed`. | `"active"` |
| `description` | `TEXT` | Yes | `NULL` | Optional long-form description. Not indexed. | `"A detailed note..."` |
| `amount` | `DECIMAL(19,4)` | No | `0.0000` | Monetary amount in the account's native currency. Never stored as float. | `1234.5600` |
| `is_archived` | `BOOLEAN` | No | `false` | Whether this record is archived (read-only). Not the same as soft-delete. | `false` |
| `metadata` | `JSONB` | Yes | `NULL` | Unstructured key-value extension point. Schema is not enforced at the DB level. | `{"source": "api"}` |
| `<fk_column>_id` | `UUID` | No | — | Foreign key to `<other_table>.id`. References the owning `<other_entity>`. | `"d4e5f6a7-..."` |
| `created_at` | `TIMESTAMPTZ` | No | `NOW()` | UTC timestamp of record creation. Set once; never updated. | `"2025-01-15T10:30:00Z"` |
| `updated_at` | `TIMESTAMPTZ` | No | `NOW()` | UTC timestamp of last modification. Updated on every write. | `"2025-06-01T08:00:00Z"` |
| `deleted_at` | `TIMESTAMPTZ` | Yes | `NULL` | UTC timestamp of soft deletion. `NULL` = active record. Never hard-deleted. | `"2025-07-01T00:00:00Z"` |

### Indexes

| Index Name | Columns | Type | Purpose |
|---|---|---|---|
| `<table>_pkey` | `(id)` | PRIMARY KEY | Unique row lookup |
| `<table>_tenant_id_idx` | `(tenant_id)` | B-Tree | Required for every multi-tenant table |
| `<table>_status_tenant_idx` | `(tenant_id, status)` | B-Tree | Composite index for tenant-scoped status filter queries |
| `<table>_created_at_idx` | `(created_at DESC)` | B-Tree | Sort and feed queries by newest first |
| `<table>_<fk>_idx` | `(<fk_column>_id)` | B-Tree | Required on every FK column |

### Foreign Keys

| Constraint Name | Column | References | On Delete |
|---|---|---|---|
| `<table>_tenant_id_fkey` | `tenant_id` | `tenants(id)` | CASCADE |
| `<table>_<fk>_fkey` | `<fk_column>_id` | `<other_table>(id)` | RESTRICT |

### Check Constraints

| Constraint Name | Expression | Purpose |
|---|---|---|
| `<table>_status_check` | `status IN ('pending', 'active', 'suspended', 'closed')` | Enforce valid enum values |
| `<table>_amount_non_negative` | `amount >= 0` | Business rule: amounts cannot be negative |

---

## Table: `<next_table_name>`

_Repeat the section above for each table in the schema._

---

## Enum Reference

Document shared enum values used across multiple tables.

| Enum Name | Values | Used In |
|---|---|---|
| `status` | `pending`, `active`, `suspended`, `closed` | `<table_a>`, `<table_b>` |
| `event_type` | `created`, `updated`, `deleted`, `archived` | `<audit_log_table>` |

---

## Change Log

Track significant schema changes in this dictionary. Full migration history is in the migration files.

| Date | Migration ID | Change |
|---|---|---|
| `YYYY-MM-DD` | `<migration_id>` | Added `<column>` to `<table>` |
| `YYYY-MM-DD` | `<migration_id>` | Created `<new_table>` |
| `YYYY-MM-DD` | `<migration_id>` | Deprecated `<column>` on `<table>` (soft-deleted column, scheduled for removal in v2) |
