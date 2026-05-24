# Basecoat Portal Database

Complete PostgreSQL schema for Basecoat Portal governance, security audit, and compliance tracking.

## Quick Start

### 1. Initialize Schema

```bash
psql -h localhost -p 5432 -U postgres -d basecoat_portal -f ./migrations/v1.0/001_initial_schema.sql
```

### 2. Load Seed Data (Development)

```bash
psql -h localhost -p 5432 -U postgres -d basecoat_portal -f ./seeds/001_initial_data.sql
```

### 3. Verify Setup

```bash
psql -h localhost -p 5432 -U postgres -d basecoat_portal -c "\dt"
```

## Directory Structure

```
.
├── migrations/          # Database schema versions
│   ├── v1.0/           # Initial schema (13+ tables, 30+ indexes)
│   │   └── 001_initial_schema.sql
│   └── v1.1/           # Non-breaking enhancements
│       └── 001_add_audit_retention.sql
├── seeds/              # Sample data for testing
│   └── 001_initial_data.sql
├── backup-scripts/     # Backup and restore utilities
│   ├── backup.sh       # Automated backup with retention
│   └── restore.sh      # Safe restore with verification
├── migrate.sh          # Migration runner (production-safe)
└── README.md           # This file
```

## Schema Overview

### Core Tables

#### Identity & Access (RBAC)
- `organizations` - Multi-tenant root (parent org isolation)
- `users` - GitHub-integrated user accounts
- `teams` - Organization subdivisions
- `team_members` - Many-to-many bridge
- `roles` - RBAC with custom permissions

#### Scanning & Results
- `repositories` - Scanning targets per org
- `scans` - Security/compliance/code_quality/SCA scan executions
- `scan_results` - Individual findings with severity & remediation
- `compliance_issues` - Remediation tracking

#### Audit & Compliance
- `audit_logs` - Immutable append-only audit trail (GDPR/SOC2)
- `reports` - Aggregated insights (compliance, security, audit)

#### Simulations
- `simulations` - Chaos/resilience test configurations
- `simulation_runs` - Execution history

### Data Volume Estimates

| Table | Initial Records | 6 Mo | 12 Mo | Storage (12 Mo) |
|-------|-----------------|------|-------|-----------------|
| organizations | 10 | 50 | 100+ | < 1 MB |
| users | 500 | 2K | 5K | < 2 MB |
| repositories | 5K | 25K | 50K+ | ~ 5 MB |
| scans | 100K | 500K | 2M+ | ~ 200 MB |
| scan_results | 500K | 2.5M | 10M+ | ~ 800 MB |
| audit_logs | 500K | 3M | 10M+ | ~ 1 GB |

**Total at 12 months: ~2.2 GB** (compress to ~400-500 MB with pg_dump)

## Indexes

### Query Optimization Strategy

**High-selectivity B-tree indexes:**
```sql
-- Frequently queried columns
idx_scans_repo_created          (repo_id, created_at DESC)
idx_scan_results_scan_severity  (scan_id, severity DESC)
idx_audit_logs_org_timestamp    (org_id, timestamp DESC)
```

**Partial indexes** (reduce size, faster on common queries):
```sql
-- Only index active repos, pending scans
idx_repositories_is_active      WHERE is_active = TRUE
idx_scans_pending              WHERE status IN ('pending', 'in_progress')
```

**GIN indexes** for JSONB searches (findings, config):
```sql
-- Enable efficient JSON document queries
idx_scan_results_details_gin   USING GIN (details)
```

## Backup & Recovery

### Automated Backup

```bash
# Daily backup (14-day retention)
./backup-scripts/backup.sh daily

# Weekly backup (12-week retention)
./backup-scripts/backup.sh weekly

# Monthly backup (24-month retention)
./backup-scripts/backup.sh monthly
```

### Scheduled Backups (Cron)

```bash
# Daily at 2 AM
0 2 * * * /path/to/basecoat/portal/backend/db/backup-scripts/backup.sh daily

# Weekly Sunday at 3 AM
0 3 * * 0 /path/to/basecoat/portal/backend/db/backup-scripts/backup.sh weekly

# Monthly 1st at 4 AM
0 4 1 * * /path/to/basecoat/portal/backend/db/backup-scripts/backup.sh monthly
```

### Restore from Backup

```bash
# Interactive restore (prompts before swap)
./backup-scripts/restore.sh /backups/daily/basecoat_portal_20250505.dump

# Restore to alternate database
./backup-scripts/restore.sh /backups/daily/basecoat_portal_20250505.dump staging_db
```

**Restore process:**
1. Creates temp database
2. Restores from backup
3. Verifies referential integrity
4. Prompts for confirmation
5. Swaps databases (old backed up as `<db>_backup_<timestamp>`)

## Migrations

### Apply Migration

```bash
./migrate.sh v1.1
```

**Prompts:**
1. Create backup? (recommended)
2. Execute migration scripts in order
3. Record version in `schema_migrations` table

### Migration Files

All migrations follow this structure:
```sql
-- Version info and time estimate
-- BEGIN transaction
-- DDL changes
-- Populate backfill data
-- COMMIT

-- Rollback procedure (commented)
/*
BEGIN;
  -- Reverse changes
COMMIT;
*/

-- Verification queries
SELECT ... -- Verify success
```

### Create New Migration

```bash
# Create directory
mkdir -p migrations/v1.2

# Create migration file with timestamp ordering
cat > migrations/v1.2/001_add_feature_x.sql << 'EOF'
-- Feature X schema changes
BEGIN;
  -- Your DDL here
COMMIT;
EOF
```

## Views

### Org Scan Summary (`v_org_scan_summary`)
```sql
SELECT * FROM v_org_scan_summary WHERE slug = 'techcorp';
-- Returns: repo_count, total_scans, critical_findings, last_scan_time
```

### Repository Status (`v_repository_status`)
```sql
SELECT * FROM v_repository_status WHERE name LIKE '%api%';
-- Returns: total_scans, completed_scans, urgent_findings, has_critical
```

### Compliance Summary (`v_compliance_summary`)
```sql
SELECT * FROM v_compliance_summary WHERE repo_id = '...';
-- Returns: total_issues, open_issues, in_progress, overdue_critical
```

## Common Queries

### Find Critical Findings

```sql
SELECT 
    sr.id,
    sr.finding_type,
    r.name as repo_name,
    s.scan_type,
    sr.remediation_steps
FROM scan_results sr
JOIN scans s ON sr.scan_id = s.id
JOIN repositories r ON s.repo_id = r.id
WHERE sr.severity = 'critical'
AND s.status = 'completed'
ORDER BY s.completed_at DESC
LIMIT 20;
```

### Org Audit Trail

```sql
SELECT 
    user_id,
    action,
    entity_type,
    entity_id,
    timestamp
FROM audit_logs
WHERE org_id = $1
AND timestamp > CURRENT_DATE - INTERVAL '30 days'
ORDER BY timestamp DESC
LIMIT 100;
```

### Open Compliance Issues

```sql
SELECT 
    ci.id,
    ci.issue_type,
    ci.severity,
    ci.assigned_to,
    ci.due_date,
    r.name as repo_name
FROM compliance_issues ci
JOIN repositories r ON ci.repo_id = r.id
WHERE ci.status IN ('open', 'in_progress')
AND r.org_id = $1
ORDER BY ci.due_date ASC, ci.severity DESC;
```

## Performance Tuning

### Connection Pooling

```
pgBouncer Config (recommended):
max_client_conn = 1000
default_pool_size = 25
reserve_pool_size = 5
server_lifetime = 3600
```

### Query Statistics

```sql
-- Enable query logging
SET log_min_duration_statement = 1000; -- Log queries > 1 second

-- Find slow queries
SELECT mean_exec_time, calls, query
FROM pg_stat_statements
WHERE query NOT LIKE '%pg_stat%'
ORDER BY mean_exec_time DESC
LIMIT 10;
```

### Maintenance

```sql
-- Analyze table statistics (run daily)
ANALYZE;

-- Vacuum for cleanup (auto-vacuum usually sufficient)
VACUUM ANALYZE;

-- Check index health
REINDEX INDEX CONCURRENTLY idx_scans_repo_created;
```

## Scaling Strategy

### Phase 1 (Current - 1M audit_logs)
- Single PostgreSQL instance
- Daily pg_dump backups
- Connection pooling with pgBouncer

### Phase 2 (1M - 5M audit_logs)
- Add read replicas (streaming replication)
- Partition audit_logs by month
- Archive old partitions to cold storage

### Phase 3 (5M+ audit_logs)
- Multi-node with Citus (distributed PostgreSQL)
- Separate OLTP and OLAP workloads
- Columnar storage for analytics

## Compliance & Audit

### GDPR
- User soft-delete (mark inactive)
- Hard-delete cascades, audit_logs retain org_id only
- Data retention per org (configurable)

### SOC 2
- Immutable audit logs (triggers prevent UPDATE/DELETE)
- Timestamp + user tracking on all mutations
- IP address + user_agent captured
- Monthly retention policy per organization

### HIPAA (if applicable)
- Encryption at rest (PostgreSQL pg_crypto)
- Encryption in transit (SSL/TLS)
- Field-level encryption for PII (future)

## Troubleshooting

### Connection Issues

```bash
# Test connection
psql -h localhost -p 5432 -U postgres -d basecoat_portal -c "SELECT 1"

# Check active connections
SELECT count(*) FROM pg_stat_activity;
```

### Slow Queries

```sql
-- Enable slow query log
ALTER SYSTEM SET log_min_duration_statement = 1000;
SELECT pg_reload_conf();

-- Analyze specific query
EXPLAIN ANALYZE
SELECT * FROM scans WHERE repo_id = $1 ORDER BY created_at DESC LIMIT 50;
```

### Disk Space

```bash
# Check database size
psql -c "SELECT pg_size_pretty(pg_database_size('basecoat_portal'));"

# Check table sizes
psql -c "SELECT relname, pg_size_pretty(pg_total_relation_size(relid)) 
         FROM pg_stat_user_tables 
         ORDER BY pg_total_relation_size(relid) DESC;"
```

## Documentation

- **Schema Design**: See `docs/PORTAL_DATABASE_SCHEMA_v1.md`
- **API Endpoints**: Backend service documentation
- **Operations Guide**: Deployment and monitoring procedures

## Support

For issues or questions about the database schema:

1. Check the troubleshooting section above
2. Review migration logs: `db/migrate.sh` output
3. Check PostgreSQL logs: `/var/log/postgresql/postgresql.log`
4. Contact: data-tier-team@basecoat.dev

---

**Last Updated**: May 2025  
**Version**: 1.0  
**Status**: Production Ready
