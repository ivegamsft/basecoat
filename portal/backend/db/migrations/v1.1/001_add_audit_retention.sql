-- ============================================================================
-- Basecoat Portal - Migration v1.1 Template
-- Non-breaking schema evolution
-- ============================================================================
-- Version: 1.1
-- Previous: v1.0
-- Breaking Changes: None
-- Migration Time Estimate: < 5 minutes
-- ============================================================================

-- Migration: 001_add_audit_retention_policy.sql
-- Purpose: Add data retention configuration to organizations table

BEGIN;

-- Add retention policy tracking column
ALTER TABLE organizations 
ADD COLUMN IF NOT EXISTS audit_retention_enabled BOOLEAN DEFAULT TRUE;

-- Create audit retention policies table
CREATE TABLE IF NOT EXISTS audit_retention_policies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL UNIQUE REFERENCES organizations(id) ON DELETE CASCADE,
    retention_days INT NOT NULL CHECK (retention_days > 0),
    archive_to_cold_storage BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_audit_retention_org_id ON audit_retention_policies(org_id);

-- Populate retention policies from existing org settings
INSERT INTO audit_retention_policies (org_id, retention_days, archive_to_cold_storage)
SELECT id, data_retention_days, FALSE FROM organizations
ON CONFLICT DO NOTHING;

-- Create archival log table for tracking
CREATE TABLE IF NOT EXISTS audit_log_archives (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    min_audit_id BIGINT NOT NULL,
    max_audit_id BIGINT NOT NULL,
    record_count INT NOT NULL,
    archive_location VARCHAR(255),
    archived_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_audit_archives_org ON audit_log_archives(org_id);
CREATE INDEX IF NOT EXISTS idx_audit_archives_timestamp ON audit_log_archives(archived_at DESC);

COMMIT;

-- Rollback procedure: 001_rollback_retention_policy.sql
-- To undo this migration, execute:
/*
BEGIN;
    DROP TABLE IF EXISTS audit_log_archives CASCADE;
    DROP TABLE IF EXISTS audit_retention_policies CASCADE;
    ALTER TABLE organizations DROP COLUMN IF EXISTS audit_retention_enabled;
COMMIT;
*/

-- ============================================================================
-- Migration: 002_add_severity_to_compliance_issues.sql
-- Purpose: Ensure all compliance issues have severity (backfill defaults)

BEGIN;

-- Add constraint if not exists (column already exists in v1.0)
-- This ensures consistency for any issues created without severity
UPDATE compliance_issues 
SET severity = 'medium' 
WHERE severity IS NULL;

ALTER TABLE compliance_issues 
ALTER COLUMN severity SET NOT NULL;

COMMIT;

-- Rollback procedure:
/*
BEGIN;
    ALTER TABLE compliance_issues 
    ALTER COLUMN severity DROP NOT NULL;
COMMIT;
*/

-- ============================================================================
-- Verification Queries
-- Execute these to verify migration success

-- Check new tables exist
SELECT 
    schemaname,
    tablename
FROM pg_tables
WHERE tablename IN ('audit_retention_policies', 'audit_log_archives')
AND schemaname = 'public';

-- Verify retention policies populated
SELECT COUNT(*) as retention_policies_count FROM audit_retention_policies;

-- Check compliance issues severity is NOT NULL
SELECT 
    COUNT(*) as total,
    COUNT(*) FILTER (WHERE severity IS NOT NULL) as with_severity,
    COUNT(*) FILTER (WHERE severity IS NULL) as null_severity
FROM compliance_issues;

-- View organizations with retention settings
SELECT 
    id,
    name,
    audit_retention_enabled,
    data_retention_days,
    (SELECT retention_days FROM audit_retention_policies WHERE org_id = organizations.id) as policy_retention
FROM organizations
LIMIT 5;
