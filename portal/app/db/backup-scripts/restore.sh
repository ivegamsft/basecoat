#!/bin/bash
# ============================================================================
# Basecoat Portal - Database Restore Script
# Safe restore with pre/post checks
# ============================================================================
# Usage: ./restore.sh <backup_file> [target_database]
# Example: ./restore.sh /backups/daily/basecoat_portal_20250505.dump
# ============================================================================

set -euo pipefail

# Configuration
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_USER="${DB_USER:-postgres}"

# Validate arguments
if [ $# -lt 1 ]; then
    echo "Usage: $0 <backup_file> [target_database]"
    echo "Example: $0 /backups/daily/basecoat_portal_20250505.dump"
    exit 1
fi

BACKUP_FILE="$1"
TARGET_DB="${2:-basecoat_portal}"
TIMESTAMP=$(date +%s)
TEMP_DB="restore_temp_${TIMESTAMP}"

# Validate backup file
if [ ! -f "$BACKUP_FILE" ]; then
    echo "ERROR: Backup file not found: $BACKUP_FILE"
    exit 1
fi

echo "[$(date +'%Y-%m-%d %H:%M:%S')] Starting restore process"
echo "  Backup file: $BACKUP_FILE"
echo "  Target database: $TARGET_DB"
echo "  Temp database: $TEMP_DB"

# Function: restore to temp database
restore_to_temp() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] Creating temporary database..."
    createdb -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" "$TEMP_DB"
    
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] Restoring from backup..."
    if [[ "$BACKUP_FILE" == *.gz ]]; then
        gunzip -c "$BACKUP_FILE" | pg_restore -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$TEMP_DB"
    else
        pg_restore -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$TEMP_DB" "$BACKUP_FILE"
    fi
}

# Function: verify restored database
verify_restore() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] Verifying restored data..."
    
    local tables=(organizations users teams repositories scans scan_results audit_logs)
    
    for table in "${tables[@]}"; do
        local count=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$TEMP_DB" -tc "SELECT COUNT(*) FROM $table")
        echo "  $table: $count rows"
    done
    
    # Check referential integrity
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] Checking referential integrity..."
    psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$TEMP_DB" << EOF
    -- Check for orphaned records
    SELECT COUNT(*) FROM scan_results sr 
    WHERE NOT EXISTS (SELECT 1 FROM scans s WHERE s.id = sr.scan_id);
    
    SELECT COUNT(*) FROM compliance_issues ci 
    WHERE NOT EXISTS (SELECT 1 FROM repositories r WHERE r.id = ci.repo_id);
EOF
}

# Function: swap databases
swap_databases() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] Swapping databases..."
    
    # Disconnect all users
    psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d postgres << EOF
    SELECT pg_terminate_backend(pg_stat_activity.pid)
    FROM pg_stat_activity
    WHERE pg_stat_activity.datname = '$TARGET_DB'
    AND pid <> pg_backend_pid();
EOF
    
    # Rename old database
    OLD_DB="${TARGET_DB}_backup_${TIMESTAMP}"
    psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d postgres -c "ALTER DATABASE \"$TARGET_DB\" RENAME TO \"$OLD_DB\""
    
    # Rename new database
    psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d postgres -c "ALTER DATABASE \"$TEMP_DB\" RENAME TO \"$TARGET_DB\""
    
    echo "  Old database backed up as: $OLD_DB"
}

# Function: cleanup on error
cleanup() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] Cleaning up temporary database..."
    psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d postgres -c "DROP DATABASE IF EXISTS \"$TEMP_DB\"" 2>/dev/null || true
}

# Main restore process
trap cleanup EXIT

restore_to_temp
verify_restore

echo "[$(date +'%Y-%m-%d %H:%M:%S')] Ready to swap databases"
read -p "Proceed with database swap? (yes/no): " confirm

if [ "$confirm" = "yes" ]; then
    swap_databases
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] RESTORE COMPLETE"
else
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] Restore cancelled"
    exit 1
fi
