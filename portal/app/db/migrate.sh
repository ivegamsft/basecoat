#!/bin/bash
# ============================================================================
# Basecoat Portal - Database Migration Runner
# Automated migration execution with tracking
# ============================================================================
# Usage: ./migrate.sh [version]
# Example: ./migrate.sh v1.1
# ============================================================================

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MIGRATIONS_DIR="$SCRIPT_DIR/migrations"
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-basecoat_portal}"
DB_USER="${DB_USER:-postgres}"

# Migration tracking
MIGRATIONS_TABLE="schema_migrations"

# Validate arguments
if [ $# -lt 1 ]; then
    echo "Usage: $0 <version>"
    echo "Available versions:"
    ls -d "$MIGRATIONS_DIR"/v* | xargs basename -a
    exit 1
fi

TARGET_VERSION="$1"
MIGRATION_PATH="$MIGRATIONS_DIR/$TARGET_VERSION"

if [ ! -d "$MIGRATION_PATH" ]; then
    echo "ERROR: Migration version not found: $TARGET_VERSION"
    exit 1
fi

echo "========================================"
echo "Basecoat Portal Database Migration"
echo "========================================"
echo "Target Version: $TARGET_VERSION"
echo "Database: $DB_NAME"
echo "Host: $DB_HOST:$DB_PORT"
echo ""

# Function: create migrations table if not exists
init_migrations_table() {
    psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" << EOF
    CREATE TABLE IF NOT EXISTS $MIGRATIONS_TABLE (
        id SERIAL PRIMARY KEY,
        version VARCHAR(50) NOT NULL UNIQUE,
        applied_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
    );
EOF
}

# Function: check if migration applied
is_migration_applied() {
    local version=$1
    local result=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -tAc "SELECT COUNT(*) FROM $MIGRATIONS_TABLE WHERE version = '$version'")
    [ "$result" -eq 1 ]
}

# Function: record migration
record_migration() {
    local version=$1
    psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" << EOF
    INSERT INTO $MIGRATIONS_TABLE (version) VALUES ('$version');
EOF
}

# Function: backup before migration
backup_before_migration() {
    local backup_file="$SCRIPT_DIR/backup-scripts/pre_migration_$(date +%s).dump"
    echo "Creating backup: $backup_file"
    pg_dump -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -Fc "$DB_NAME" > "$backup_file"
}

# Function: execute migration
execute_migration() {
    local version=$1
    local migration_dir="$MIGRATIONS_DIR/$version"
    
    if is_migration_applied "$version"; then
        echo "✓ Migration $version already applied"
        return 0
    fi
    
    echo "Applying migration: $version"
    
    # Get all migration files
    for migration_file in $(ls "$migration_dir"/*.sql 2>/dev/null | sort); do
        local filename=$(basename "$migration_file")
        echo "  Executing: $filename"
        
        if psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -f "$migration_file" > /dev/null 2>&1; then
            echo "  ✓ $filename completed"
        else
            echo "  ✗ $filename FAILED"
            return 1
        fi
    done
    
    record_migration "$version"
    echo "✓ Migration $version completed successfully"
}

# Main execution
init_migrations_table

read -p "Create backup before migration? (recommended) (yes/no): " backup_response
if [ "$backup_response" = "yes" ]; then
    backup_before_migration
fi

if execute_migration "$TARGET_VERSION"; then
    echo ""
    echo "========================================"
    echo "✓ Migration to $TARGET_VERSION complete"
    echo "========================================"
    
    # Show migration history
    echo ""
    echo "Applied migrations:"
    psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "SELECT version, applied_at FROM $MIGRATIONS_TABLE ORDER BY applied_at DESC;"
else
    echo ""
    echo "========================================"
    echo "✗ Migration FAILED"
    echo "========================================"
    exit 1
fi
