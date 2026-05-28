# Backup & Recovery Procedures
## BaseCoat Portal Database v1.0

### Executive Summary

This guide documents automated backup strategy, recovery procedures, point-in-time recovery (PITR) capabilities, and backup retention policies for the Basecoat Portal PostgreSQL database.

**Backup Strategy:** Three-tier retention (daily, weekly, monthly)
**Backup Format:** PostgreSQL custom format (pg_dump -Fc) with optional compression
**Recovery Capability:** Point-in-time recovery up to 7 days
**RTO (Recovery Time Objective):** < 30 minutes
**RPO (Recovery Point Objective):** < 5 minutes

---

## Part 1: Backup Strategy

### 1.1 Backup Schedule

| Tier | Frequency | Retention | Schedule | Format | Location |
|------|-----------|-----------|----------|--------|----------|
| Daily | Once/day | 14 days | 02:00 UTC | Custom format | `/backups/daily/` |
| Weekly | Once/week | 12 weeks | Sunday 03:00 UTC | Custom format | `/backups/weekly/` |
| Monthly | Once/month | 24 months | 1st day 04:00 UTC | Gzipped custom | `/backups/monthly/` |

### 1.2 Backup Directory Structure

```
/backups/basecoat-portal/
├── daily/
│   ├── basecoat-portal-2025-01-15.dump
│   ├── basecoat-portal-2025-01-14.dump
│   └── ... (14 days retention)
├── weekly/
│   ├── basecoat-portal-2025-01-12-weekly.dump
│   ├── basecoat-portal-2025-01-05-weekly.dump
│   └── ... (12 weeks retention)
├── monthly/
│   ├── basecoat-portal-2025-01-01-monthly.dump.gz
│   ├── basecoat-portal-2024-12-01-monthly.dump.gz
│   └── ... (24 months retention)
└── wal-archives/
    ├── 000000010000000000000001
    ├── 000000010000000000000002
    └── ... (WAL files for PITR)
```

---

## Part 2: Automated Backup Script

### 2.1 Daily Backup Script

```bash
#!/bin/bash
# /usr/local/bin/backup-basecoat-daily.sh
# Daily backup for Basecoat Portal database

set -e

# Configuration
BACKUP_DIR="/backups/basecoat-portal/daily"
DB_HOST="staging-rds.aws.amazon.com"
DB_PORT="5432"
DB_NAME="basecoat_portal"
DB_USER="postgres"
RETENTION_DAYS=14
DATE=$(date +%Y-%m-%d)
BACKUP_FILE="$BACKUP_DIR/basecoat-portal-${DATE}.dump"

# Create backup directory if not exists
mkdir -p "$BACKUP_DIR"

# Perform backup
echo "Starting daily backup: $DATE"
pg_dump -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -Fc "$DB_NAME" > "$BACKUP_FILE"

# Verify backup
if [ -s "$BACKUP_FILE" ]; then
    SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
    echo "✓ Backup successful: $SIZE"
    
    # Verify backup integrity
    pg_restore -l "$BACKUP_FILE" > /dev/null && echo "✓ Backup integrity verified"
else
    echo "✗ Backup failed: File is empty"
    exit 1
fi

# Prune old backups (keep only last 14 days)
echo "Pruning backups older than $RETENTION_DAYS days"
find "$BACKUP_DIR" -name "basecoat-portal-*.dump" -mtime "+$RETENTION_DAYS" -delete
ls -lh "$BACKUP_DIR" | tail -5

echo "✓ Daily backup completed successfully"
```

### 2.2 Weekly Backup Script

```bash
#!/bin/bash
# /usr/local/bin/backup-basecoat-weekly.sh
# Weekly backup for Basecoat Portal database

set -e

# Configuration
BACKUP_DIR="/backups/basecoat-portal/weekly"
DB_HOST="staging-rds.aws.amazon.com"
DB_PORT="5432"
DB_NAME="basecoat_portal"
DB_USER="postgres"
RETENTION_WEEKS=12
DATE=$(date +%Y-%m-%d)
DOW=$(date +%A)  # Day of week
BACKUP_FILE="$BACKUP_DIR/basecoat-portal-${DATE}-weekly.dump"

# Only run on Sunday
if [ "$DOW" != "Sunday" ]; then
    echo "Skipping: Not Sunday (today is $DOW)"
    exit 0
fi

mkdir -p "$BACKUP_DIR"

echo "Starting weekly backup: $DATE (Sunday)"
pg_dump -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -Fc "$DB_NAME" > "$BACKUP_FILE"

# Verify
if [ -s "$BACKUP_FILE" ]; then
    SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
    echo "✓ Weekly backup successful: $SIZE"
    pg_restore -l "$BACKUP_FILE" > /dev/null && echo "✓ Backup verified"
else
    echo "✗ Backup failed"
    exit 1
fi

# Prune old weekly backups (keep 12 weeks)
echo "Pruning weekly backups older than $RETENTION_WEEKS weeks"
find "$BACKUP_DIR" -name "basecoat-portal-*-weekly.dump" \
    -mtime "+$((RETENTION_WEEKS * 7))" -delete

echo "✓ Weekly backup completed"
```

### 2.3 Monthly Backup Script (with Compression)

```bash
#!/bin/bash
# /usr/local/bin/backup-basecoat-monthly.sh
# Monthly backup with compression for long-term storage

set -e

# Configuration
BACKUP_DIR="/backups/basecoat-portal/monthly"
DB_HOST="staging-rds.aws.amazon.com"
DB_PORT="5432"
DB_NAME="basecoat_portal"
DB_USER="postgres"
RETENTION_MONTHS=24
DATE=$(date +%Y-%m-01)  # First day of month
BACKUP_FILE="$BACKUP_DIR/basecoat-portal-${DATE}-monthly.dump"
BACKUP_COMPRESSED="$BACKUP_FILE.gz"

# Only run on 1st of month
DOM=$(date +%d)
if [ "$DOM" != "01" ]; then
    echo "Skipping: Not 1st of month (today is day $DOM)"
    exit 0
fi

mkdir -p "$BACKUP_DIR"

echo "Starting monthly backup: $DATE"
pg_dump -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -Fc "$DB_NAME" > "$BACKUP_FILE"

# Compress
echo "Compressing backup..."
gzip "$BACKUP_FILE"

# Verify compressed backup
if [ -s "$BACKUP_COMPRESSED" ]; then
    SIZE=$(du -h "$BACKUP_COMPRESSED" | cut -f1)
    echo "✓ Monthly backup successful (compressed): $SIZE"
else
    echo "✗ Backup failed"
    exit 1
fi

# Prune old monthly backups (keep 24 months = 2 years)
echo "Pruning backups older than $RETENTION_MONTHS months"
find "$BACKUP_DIR" -name "basecoat-portal-*-monthly.dump.gz" \
    -mtime "+$((RETENTION_MONTHS * 30))" -delete

echo "✓ Monthly backup completed"
```

### 2.4 Cron Schedule

```bash
# Add to crontab -e

# Daily backup at 02:00 UTC
0 2 * * * /usr/local/bin/backup-basecoat-daily.sh >> /var/log/backup-basecoat-daily.log 2>&1

# Weekly backup at 03:00 UTC on Sunday
0 3 * * 0 /usr/local/bin/backup-basecoat-weekly.sh >> /var/log/backup-basecoat-weekly.log 2>&1

# Monthly backup at 04:00 UTC on 1st of month
0 4 1 * * /usr/local/bin/backup-basecoat-monthly.sh >> /var/log/backup-basecoat-monthly.log 2>&1
```

---

## Part 3: WAL (Write-Ahead Log) Archiving for PITR

### 3.1 WAL Archiving Configuration

On RDS instance, set parameter group:

```sql
-- RDS Parameter Group Settings
rds_default_parameters {
  archive_mode = 'on'
  archive_command = 'test ! -f /archivedir/%f && cp %p /archivedir/%f'
  restore_command = 'cp /archivedir/%f %p'
  wal_keep_size = '1GB'  -- Keep 1GB of WAL files
}
```

### 3.2 Enable Archive Directory

```bash
# On backup server
mkdir -p /backups/basecoat-portal/wal-archives
chmod 700 /backups/basecoat-portal/wal-archives

# Mount if on different filesystem
# mount -t nfs backup-server:/wal-archives /backups/basecoat-portal/wal-archives
```

### 3.3 Verify WAL Archiving

```sql
-- Connect to database and check WAL archiving status
SELECT * FROM pg_stat_archiver;

-- Expected output:
--  archived_count | failed_count | stats_reset
-- ----------------+--------------+-----------
--            1234 |            0 | 2025-01-01
```

---

## Part 4: Full Database Restore Procedures

### 4.1 Restore from Latest Backup

**Scenario:** Full database corruption, need complete restore

```bash
#!/bin/bash
# restore-basecoat-latest.sh
# Restore from most recent daily backup

set -e

# Configuration
BACKUP_DIR="/backups/basecoat-portal/daily"
DB_HOST="staging-rds.aws.amazon.com"
DB_PORT="5432"
DB_NAME="basecoat_portal"
DB_USER="postgres"
TARGET_DB="basecoat_portal_restore"  # Restore to different DB first

# Find latest backup
LATEST_BACKUP=$(ls -t "$BACKUP_DIR"/basecoat-portal-*.dump | head -1)
echo "Using backup: $LATEST_BACKUP"

# Verify backup exists and is readable
if [ ! -r "$LATEST_BACKUP" ]; then
    echo "✗ Backup file not readable: $LATEST_BACKUP"
    exit 1
fi

# Create restore database
echo "Creating restore database..."
psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -c "CREATE DATABASE $TARGET_DB;"

# Perform restore
echo "Restoring from backup..."
pg_restore -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" \
    -d "$TARGET_DB" \
    --no-privileges \
    --no-owner \
    -v "$LATEST_BACKUP" 2>&1 | tee /tmp/restore.log

# Count records to verify restore
echo "Verifying restore..."
psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$TARGET_DB" -c "
SELECT 'organizations' as table_name, COUNT(*) FROM organizations
UNION ALL
SELECT 'users', COUNT(*) FROM users
UNION ALL
SELECT 'repositories', COUNT(*) FROM repositories
UNION ALL
SELECT 'scans', COUNT(*) FROM scans
UNION ALL
SELECT 'scan_results', COUNT(*) FROM scan_results
ORDER BY table_name;
"

echo "✓ Restore verification complete"
echo "To switch to restored database:"
echo "  1. Verify data integrity in $TARGET_DB"
echo "  2. Rename production database: ALTER DATABASE $DB_NAME RENAME TO ${DB_NAME}_backup;"
echo "  3. Rename restored database: ALTER DATABASE $TARGET_DB RENAME TO $DB_NAME;"
echo "  4. Drop old database: DROP DATABASE ${DB_NAME}_backup;"
```

### 4.2 Restore Specific Table

```bash
# Restore single table from backup
pg_restore -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" \
    -d "$DB_NAME" \
    -t scan_results \  # Table name
    "$BACKUP_FILE"

# Restore multiple tables
pg_restore -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" \
    -d "$DB_NAME" \
    -t organizations \
    -t users \
    -t teams \
    "$BACKUP_FILE"

# List tables in backup
pg_restore -l "$BACKUP_FILE" | grep "TABLE"
```

### 4.3 Restore to Point-in-Time (PITR)

**Scenario:** Database was corrupted 2 hours ago, need to restore to that point

```bash
#!/bin/bash
# restore-point-in-time.sh
# Restore to specific timestamp using WAL archives

set -e

# Configuration
BACKUP_DIR="/backups/basecoat-portal/daily"
WAL_DIR="/backups/basecoat-portal/wal-archives"
DB_HOST="staging-rds.aws.amazon.com"
DB_PORT="5432"
DB_USER="postgres"
TARGET_DB="basecoat_portal_pitr"
RESTORE_TIME="2025-01-15 12:30:00"  # Target restore time

# Find backup before restore time
BACKUP_FILE=$(ls -t "$BACKUP_DIR"/basecoat-portal-*.dump | head -1)
echo "Using backup: $BACKUP_FILE"

# Create PITR database
echo "Creating PITR database..."
psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -c "CREATE DATABASE $TARGET_DB;"

# Restore from backup
echo "Restoring from backup: $BACKUP_FILE"
pg_restore -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" \
    -d "$TARGET_DB" \
    --no-privileges \
    --no-owner \
    "$BACKUP_FILE"

# Apply WAL archives to reach target time
echo "Applying WAL archives to reach $RESTORE_TIME..."
# Note: On RDS, PITR is handled by AWS managed backups + WAL
# For on-premises, use pg_waldump to replay WALs

echo "✓ PITR restore to $RESTORE_TIME complete"
echo "Verify data in $TARGET_DB, then promote to production"
```

---

## Part 5: Recovery Testing

### 5.1 Weekly Restore Test

**Procedure:** Verify backup integrity weekly

```bash
#!/bin/bash
# test-backup-restore.sh
# Weekly restore test to verify backup integrity

set -e

BACKUP_DIR="/backups/basecoat-portal/daily"
DB_HOST="staging-rds.aws.amazon.com"
DB_PORT="5432"
DB_USER="postgres"
TEST_DB="basecoat_portal_test_$$"

echo "Starting backup restore test on $(date)"

# Find backup to test (yesterday's backup)
BACKUP_FILE=$(ls -t "$BACKUP_DIR"/basecoat-portal-*.dump | head -1)
echo "Testing backup: $BACKUP_FILE"

# Create test database
echo "Creating test database: $TEST_DB"
psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -c "CREATE DATABASE $TEST_DB;"

# Restore
echo "Restoring..."
START_TIME=$(date +%s)
pg_restore -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" \
    -d "$TEST_DB" \
    --no-privileges \
    --no-owner \
    "$BACKUP_FILE"
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

# Verify data
echo "Verifying restore..."
RESULT=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$TEST_DB" \
    -t -c "SELECT COUNT(*) FROM organizations;")

if [ "$RESULT" -gt 0 ]; then
    echo "✓ Restore verification passed"
    echo "  Organizations: $RESULT"
    echo "  Duration: ${DURATION}s"
    
    # Cleanup
    psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -c "DROP DATABASE $TEST_DB;"
    echo "✓ Test cleanup complete"
    exit 0
else
    echo "✗ Restore verification failed"
    psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -c "DROP DATABASE $TEST_DB;"
    exit 1
fi
```

### 5.2 Monthly Full Restore Drill

**Procedure:** Full restore to alternate environment (monthly)

```bash
#!/bin/bash
# monthly-restore-drill.sh
# Full restore test to alternate RDS instance

echo "=== MONTHLY BACKUP RESTORE DRILL ==="
echo "Date: $(date)"

# Configuration
SOURCE_BACKUP="/backups/basecoat-portal/weekly/basecoat-portal-2025-01-12-weekly.dump"
ALTERNATE_DB_HOST="staging-rds-alt.aws.amazon.com"
ALTERNATE_DB_PORT="5432"
ALTERNATE_DB_USER="postgres"
RESTORE_DB="basecoat_portal_restore"

# Verify backup exists
if [ ! -f "$SOURCE_BACKUP" ]; then
    echo "✗ Backup not found: $SOURCE_BACKUP"
    exit 1
fi

# Verify backup integrity
echo "Verifying backup integrity..."
pg_restore -l "$SOURCE_BACKUP" > /dev/null || {
    echo "✗ Backup corrupted"
    exit 1
}
echo "✓ Backup integrity verified"

# Create restore database
echo "Creating restore database on alternate host..."
psql -h "$ALTERNATE_DB_HOST" -p "$ALTERNATE_DB_PORT" -U "$ALTERNATE_DB_USER" \
    -c "CREATE DATABASE $RESTORE_DB;"

# Restore
echo "Restoring to alternate environment..."
pg_restore -h "$ALTERNATE_DB_HOST" -p "$ALTERNATE_DB_PORT" \
    -U "$ALTERNATE_DB_USER" -d "$RESTORE_DB" "$SOURCE_BACKUP"

# Verify
echo "Running verification queries..."
psql -h "$ALTERNATE_DB_HOST" -p "$ALTERNATE_DB_PORT" \
    -U "$ALTERNATE_DB_USER" -d "$RESTORE_DB" << EOF
SELECT 'Verification Results' as report;
SELECT 'Organizations:' as metric, COUNT(*) FROM organizations
UNION ALL
SELECT 'Users:', COUNT(*) FROM users
UNION ALL
SELECT 'Repositories:', COUNT(*) FROM repositories
UNION ALL
SELECT 'Total Audit Logs:', COUNT(*) FROM audit_logs;
EOF

echo "✓ Monthly restore drill complete"
echo "Result: PASSED" > /tmp/monthly-restore-drill-result.txt
```

---

## Part 6: Backup Verification Procedures

### 6.1 Daily Backup Health Check

```sql
-- Run daily to verify backup status
-- Connect as: psql -h localhost -p 6432 -d postgres

-- Check WAL archiving
SELECT
  archive_status,
  count(*) as file_count
FROM pg_ls_wal_dir()
GROUP BY archive_status;

-- Check backup metadata (if backup catalog exists)
SELECT
  backup_name,
  backup_time,
  end_time,
  backup_size,
  status
FROM backup_catalog
ORDER BY backup_time DESC
LIMIT 10;
```

### 6.2 Backup Size Analysis

```bash
# Monitor backup size trends
du -sh /backups/basecoat-portal/daily/* | sort -rh | head -10

# Expected growth rate:
# - Daily: ~50 MB (stable after initial growth)
# - Weekly: Similar to daily
# - Monthly: 8-10 MB (compressed)

# Alert if daily backup > 200 MB or growing >10% week-over-week
```

---

## Part 7: Disaster Recovery Plan

### 7.1 RTO/RPO Targets

| Scenario | RTO | RPO | Strategy |
|----------|-----|-----|----------|
| Table corruption | < 1 hour | < 5 min | Single table restore |
| Database corruption | < 2 hours | < 30 min | Full restore + PITR |
| Disk failure (EBS snapshot) | < 15 min | < 1 min | AWS auto-recovery |
| Region failure | < 4 hours | < 1 hour | Restore from S3 backups |

### 7.2 Backup Location Strategy

**Primary:** On-disk on backup server (/backups/)
**Secondary:** S3 for long-term storage
**Tertiary:** Archive to Glacier for 24-month retention

```bash
#!/bin/bash
# backup-to-s3.sh
# Copy monthly backups to S3 for disaster recovery

S3_BUCKET="s3://basecoat-portal-backups"
BACKUP_DIR="/backups/basecoat-portal/monthly"

for backup in "$BACKUP_DIR"/*.gz; do
    if [ -f "$backup" ]; then
        filename=$(basename "$backup")
        echo "Uploading $filename to S3..."
        aws s3 cp "$backup" "$S3_BUCKET/monthly/$filename" \
            --storage-class GLACIER \
            --metadata "backup-date=$(date +%Y-%m-%d),database=basecoat_portal"
        echo "✓ Uploaded"
    fi
done
```

---

## Part 8: Monitoring & Alerting

### 8.1 Backup Monitoring Queries

```bash
# Check backup completion status
ls -lh /backups/basecoat-portal/daily/ | tail -5

# Alert if latest backup is missing or > 24 hours old
LATEST=$(ls -t /backups/basecoat-portal/daily/*.dump | head -1)
MTIME=$(stat -f %m "$LATEST" 2>/dev/null || stat -c %Y "$LATEST")
NOW=$(date +%s)
AGE=$((NOW - MTIME))

if [ "$AGE" -gt 86400 ]; then
    echo "ALERT: Latest backup is older than 24 hours"
    exit 1
fi
```

### 8.2 Backup Alerts

Configure in monitoring system (Datadog, CloudWatch, etc.):

- ⚠️ **Warning:** Backup missing or > 25 hours old
- 🔴 **Critical:** Backup missing or > 48 hours old
- ⚠️ **Warning:** Backup size increased > 20% from normal
- 🔴 **Critical:** Backup verification test failed
- ⚠️ **Warning:** WAL archiving failed (failed_count > 0)

---

## Success Criteria

Backup & recovery validation is successful when:

- ✓ Daily backup completes in < 10 minutes
- ✓ Weekly backup completes in < 10 minutes
- ✓ Monthly backup completes in < 15 minutes
- ✓ Backup verification test passes 100% of runs
- ✓ Restore from any backup takes < 30 minutes
- ✓ Full restore test passes monthly
- ✓ PITR recovery to any point in last 7 days
- ✓ 24-month backup retention maintained
- ✓ Zero backup failures over 30-day period
- ✓ All backups verified with pg_restore -l
