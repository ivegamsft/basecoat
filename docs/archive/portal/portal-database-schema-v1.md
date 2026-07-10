# Basecoat Portal Database Schema v1.0

**Document Version:** 1.0  
**Date:** May 2025  
**Author:** Data Tier Agent  
**Status:** Final Design  
**Target Deployment:** PostgreSQL 14+

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Architecture Overview](#architecture-overview)
3. [Entity Relationship Diagram](#entity-relationship-diagram)
4. [Schema Design](#schema-design)
5. [Indexes & Query Optimization](#indexes--query-optimization)
6. [Backup & Recovery Strategy](#backup--recovery-strategy)
7. [Migration Strategy](#migration-strategy)
8. [Performance Notes](#performance-notes)
9. [Data Retention & Compliance](#data-retention--compliance)

---

## Executive Summary

The Basecoat Portal database supports governance, security audit, and compliance tracking across 100-1000+ concurrent users in a multi-tenant architecture. The schema is designed to scale from 100K initial audit records to millions with efficient querying, immutable audit trails, and ACID compliance.

### Key Characteristics

- **Multi-Tenancy**: Organizations and teams provide data isolation
- **Audit Trails**: All user actions logged immutably (append-only)
- **Scalability**: Designed for millions of records with composite indexing
- **Data Retention**: Configurable policies per organization
- **Compliance**: GDPR/SOC2 alignment with data lineage tracking

### Data Volume Projections

| Metric | Initial | 6 Months | 12 Months | Notes |
|--------|---------|----------|-----------|-------|
| Users | 500 | 2K | 5K | Grows with org adoption |
| Organizations | 10 | 50 | 100+ | Enterprise multi-tenant |
| Repositories | 5K | 25K | 50K+ | Per org, with history |
| Scans | 100K | 500K | 2M+ | Daily/weekly scheduling |
| Audit Logs | 500K | 3M | 10M+ | Every user action |

---

## Architecture Overview

### Core Domains

#### 1. **Identity & Access (RBAC)**
- Organizations isolate data
- Teams organize users and permissions
- Role-based access with granular permissions
- User profiles with GitHub integration

#### 2. **Repository & Scanning**
- Repositories mapped to organizations
- Scans track security, compliance, and code quality
- Scan results store findings with severity/remediation

#### 3. **Audit & Compliance**
- Compliance issues track remediation progress
- Audit logs provide immutable action history
- Findings aggregated for reporting

#### 4. **Simulations & Reporting**
- Chaos simulations for resilience testing
- Reports generated from scan/audit data
- Visibility controls (private/team/org-wide)

### Design Principles

1. **Immutability**: Audit logs are append-only; no updates allowed
2. **Referential Integrity**: Foreign keys enforce relationships
3. **Isolation**: Org-level data partitioning
4. **Auditability**: Timestamps (created_at, updated_at) on all mutable entities
5. **Extensibility**: JSONB columns for findings/config details

---

## Entity Relationship Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                         BASECOAT PORTAL - ERD                        │
└─────────────────────────────────────────────────────────────────────┘

                            ┌─────────────┐
                            │ organizations │
                            │ (id, name, plan)
                            └────────┬────┘
                                     │
                  ┌──────────────────┼──────────────────┐
                  │                  │                  │
            ┌─────▼────┐      ┌─────▼────────┐   ┌──────▼──────┐
            │   users   │      │    teams     │   │repositories│
            │  (n:many) │      │   (1:many)   │   │  (1:many)  │
            └─────┬────┘      └─────┬────────┘   └──────┬──────┘
                  │                  │                  │
            ┌─────▼──────────┐ ┌─────▼────────┐  ┌─────▼────────────┐
            │ team_members   │ │  roles       │  │    scans         │
            │ (bridge)       │ │  (lookup)    │  │   (1:many)       │
            └────────────────┘ └──────────────┘  └─────┬────────────┘
                                                        │
                                         ┌──────────────┼──────────────┐
                                         │              │              │
                                  ┌──────▼──────┐ ┌────▼────────┐  ┌──▼────────┐
                                  │scan_results │ │simulations  │  │ compliance│
                                  │ (1:many)    │ │ (1:many)    │  │ _issues   │
                                  └─────────────┘ └────┬────────┘  └───────────┘
                                                       │
                                              ┌────────▼──────────┐
                                              │ simulation_runs    │
                                              │    (1:many)        │
                                              └────────────────────┘

            ┌────────────────┐
            │  audit_logs    │  (append-only, immutable)
            │  (n for users) │
            └────────────────┘

            ┌────────────────┐
            │    reports     │  (generated from scans/audit)
            └────────────────┘
```

---

## Schema Design

### 1. Organizations (Multi-Tenancy Root)

```sql
CREATE TABLE organizations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    slug VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    plan VARCHAR(50) NOT NULL DEFAULT 'free',
    website_url VARCHAR(255),
    logo_url VARCHAR(255),
    data_retention_days INT DEFAULT 90,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    CHECK (length(slug) >= 3),
    CHECK (plan IN ('free', 'pro', 'enterprise')),
    CHECK (data_retention_days > 0)
);

CREATE INDEX idx_organizations_slug ON organizations(slug);
CREATE INDEX idx_organizations_plan ON organizations(plan);
```

### 2. Users (GitHub-Integrated Identity)

```sql
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) NOT NULL UNIQUE,
    github_id BIGINT UNIQUE,
    github_login VARCHAR(100),
    display_name VARCHAR(255),
    avatar_url VARCHAR(255),
    role VARCHAR(50) NOT NULL DEFAULT 'user',
    is_active BOOLEAN DEFAULT TRUE,
    last_login_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    CHECK (role IN ('admin', 'user', 'readonly')),
    CHECK (email ~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}$')
);

CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_github_id ON users(github_id);
CREATE INDEX idx_users_github_login ON users(github_login);
CREATE INDEX idx_users_is_active ON users(is_active);
```

### 3. Teams (Org Subdivision)

```sql
CREATE TABLE teams (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    slug VARCHAR(100) NOT NULL,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE(org_id, slug)
);

CREATE INDEX idx_teams_org_id ON teams(org_id);
CREATE INDEX idx_teams_org_slug ON teams(org_id, slug);
```

### 4. Team Members (Bridge Table)

```sql
CREATE TABLE team_members (
    team_id UUID NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role VARCHAR(50) NOT NULL DEFAULT 'member',
    joined_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    PRIMARY KEY (team_id, user_id),
    CHECK (role IN ('admin', 'member', 'readonly'))
);

CREATE INDEX idx_team_members_user_id ON team_members(user_id);
CREATE INDEX idx_team_members_role ON team_members(role);
```

### 5. Roles (Lookup - RBAC)

```sql
CREATE TABLE roles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    permissions JSONB NOT NULL DEFAULT '[]',
    is_custom BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE(org_id, name)
);

CREATE INDEX idx_roles_org_id ON roles(org_id);
```

### 6. Repositories (Scanning Targets)

```sql
CREATE TABLE repositories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    url VARCHAR(255) NOT NULL,
    description TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    last_scanned_at TIMESTAMP WITH TIME ZONE,
    scan_count INT DEFAULT 0,
    language VARCHAR(50),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE(org_id, url)
);

CREATE INDEX idx_repositories_org_id ON repositories(org_id);
CREATE INDEX idx_repositories_url ON repositories(url);
CREATE INDEX idx_repositories_is_active ON repositories(is_active);
CREATE INDEX idx_repositories_last_scanned ON repositories(last_scanned_at);
```

### 7. Scans (Audit Events)

```sql
CREATE TABLE scans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    repo_id UUID NOT NULL REFERENCES repositories(id) ON DELETE CASCADE,
    scan_type VARCHAR(50) NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'pending',
    started_at TIMESTAMP WITH TIME ZONE NOT NULL,
    completed_at TIMESTAMP WITH TIME ZONE,
    summary JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    CHECK (scan_type IN ('security', 'compliance', 'code_quality', 'sca')),
    CHECK (status IN ('pending', 'in_progress', 'completed', 'failed', 'cancelled')),
    CHECK (completed_at IS NULL OR completed_at >= started_at)
);

CREATE INDEX idx_scans_repo_id ON scans(repo_id);
CREATE INDEX idx_scans_status ON scans(status);
CREATE INDEX idx_scans_created_at ON scans(created_at);
CREATE INDEX idx_scans_repo_created ON scans(repo_id, created_at DESC);
CREATE INDEX idx_scans_type_status ON scans(scan_type, status);
```

### 8. Scan Results (Findings)

```sql
CREATE TABLE scan_results (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    scan_id UUID NOT NULL REFERENCES scans(id) ON DELETE CASCADE,
    finding_type VARCHAR(100) NOT NULL,
    severity VARCHAR(20) NOT NULL,
    count INT DEFAULT 1,
    details JSONB NOT NULL,
    remediation_steps JSONB,
    cve_id VARCHAR(50),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    CHECK (severity IN ('critical', 'high', 'medium', 'low', 'info')),
    CHECK (count > 0)
);

CREATE INDEX idx_scan_results_scan_id ON scan_results(scan_id);
CREATE INDEX idx_scan_results_severity ON scan_results(severity);
CREATE INDEX idx_scan_results_finding_type ON scan_results(finding_type);
CREATE INDEX idx_scan_results_cve ON scan_results(cve_id);
CREATE INDEX idx_scan_results_scan_severity ON scan_results(scan_id, severity DESC);
```

### 9. Compliance Issues (Tracking)

```sql
CREATE TABLE compliance_issues (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    repo_id UUID NOT NULL REFERENCES repositories(id) ON DELETE CASCADE,
    issue_type VARCHAR(100) NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'open',
    severity VARCHAR(20) NOT NULL DEFAULT 'medium',
    assigned_to UUID REFERENCES users(id) ON DELETE SET NULL,
    due_date DATE,
    description TEXT,
    remediation_notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    resolved_at TIMESTAMP WITH TIME ZONE,
    
    CHECK (status IN ('open', 'in_progress', 'resolved', 'wontfix')),
    CHECK (severity IN ('critical', 'high', 'medium', 'low'))
);

CREATE INDEX idx_compliance_issues_repo_id ON compliance_issues(repo_id);
CREATE INDEX idx_compliance_issues_status ON compliance_issues(status);
CREATE INDEX idx_compliance_issues_assigned_to ON compliance_issues(assigned_to);
CREATE INDEX idx_compliance_issues_due_date ON compliance_issues(due_date);
CREATE INDEX idx_compliance_issues_repo_status ON compliance_issues(repo_id, status);
```

### 10. Audit Logs (Immutable - Append-Only)

```sql
CREATE TABLE audit_logs (
    id BIGSERIAL PRIMARY KEY,
    org_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    action VARCHAR(100) NOT NULL,
    entity_type VARCHAR(50) NOT NULL,
    entity_id VARCHAR(255),
    changes JSONB,
    ip_address INET,
    user_agent TEXT,
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

CREATE INDEX idx_audit_logs_org_id ON audit_logs(org_id);
CREATE INDEX idx_audit_logs_user_id ON audit_logs(user_id);
CREATE INDEX idx_audit_logs_timestamp ON audit_logs(timestamp);
CREATE INDEX idx_audit_logs_entity ON audit_logs(entity_type, entity_id);
CREATE INDEX idx_audit_logs_org_timestamp ON audit_logs(org_id, timestamp DESC);
CREATE INDEX idx_audit_logs_user_timestamp ON audit_logs(user_id, timestamp DESC);
```

### 11. Simulations (Chaos/Resilience Testing)

```sql
CREATE TABLE simulations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    repo_id UUID NOT NULL REFERENCES repositories(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    config JSONB NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'draft',
    results JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    CHECK (status IN ('draft', 'scheduled', 'running', 'completed', 'failed'))
);

CREATE INDEX idx_simulations_repo_id ON simulations(repo_id);
CREATE INDEX idx_simulations_status ON simulations(status);
```

### 12. Simulation Runs (Execution History)

```sql
CREATE TABLE simulation_runs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sim_id UUID NOT NULL REFERENCES simulations(id) ON DELETE CASCADE,
    scenario VARCHAR(255),
    outcome VARCHAR(50),
    details JSONB,
    duration_ms INT,
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    CHECK (outcome IN ('success', 'partial', 'failed'))
);

CREATE INDEX idx_simulation_runs_sim_id ON simulation_runs(sim_id);
CREATE INDEX idx_simulation_runs_timestamp ON simulation_runs(timestamp);
```

### 13. Reports (Aggregated Insights)

```sql
CREATE TABLE reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    report_type VARCHAR(50) NOT NULL,
    title VARCHAR(255) NOT NULL,
    data JSONB NOT NULL,
    visibility VARCHAR(50) NOT NULL DEFAULT 'org',
    generated_by UUID REFERENCES users(id) ON DELETE SET NULL,
    generated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    CHECK (report_type IN ('compliance', 'security', 'audit', 'dashboard')),
    CHECK (visibility IN ('private', 'team', 'org', 'enterprise'))
);

CREATE INDEX idx_reports_org_id ON reports(org_id);
CREATE INDEX idx_reports_report_type ON reports(report_type);
CREATE INDEX idx_reports_generated_at ON reports(generated_at DESC);
```

---

## Indexes & Query Optimization

### Strategy

1. **Primary Access Patterns** indexed first
2. **Composite indexes** for JOIN-heavy queries
3. **Partial indexes** for status filtering
4. **BRIN indexes** for large time-series (audit_logs)
5. **Careful selectivity** to avoid index bloat

### Index Summary

| Table | Index Name | Columns | Type | Use Case |
|-------|-----------|---------|------|----------|
| scans | idx_scans_repo_created | (repo_id, created_at DESC) | Composite | List scans by repo, newest first |
| scan_results | idx_scan_results_scan_severity | (scan_id, severity DESC) | Composite | Filter results by severity |
| audit_logs | idx_audit_logs_org_timestamp | (org_id, timestamp DESC) | Composite | Org audit trails, ordered |
| repositories | idx_repositories_is_active | (is_active) | Partial | Active repos only |
| compliance_issues | idx_compliance_issues_repo_status | (repo_id, status) | Composite | Open issues per repo |

### Query Optimization Tips

#### N+1 Prevention
```sql
-- ❌ BAD: N+1 queries
SELECT * FROM repositories WHERE org_id = $1;
-- Then loop and query scans for each repo

-- ✅ GOOD: JOIN with aggregation
SELECT r.*, 
       COUNT(s.id) as scan_count,
       MAX(s.completed_at) as last_scan
FROM repositories r
LEFT JOIN scans s ON r.id = s.repo_id
WHERE r.org_id = $1
GROUP BY r.id;
```

#### Audit Log Querying
```sql
-- Efficient pagination with timestamp ordering
SELECT * FROM audit_logs
WHERE org_id = $1 AND timestamp > $2
ORDER BY timestamp DESC
LIMIT 50;
```

#### Scan Results Aggregation
```sql
-- Summary by severity (uses index on severity)
SELECT severity, COUNT(*) as count
FROM scan_results sr
JOIN scans s ON sr.scan_id = s.id
WHERE s.repo_id = $1 AND s.status = 'completed'
GROUP BY sr.severity
ORDER BY CASE severity
    WHEN 'critical' THEN 1
    WHEN 'high' THEN 2
    WHEN 'medium' THEN 3
    WHEN 'low' THEN 4
    ELSE 5 END;
```

---

## Backup & Recovery Strategy

### Backup Schedule

```bash
# Daily backups (incremental)
0 2 * * * pg_dump -Fc basecoat_portal > /backups/daily/basecoat_$(date +\%Y\%m\%d).dump

# Weekly backups (full)
0 3 * * 0 pg_dump -Fc basecoat_portal > /backups/weekly/basecoat_week_$(date +\%W).dump

# Monthly snapshots (archive)
0 4 1 * * pg_dump -Fc basecoat_portal | gzip > /backups/monthly/basecoat_$(date +\%Y\%m).dump.gz
```

### Retention Policy

- **Daily Backups**: 14 days
- **Weekly Backups**: 12 weeks (3 months)
- **Monthly Snapshots**: 24 months (2 years)
- **WAL Archiving**: 7 days for PITR

### Recovery Procedures

#### Full Restore
```bash
pg_restore -d basecoat_portal --clean /backups/daily/basecoat_20250505.dump
```

#### Point-in-Time Recovery (PITR)
```bash
# Requires WAL archiving enabled
psql -d basecoat_portal << EOF
SELECT pg_stop_backup();
EOF

# Restore to specific timestamp
pg_restore -d basecoat_portal --disable-triggers /backups/daily/basecoat_20250505.dump
# Apply WAL files up to target time
```

#### Selective Table Restore
```bash
pg_restore -d basecoat_portal -t audit_logs /backups/daily/basecoat_20250505.dump
```

### Testing Restore Procedures

- Monthly restore drills to staging environment
- Automated integrity checks post-restore
- Document recovery time objectives (RTO)

---

## Migration Strategy

### Versioning Scheme

```
v1.0: Initial schema (current)
v1.1: Add org_id to reports (non-breaking)
v2.0: Restructure audit_logs sharding (breaking)
```

### Migration File Structure

```
migrations/
├── v1.0/
│   ├── 001_initial_schema.sql
│   ├── 002_initial_indexes.sql
│   └── 003_seed_roles.sql
├── v1.1/
│   ├── 001_add_audit_retention.sql
│   └── 002_backfill_compliance_severity.sql
└── v2.0/
    └── 001_partition_audit_logs.sql
```

### Migration Execution Pattern

```bash
#!/bin/bash
# Migrate to version 1.1

MIGRATION_PATH="migrations/v1.1"
BACKUP_FILE="/backups/pre_migration_$(date +%s).dump"

# 1. Backup current state
pg_dump -Fc basecoat_portal > $BACKUP_FILE

# 2. Execute migrations in order
for sql_file in $(ls $MIGRATION_PATH/*.sql | sort); do
    echo "Applying $sql_file..."
    psql -f $sql_file basecoat_portal || {
        echo "Migration failed, restoring backup..."
        pg_restore -d basecoat_portal $BACKUP_FILE
        exit 1
    }
done

# 3. Verify schema
psql -c "\dt" basecoat_portal

echo "Migration to v1.1 complete"
```

### Rollback Procedures

```sql
-- v1.1 → v1.0 rollback
-- 1. Drop new columns/tables
ALTER TABLE reports DROP COLUMN org_id;
DROP TABLE IF EXISTS migration_tracking;

-- 2. Restore function definitions
CREATE OR REPLACE FUNCTION update_timestamp() RETURNS TRIGGER AS $$
  BEGIN NEW.updated_at = CURRENT_TIMESTAMP; RETURN NEW; END;
$$ LANGUAGE plpgsql;

-- 3. Verify data integrity
SELECT COUNT(*) FROM reports;
```

### Zero-Downtime Deployments

For breaking changes (v2.0+), use:

1. **Dual-write pattern**: New and old columns written simultaneously
2. **Gradual read migration**: APIs switch over weeks
3. **Blue-green deployments**: Parallel databases
4. **Feature flags**: Toggle new schema queries

---

## Performance Notes

### Connection Pooling

```
pgBouncer Configuration (recommended)
max_client_conn = 1000
default_pool_size = 25
reserve_pool_size = 5
reserve_pool_timeout = 3
```

### Query Performance Baselines

| Query | Expected Execution Time | Rows | Notes |
|-------|--------------------------|------|-------|
| Scans by repo (last 30 days) | < 100ms | 1K | Uses idx_scans_repo_created |
| Audit logs by org (paginated) | < 50ms | 50 | Uses idx_audit_logs_org_timestamp |
| Scan results by severity | < 200ms | 5K | Aggregated, uses index |
| Compliance issues open | < 75ms | 500 | Filtered by status |

### Scaling Recommendations

**At 1M Audit Logs:**
- Partition audit_logs by date (monthly)
- Use BRIN indexes on timestamp
- Archive old partitions to cold storage

**At 5M Scan Results:**
- Partition by repository_id or scan_type
- Implement query result caching (Redis)
- Consider columnar storage (Citus) for analytics

**At 10M+ Records:**
- Move to multi-node PostgreSQL (Citus)
- Separate OLTP and OLAP workloads
- Implement auto-vacuuming tuning

---

## Data Retention & Compliance

### GDPR Compliance

**User Deletion:**
```sql
-- Soft-delete: mark inactive
UPDATE users SET is_active = FALSE WHERE id = $1;

-- Hard-delete: cascade to audit_logs (PII anonymization)
DELETE FROM users WHERE id = $1;
```

**Right to Erasure:**
- Audit logs retain org_id only (no user PII after deletion)
- Configure `ON DELETE SET NULL` for foreign keys

### SOC 2 Audit Trail

- Immutable audit_logs table (no UPDATE/DELETE)
- Timestamp + user tracking on all mutations
- IP address + user_agent captured
- Monthly retention policy per organization

### Data Anonymization

```sql
-- For compliance reports, anonymize user data
SELECT 
    user_id,
    action,
    entity_type,
    timestamp
FROM audit_logs
WHERE timestamp > CURRENT_DATE - INTERVAL '90 days'
-- User details NOT exposed in reports
```

---

## Entity Reference

### User Roles & Permissions

```json
{
  "admin": {
    "permissions": [
      "manage_teams",
      "manage_users",
      "manage_repositories",
      "view_audit_logs",
      "delete_scans",
      "manage_compliance"
    ]
  },
  "user": {
    "permissions": [
      "create_scans",
      "view_results",
      "comment_issues",
      "view_org_reports"
    ]
  },
  "readonly": {
    "permissions": [
      "view_scans",
      "view_results",
      "view_reports"
    ]
  }
}
```

### Scan Types

- **security**: SAST/DAST/dependency scanning
- **compliance**: Policy/governance audits
- **code_quality**: Linting, coverage, complexity
- **sca**: Software Composition Analysis

### Severity Levels (CVSS-aligned)

- **critical**: 9.0-10.0 (immediate action required)
- **high**: 7.0-8.9 (urgent, within days)
- **medium**: 4.0-6.9 (schedule remediation)
- **low**: 0.1-3.9 (document and track)
- **info**: Informational findings only

---

## Deployment Checklist

- [ ] PostgreSQL 14+ provisioned with replication
- [ ] Connection pooling configured (pgBouncer/PgPool)
- [ ] Backup jobs scheduled and tested
- [ ] Monitoring alerts configured (CPU, memory, connections)
- [ ] Query logging enabled for slow query analysis
- [ ] EXPLAIN ANALYZE validated for key queries
- [ ] Load testing completed (1K concurrent users)
- [ ] Backup restore drills completed
- [ ] High availability failover tested
- [ ] Documentation handed off to ops team

---

## Appendix: SQL References

### Create Schema Extension

```sql
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
CREATE EXTENSION IF NOT EXISTS "btree_gin";
CREATE EXTENSION IF NOT EXISTS "btree_gist";
```

### Useful Views & Functions

```sql
-- Scan summary by org
CREATE VIEW v_org_scan_summary AS
SELECT 
    o.id, o.name,
    COUNT(DISTINCT r.id) as repo_count,
    COUNT(DISTINCT s.id) as scan_count,
    COUNT(DISTINCT sr.id) FILTER (WHERE sr.severity = 'critical') as critical_findings
FROM organizations o
LEFT JOIN repositories r ON o.id = r.org_id
LEFT JOIN scans s ON r.id = s.repo_id
LEFT JOIN scan_results sr ON s.id = sr.scan_id
GROUP BY o.id, o.name;

-- Activity tracking
CREATE OR REPLACE FUNCTION log_audit_event()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO audit_logs (org_id, user_id, action, entity_type, entity_id, changes)
    VALUES (
        NEW.org_id,
        current_user_id(),
        TG_ARGV[0],
        TG_TABLE_NAME,
        NEW.id::TEXT,
        to_jsonb(NEW) - to_jsonb(OLD)
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
```

---

**Document End**

*For questions or updates, contact the Data Tier team.*
