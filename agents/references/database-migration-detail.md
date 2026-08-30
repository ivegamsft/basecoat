# Database Migration Agent — Detail Reference

Full migration pattern examples (schema-only, data migration strategies, dual-write,
zero-downtime via feature flags), risk assessment table, testing strategy, checklists,
common challenges, and post-migration validation script for
`agents/basecoat-80-data-database-migration.agent.md`.

## Migration Patterns

### Schema-Only Migrations

**Backward-Compatible Changes** (Safe)

```sql
-- Add column with default
ALTER TABLE users ADD COLUMN created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

-- Add nullable column
ALTER TABLE products ADD COLUMN description VARCHAR(1000);

-- Rename column (with compatible alias in application layer first)
ALTER TABLE orders ADD COLUMN order_date TIMESTAMP;
-- Keep old column until all code migrated
```

**Breaking Changes** (Require Coordination)

```sql
-- Remove column (ensure no code references it)
ALTER TABLE users DROP COLUMN deprecated_field;

-- Rename table (coordinate with application)
ALTER TABLE old_name RENAME TO new_name;

-- Change data type (requires data transformation)
ALTER TABLE products 
  ALTER COLUMN price TYPE DECIMAL(12,2) USING price::DECIMAL(12,2);
```

### Data Migration Strategies

**Full Table Copy** (Small tables)

```sql
-- Simple copy with validation
CREATE TABLE target_db.new_table AS 
SELECT * FROM source_db.old_table;

-- Validate row counts
SELECT COUNT(*) FROM source_db.old_table;  -- 1,234,567
SELECT COUNT(*) FROM target_db.new_table;  -- 1,234,567
```

**Incremental Replication** (Large tables)

Before the initial snapshot, establish database-native CDC, logical replication, or a
trigger-backed change log. Capture a consistent replication point (for example, a
database LSN), take the snapshot at that point, and continuously apply inserts, updates,
and deletes from the chosen CDC system until cutover. Do not use a snapshot table as a
change tracker.

**Dual-Write Pattern** (Zero-Downtime)

1. Deploy dual-write logic (write to both old and new)
2. Replicate historical data
3. Validate data consistency
4. Switch reads to new system
5. Remove writes to old system (read-only)
6. Decommission old system

### Zero-Downtime Migrations — Feature Flags

```python
# Application layer
if feature_flag_enabled('use_new_database'):
    db = new_connection
else:
    db = old_connection

# Parallel writes for validation
write_to_old_db(data)
try:
    write_to_new_db(data)
except Exception as e:
    log_mismatch(e)
    # The authoritative old database remains available; track new-store divergence.
```

## Risk Assessment & Validation

| Risk | Mitigation |
|------|-----------|
| Data loss | Backup before, incremental sync validation, dry-run in staging |
| Schema incompatibility | Automated schema comparison, application compatibility tests |
| Performance regression | Index analysis, query plan comparison, load test |
| Lock contention | Schedule during maintenance window, use online DDL |
| Rollback failure | Test rollback procedure in staging, keep old system for 24h |

## Testing Strategy

```yaml
# Migration validation tests
tests:
  data_integrity:
    - row_count_match: [source, target]
    - checksum_match: [source, target]
    - null_count_match: [source, target]
    
  application:
    - smoke_tests: # basic functionality
    - regression_tests: # against baseline
    - load_test: # target capacity
    
  performance:
    - query_latency < baseline * 1.1
    - throughput > baseline * 0.9
```

## Pre-Migration Checklist

- [ ] Backup source database
- [ ] Notify stakeholders of maintenance window
- [ ] Verify rollback plan works in staging
- [ ] Test failover/recovery procedures
- [ ] Confirm monitoring and alerting active
- [ ] Have DBA on-call during migration
- [ ] Document expected duration and downtime
- [ ] Prepare communication for users

## Common Challenges

| Challenge | Solution |
|-----------|----------|
| Long-running queries during migration | Pre-migration analysis, terminate blocking sessions, increase transaction timeout |
| Foreign key constraint violations | Pre-process data, defer constraint checking, use `SET CONSTRAINTS DEFERRED` |
| Lock escalation during DDL | Use online DDL (MySQL 5.7+, PostgreSQL 11+), schedule during low-traffic window |
| Migration exceeds RTO window | Implement dual-write earlier, use log-based CDC, stage more data pre-migration |
| Slave lag in replication | Monitor lag continuously, adjust replica configuration, consider read-replica instead |

## Post-Migration Validation

```bash
#!/bin/bash
# Comprehensive validation script

# 1. Row count validation
psql -c "SELECT COUNT(*) FROM target_db.table1" > target_count.txt
diff -u source_count.txt target_count.txt

# 2. Data integrity (sampling)
psql -c "SELECT * FROM source.table1 EXCEPT SELECT * FROM target.table1" > divergence.txt

# 3. Index validation
psql -c "SELECT schemaname, tablename, indexname FROM pg_indexes 
         WHERE schemaname = 'target'" > target_indexes.txt

# 4. Constraint validation
psql -c "SELECT * FROM information_schema.table_constraints WHERE table_schema = 'target'"
```

## References

- [PostgreSQL Zero Downtime Migrations](https://wiki.postgresql.org/wiki/Upgrade_Patterns_for_Safe_Database_Migrations)
- [MySQL Online DDL Best Practices](https://dev.mysql.com/doc/refman/8.0/en/innodb-online-ddl-operations.html)
- [Change Data Capture Patterns](https://martinfowler.com/patterns/changecapture.html)
