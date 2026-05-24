#!/bin/bash
# ============================================================================
# Basecoat Portal - Database Backup Script
# Automated backup with retention policy
# ============================================================================
# Usage: ./backup.sh [daily|weekly|monthly]
# ============================================================================

set -euo pipefail

# Configuration
BACKUP_BASE_DIR="/backups/basecoat-portal"
DB_NAME="${DB_NAME:-basecoat_portal}"
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_USER="${DB_USER:-postgres}"
RETENTION_DAILY=14  # days
RETENTION_WEEKLY=12 # weeks
RETENTION_MONTHLY=24 # months

# Create backup directory
mkdir -p "$BACKUP_BASE_DIR"/{daily,weekly,monthly}

# Determine backup type
BACKUP_TYPE="${1:-daily}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
DATE_ONLY=$(date +%Y%m%d)
WEEK_NUM=$(date +%W)
MONTH=$(date +%Y%m)

case "$BACKUP_TYPE" in
    daily)
        BACKUP_FILE="$BACKUP_BASE_DIR/daily/basecoat_portal_${DATE_ONLY}.dump"
        RETAIN_DAYS=$RETENTION_DAILY
        ;;
    weekly)
        BACKUP_FILE="$BACKUP_BASE_DIR/weekly/basecoat_portal_week${WEEK_NUM}.dump"
        RETAIN_DAYS=$((RETENTION_WEEKLY * 7))
        ;;
    monthly)
        BACKUP_FILE="$BACKUP_BASE_DIR/monthly/basecoat_portal_${MONTH}.dump.gz"
        RETAIN_DAYS=$((RETENTION_MONTHLY * 30))
        ;;
    *)
        echo "Invalid backup type. Use: daily, weekly, or monthly"
        exit 1
        ;;
esac

# Function: backup database
backup_database() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] Starting $BACKUP_TYPE backup of $DB_NAME..."
    
    if [ "$BACKUP_TYPE" = "monthly" ]; then
        pg_dump \
            -h "$DB_HOST" \
            -p "$DB_PORT" \
            -U "$DB_USER" \
            -Fc \
            "$DB_NAME" | gzip > "$BACKUP_FILE"
    else
        pg_dump \
            -h "$DB_HOST" \
            -p "$DB_PORT" \
            -U "$DB_USER" \
            -Fc \
            "$DB_NAME" > "$BACKUP_FILE"
    fi
    
    local backup_size=$(du -h "$BACKUP_FILE" | cut -f1)
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] Backup complete: $BACKUP_FILE ($backup_size)"
}

# Function: prune old backups
prune_backups() {
    local backup_dir=$1
    local retention_days=$2
    
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] Pruning backups older than $retention_days days..."
    
    find "$backup_dir" -name "basecoat_portal*" -type f -mtime +$retention_days -delete
}

# Execute backup
backup_database

# Prune old backups
case "$BACKUP_TYPE" in
    daily)
        prune_backups "$BACKUP_BASE_DIR/daily" $RETENTION_DAILY
        ;;
    weekly)
        prune_backups "$BACKUP_BASE_DIR/weekly" $((RETENTION_WEEKLY * 7))
        ;;
    monthly)
        prune_backups "$BACKUP_BASE_DIR/monthly" $((RETENTION_MONTHLY * 30))
        ;;
esac

echo "[$(date +'%Y-%m-%d %H:%M:%S')] Backup process completed successfully"
exit 0
