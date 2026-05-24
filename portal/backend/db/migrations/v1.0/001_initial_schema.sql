-- ============================================================================
-- Basecoat Portal Database Schema v1.0
-- Complete DDL Script for PostgreSQL 14+
-- ============================================================================
-- This script creates all tables, constraints, indexes, and extensions
-- for the Basecoat Portal governance and security audit system.
-- ============================================================================

-- Extension Dependencies
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
CREATE EXTENSION IF NOT EXISTS "btree_gin";
CREATE EXTENSION IF NOT EXISTS "btree_gist";

-- ============================================================================
-- TABLE: organizations (Multi-tenancy root)
-- ============================================================================
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
    
    CONSTRAINT chk_org_slug_length CHECK (length(slug) >= 3),
    CONSTRAINT chk_org_plan CHECK (plan IN ('free', 'pro', 'enterprise')),
    CONSTRAINT chk_retention_days CHECK (data_retention_days > 0)
);

CREATE INDEX idx_organizations_slug ON organizations(slug);
CREATE INDEX idx_organizations_plan ON organizations(plan);
CREATE INDEX idx_organizations_created ON organizations(created_at DESC);

-- ============================================================================
-- TABLE: users (GitHub-integrated identity)
-- ============================================================================
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
    
    CONSTRAINT chk_user_role CHECK (role IN ('admin', 'user', 'readonly')),
    CONSTRAINT chk_user_email CHECK (email ~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}$')
);

CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_github_id ON users(github_id);
CREATE INDEX idx_users_github_login ON users(github_login);
CREATE INDEX idx_users_is_active ON users(is_active);
CREATE INDEX idx_users_created ON users(created_at DESC);

-- ============================================================================
-- TABLE: teams (Organization subdivision)
-- ============================================================================
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
CREATE INDEX idx_teams_created ON teams(created_at DESC);

-- ============================================================================
-- TABLE: team_members (Bridge table for many-to-many relationship)
-- ============================================================================
CREATE TABLE team_members (
    team_id UUID NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role VARCHAR(50) NOT NULL DEFAULT 'member',
    joined_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    PRIMARY KEY (team_id, user_id),
    CONSTRAINT chk_tm_role CHECK (role IN ('admin', 'member', 'readonly'))
);

CREATE INDEX idx_team_members_user_id ON team_members(user_id);
CREATE INDEX idx_team_members_role ON team_members(role);

-- ============================================================================
-- TABLE: roles (RBAC - Role-based access control)
-- ============================================================================
CREATE TABLE roles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    permissions JSONB NOT NULL DEFAULT '[]'::jsonb,
    is_custom BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE(org_id, name)
);

CREATE INDEX idx_roles_org_id ON roles(org_id);
CREATE INDEX idx_roles_is_custom ON roles(is_custom);

-- ============================================================================
-- TABLE: repositories (Scanning targets)
-- ============================================================================
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
CREATE INDEX idx_repositories_last_scanned ON repositories(last_scanned_at DESC);
CREATE INDEX idx_repositories_org_active ON repositories(org_id, is_active);

-- ============================================================================
-- TABLE: scans (Audit events - each scan execution)
-- ============================================================================
CREATE TABLE scans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    repo_id UUID NOT NULL REFERENCES repositories(id) ON DELETE CASCADE,
    scan_type VARCHAR(50) NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'pending',
    started_at TIMESTAMP WITH TIME ZONE NOT NULL,
    completed_at TIMESTAMP WITH TIME ZONE,
    summary JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT chk_scan_type CHECK (scan_type IN ('security', 'compliance', 'code_quality', 'sca')),
    CONSTRAINT chk_scan_status CHECK (status IN ('pending', 'in_progress', 'completed', 'failed', 'cancelled')),
    CONSTRAINT chk_scan_time CHECK (completed_at IS NULL OR completed_at >= started_at)
);

CREATE INDEX idx_scans_repo_id ON scans(repo_id);
CREATE INDEX idx_scans_status ON scans(status);
CREATE INDEX idx_scans_created_at ON scans(created_at DESC);
CREATE INDEX idx_scans_repo_created ON scans(repo_id, created_at DESC);
CREATE INDEX idx_scans_type_status ON scans(scan_type, status);
CREATE INDEX idx_scans_pending ON scans(status) WHERE status IN ('pending', 'in_progress');

-- ============================================================================
-- TABLE: scan_results (Findings from scans)
-- ============================================================================
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
    
    CONSTRAINT chk_severity CHECK (severity IN ('critical', 'high', 'medium', 'low', 'info')),
    CONSTRAINT chk_finding_count CHECK (count > 0)
);

CREATE INDEX idx_scan_results_scan_id ON scan_results(scan_id);
CREATE INDEX idx_scan_results_severity ON scan_results(severity);
CREATE INDEX idx_scan_results_finding_type ON scan_results(finding_type);
CREATE INDEX idx_scan_results_cve ON scan_results(cve_id);
CREATE INDEX idx_scan_results_scan_severity ON scan_results(scan_id, severity DESC);
CREATE INDEX idx_scan_results_critical ON scan_results(scan_id) WHERE severity = 'critical';

-- ============================================================================
-- TABLE: compliance_issues (Tracking remediation progress)
-- ============================================================================
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
    
    CONSTRAINT chk_ci_status CHECK (status IN ('open', 'in_progress', 'resolved', 'wontfix')),
    CONSTRAINT chk_ci_severity CHECK (severity IN ('critical', 'high', 'medium', 'low'))
);

CREATE INDEX idx_compliance_issues_repo_id ON compliance_issues(repo_id);
CREATE INDEX idx_compliance_issues_status ON compliance_issues(status);
CREATE INDEX idx_compliance_issues_assigned_to ON compliance_issues(assigned_to);
CREATE INDEX idx_compliance_issues_due_date ON compliance_issues(due_date);
CREATE INDEX idx_compliance_issues_repo_status ON compliance_issues(repo_id, status);
CREATE INDEX idx_compliance_issues_open ON compliance_issues(repo_id) WHERE status IN ('open', 'in_progress');

-- ============================================================================
-- TABLE: audit_logs (Immutable append-only audit trail)
-- ============================================================================
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
CREATE INDEX idx_audit_logs_timestamp ON audit_logs(timestamp DESC);
CREATE INDEX idx_audit_logs_entity ON audit_logs(entity_type, entity_id);
CREATE INDEX idx_audit_logs_org_timestamp ON audit_logs(org_id, timestamp DESC);
CREATE INDEX idx_audit_logs_user_timestamp ON audit_logs(user_id, timestamp DESC);

-- ============================================================================
-- TABLE: simulations (Chaos/resilience testing)
-- ============================================================================
CREATE TABLE simulations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    repo_id UUID NOT NULL REFERENCES repositories(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    config JSONB NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'draft',
    results JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT chk_sim_status CHECK (status IN ('draft', 'scheduled', 'running', 'completed', 'failed'))
);

CREATE INDEX idx_simulations_repo_id ON simulations(repo_id);
CREATE INDEX idx_simulations_status ON simulations(status);
CREATE INDEX idx_simulations_created ON simulations(created_at DESC);

-- ============================================================================
-- TABLE: simulation_runs (Execution history)
-- ============================================================================
CREATE TABLE simulation_runs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sim_id UUID NOT NULL REFERENCES simulations(id) ON DELETE CASCADE,
    scenario VARCHAR(255),
    outcome VARCHAR(50),
    details JSONB,
    duration_ms INT,
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT chk_outcome CHECK (outcome IN ('success', 'partial', 'failed'))
);

CREATE INDEX idx_simulation_runs_sim_id ON simulation_runs(sim_id);
CREATE INDEX idx_simulation_runs_timestamp ON simulation_runs(timestamp DESC);

-- ============================================================================
-- TABLE: reports (Aggregated insights)
-- ============================================================================
CREATE TABLE reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    report_type VARCHAR(50) NOT NULL,
    title VARCHAR(255) NOT NULL,
    data JSONB NOT NULL,
    visibility VARCHAR(50) NOT NULL DEFAULT 'org',
    generated_by UUID REFERENCES users(id) ON DELETE SET NULL,
    generated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT chk_report_type CHECK (report_type IN ('compliance', 'security', 'audit', 'dashboard')),
    CONSTRAINT chk_visibility CHECK (visibility IN ('private', 'team', 'org', 'enterprise'))
);

CREATE INDEX idx_reports_org_id ON reports(org_id);
CREATE INDEX idx_reports_report_type ON reports(report_type);
CREATE INDEX idx_reports_generated_at ON reports(generated_at DESC);
CREATE INDEX idx_reports_org_type ON reports(org_id, report_type);

-- ============================================================================
-- Audit Log Triggers (for immutability verification)
-- ============================================================================

-- Prevent UPDATE/DELETE on audit_logs
CREATE OR REPLACE FUNCTION prevent_audit_modification()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'Audit logs are immutable and cannot be modified';
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_audit_logs_immutable
    BEFORE UPDATE OR DELETE ON audit_logs
    FOR EACH ROW
    EXECUTE FUNCTION prevent_audit_modification();

-- ============================================================================
-- Updated Timestamp Triggers
-- ============================================================================

CREATE OR REPLACE FUNCTION update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_organizations_updated
    BEFORE UPDATE ON organizations
    FOR EACH ROW
    EXECUTE FUNCTION update_timestamp();

CREATE TRIGGER trg_users_updated
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION update_timestamp();

CREATE TRIGGER trg_teams_updated
    BEFORE UPDATE ON teams
    FOR EACH ROW
    EXECUTE FUNCTION update_timestamp();

CREATE TRIGGER trg_repositories_updated
    BEFORE UPDATE ON repositories
    FOR EACH ROW
    EXECUTE FUNCTION update_timestamp();

CREATE TRIGGER trg_simulations_updated
    BEFORE UPDATE ON simulations
    FOR EACH ROW
    EXECUTE FUNCTION update_timestamp();

-- ============================================================================
-- Views for Common Queries
-- ============================================================================

-- Org scan summary
CREATE OR REPLACE VIEW v_org_scan_summary AS
SELECT 
    o.id,
    o.name,
    o.slug,
    COUNT(DISTINCT r.id)::INT as repo_count,
    COUNT(DISTINCT s.id)::INT as total_scans,
    COUNT(DISTINCT s.id) FILTER (WHERE s.status = 'in_progress')::INT as in_progress_scans,
    COUNT(DISTINCT sr.id) FILTER (WHERE sr.severity = 'critical')::INT as critical_findings,
    COUNT(DISTINCT sr.id) FILTER (WHERE sr.severity = 'high')::INT as high_findings,
    MAX(s.completed_at) as last_scan_time
FROM organizations o
LEFT JOIN repositories r ON o.id = r.org_id
LEFT JOIN scans s ON r.id = s.repo_id
LEFT JOIN scan_results sr ON s.id = sr.scan_id AND s.status = 'completed'
GROUP BY o.id, o.name, o.slug;

-- Repository scan status
CREATE OR REPLACE VIEW v_repository_status AS
SELECT 
    r.id,
    r.name,
    r.url,
    r.last_scanned_at,
    COUNT(s.id)::INT as total_scans,
    COUNT(s.id) FILTER (WHERE s.status = 'completed')::INT as completed_scans,
    COUNT(sr.id) FILTER (WHERE sr.severity IN ('critical', 'high'))::INT as urgent_findings,
    MAX(CASE WHEN sr.severity = 'critical' THEN 1 ELSE 0 END) as has_critical
FROM repositories r
LEFT JOIN scans s ON r.id = s.repo_id
LEFT JOIN scan_results sr ON s.id = sr.scan_id AND s.status = 'completed'
WHERE r.is_active = TRUE
GROUP BY r.id, r.name, r.url, r.last_scanned_at;

-- Compliance tracking
CREATE OR REPLACE VIEW v_compliance_summary AS
SELECT 
    r.id as repo_id,
    r.name as repo_name,
    COUNT(DISTINCT ci.id)::INT as total_issues,
    COUNT(DISTINCT ci.id) FILTER (WHERE ci.status = 'open')::INT as open_issues,
    COUNT(DISTINCT ci.id) FILTER (WHERE ci.status = 'in_progress')::INT as in_progress,
    COUNT(DISTINCT ci.id) FILTER (WHERE ci.severity = 'critical' AND ci.status IN ('open', 'in_progress'))::INT as overdue_critical
FROM repositories r
LEFT JOIN compliance_issues ci ON r.id = ci.repo_id
GROUP BY r.id, r.name;

-- ============================================================================
-- Schema End
-- ============================================================================
