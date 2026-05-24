-- ============================================================================
-- Basecoat Portal - Seed Data v1.0
-- Sample data for testing and development
-- ============================================================================

-- Clear existing data (optional - comment out for production)
TRUNCATE TABLE reports, simulation_runs, simulations, audit_logs, 
              compliance_issues, scan_results, scans, repositories,
              team_members, teams, roles, users, organizations CASCADE;

-- ============================================================================
-- Organizations
-- ============================================================================
INSERT INTO organizations (name, slug, description, plan, data_retention_days) VALUES
    ('TechCorp Inc', 'techcorp', 'Enterprise SaaS platform company', 'enterprise', 365),
    ('StartupX', 'startupx', 'Early-stage fintech startup', 'pro', 90),
    ('OpenSource Foundation', 'opensource-foundation', 'Community-driven open source', 'free', 30);

-- Get org IDs for reference
WITH org_data AS (
    SELECT id, slug FROM organizations
)
SELECT * FROM org_data;

-- ============================================================================
-- Users
-- ============================================================================
INSERT INTO users (email, github_id, github_login, display_name, role, is_active) VALUES
    ('alice@techcorp.com', 123456789, 'alice-tc', 'Alice Chen', 'admin', TRUE),
    ('bob@techcorp.com', 987654321, 'bob-tc', 'Bob Smith', 'user', TRUE),
    ('charlie@startup.com', 555666777, 'charlie-sx', 'Charlie Davis', 'admin', TRUE),
    ('diana@startup.com', 111222333, 'diana-sx', 'Diana Rodriguez', 'user', TRUE),
    ('eve@opensource.org', 444555666, 'eve-os', 'Eve Johnson', 'user', TRUE),
    ('frank@techcorp.com', 777888999, 'frank-tc', 'Frank Wilson', 'readonly', TRUE),
    ('grace@techcorp.com', 999888777, 'grace-tc', 'Grace Kim', 'user', FALSE);

-- ============================================================================
-- Teams
-- ============================================================================
INSERT INTO teams (org_id, name, slug, description)
SELECT 
    (SELECT id FROM organizations WHERE slug = 'techcorp'),
    'Platform Security',
    'platform-security',
    'Security and compliance team'
UNION ALL
SELECT 
    (SELECT id FROM organizations WHERE slug = 'techcorp'),
    'Backend Infrastructure',
    'backend-infra',
    'Backend and infrastructure team'
UNION ALL
SELECT 
    (SELECT id FROM organizations WHERE slug = 'startupx'),
    'Full Stack Team',
    'full-stack',
    'All-purpose development team'
UNION ALL
SELECT 
    (SELECT id FROM organizations WHERE slug = 'opensource-foundation'),
    'Core Contributors',
    'core-contributors',
    'Main project contributors';

-- ============================================================================
-- Team Members
-- ============================================================================
INSERT INTO team_members (team_id, user_id, role, joined_at)
SELECT 
    (SELECT id FROM teams WHERE slug = 'platform-security' LIMIT 1),
    (SELECT id FROM users WHERE github_login = 'alice-tc'),
    'admin',
    NOW() - INTERVAL '6 months'
UNION ALL
SELECT 
    (SELECT id FROM teams WHERE slug = 'platform-security' LIMIT 1),
    (SELECT id FROM users WHERE github_login = 'frank-tc'),
    'member',
    NOW() - INTERVAL '3 months'
UNION ALL
SELECT 
    (SELECT id FROM teams WHERE slug = 'backend-infra' LIMIT 1),
    (SELECT id FROM users WHERE github_login = 'bob-tc'),
    'member',
    NOW() - INTERVAL '12 months'
UNION ALL
SELECT 
    (SELECT id FROM teams WHERE slug = 'full-stack' LIMIT 1),
    (SELECT id FROM users WHERE github_login = 'charlie-sx'),
    'admin',
    NOW() - INTERVAL '12 months'
UNION ALL
SELECT 
    (SELECT id FROM teams WHERE slug = 'full-stack' LIMIT 1),
    (SELECT id FROM users WHERE github_login = 'diana-sx'),
    'member',
    NOW() - INTERVAL '9 months'
UNION ALL
SELECT 
    (SELECT id FROM teams WHERE slug = 'core-contributors' LIMIT 1),
    (SELECT id FROM users WHERE github_login = 'eve-os'),
    'member',
    NOW() - INTERVAL '24 months';

-- ============================================================================
-- Roles
-- ============================================================================
INSERT INTO roles (org_id, name, permissions, is_custom) VALUES
-- TechCorp roles
(
    (SELECT id FROM organizations WHERE slug = 'techcorp'),
    'Security Lead',
    '["manage_scans", "view_results", "manage_compliance", "view_audit_logs"]'::jsonb,
    TRUE
),
(
    (SELECT id FROM organizations WHERE slug = 'techcorp'),
    'Compliance Officer',
    '["view_results", "manage_compliance", "view_audit_logs", "generate_reports"]'::jsonb,
    TRUE
),
-- Default roles (all orgs get these)
(
    (SELECT id FROM organizations WHERE slug = 'techcorp'),
    'Admin',
    '["manage_teams", "manage_users", "manage_repositories", "view_audit_logs", "manage_compliance"]'::jsonb,
    FALSE
);

-- ============================================================================
-- Repositories
-- ============================================================================
INSERT INTO repositories (org_id, name, url, description, is_active, language) VALUES
-- TechCorp repos
(
    (SELECT id FROM organizations WHERE slug = 'techcorp'),
    'api-gateway',
    'https://github.com/techcorp/api-gateway',
    'Main API gateway for service mesh',
    TRUE,
    'Go'
),
(
    (SELECT id FROM organizations WHERE slug = 'techcorp'),
    'auth-service',
    'https://github.com/techcorp/auth-service',
    'Authentication and authorization service',
    TRUE,
    'Python'
),
(
    (SELECT id FROM organizations WHERE slug = 'techcorp'),
    'data-pipeline',
    'https://github.com/techcorp/data-pipeline',
    'ETL data processing pipeline',
    TRUE,
    'Scala'
),
(
    (SELECT id FROM organizations WHERE slug = 'techcorp'),
    'legacy-monolith',
    'https://github.com/techcorp/legacy-monolith',
    'Legacy monolithic application',
    TRUE,
    'Java'
),
-- StartupX repos
(
    (SELECT id FROM organizations WHERE slug = 'startupx'),
    'trading-engine',
    'https://github.com/startupx/trading-engine',
    'Core trading engine',
    TRUE,
    'Rust'
),
(
    (SELECT id FROM organizations WHERE slug = 'startupx'),
    'web-dashboard',
    'https://github.com/startupx/web-dashboard',
    'React web dashboard',
    TRUE,
    'TypeScript'
),
-- OpenSource repos
(
    (SELECT id FROM organizations WHERE slug = 'opensource-foundation'),
    'open-framework',
    'https://github.com/opensource/open-framework',
    'Core framework library',
    TRUE,
    'C++'
);

-- ============================================================================
-- Scans
-- ============================================================================
INSERT INTO scans (repo_id, scan_type, status, started_at, completed_at, summary) VALUES
-- Recent completed scans
(
    (SELECT id FROM repositories WHERE name = 'api-gateway' LIMIT 1),
    'security',
    'completed',
    NOW() - INTERVAL '2 days',
    NOW() - INTERVAL '2 days' + INTERVAL '15 minutes',
    '{"duration_seconds": 900, "files_scanned": 245, "dependencies_checked": 87}'::jsonb
),
(
    (SELECT id FROM repositories WHERE name = 'auth-service' LIMIT 1),
    'security',
    'completed',
    NOW() - INTERVAL '1 day',
    NOW() - INTERVAL '1 day' + INTERVAL '20 minutes',
    '{"duration_seconds": 1200, "files_scanned": 156, "dependencies_checked": 52}'::jsonb
),
(
    (SELECT id FROM repositories WHERE name = 'auth-service' LIMIT 1),
    'compliance',
    'completed',
    NOW() - INTERVAL '1 day',
    NOW() - INTERVAL '1 day' + INTERVAL '10 minutes',
    '{"duration_seconds": 600, "policies_checked": 24, "passed": 18, "failed": 6}'::jsonb
),
(
    (SELECT id FROM repositories WHERE name = 'data-pipeline' LIMIT 1),
    'code_quality',
    'completed',
    NOW() - INTERVAL '12 hours',
    NOW() - INTERVAL '12 hours' + INTERVAL '25 minutes',
    '{"duration_seconds": 1500, "files_scanned": 89, "coverage": 78.5}'::jsonb
),
(
    (SELECT id FROM repositories WHERE name = 'trading-engine' LIMIT 1),
    'security',
    'completed',
    NOW() - INTERVAL '4 hours',
    NOW() - INTERVAL '4 hours' + INTERVAL '18 minutes',
    '{"duration_seconds": 1080, "files_scanned": 234, "dependencies_checked": 123}'::jsonb
),
-- In-progress scan
(
    (SELECT id FROM repositories WHERE name = 'web-dashboard' LIMIT 1),
    'security',
    'in_progress',
    NOW() - INTERVAL '30 minutes',
    NULL,
    NULL
),
-- Pending scan
(
    (SELECT id FROM repositories WHERE name = 'legacy-monolith' LIMIT 1),
    'compliance',
    'pending',
    NOW() - INTERVAL '5 minutes',
    NULL,
    NULL
),
-- Failed scan
(
    (SELECT id FROM repositories WHERE name = 'open-framework' LIMIT 1),
    'sca',
    'failed',
    NOW() - INTERVAL '8 hours',
    NOW() - INTERVAL '8 hours' + INTERVAL '5 minutes',
    '{"error": "Timeout scanning dependencies", "files_attempted": 156}'::jsonb
);

-- ============================================================================
-- Scan Results
-- ============================================================================
INSERT INTO scan_results (scan_id, finding_type, severity, count, details, remediation_steps, cve_id) VALUES
-- api-gateway security findings
(
    (SELECT id FROM scans WHERE repo_id = (SELECT id FROM repositories WHERE name = 'api-gateway' LIMIT 1) 
     AND scan_type = 'security' LIMIT 1),
    'SQL Injection Vulnerability',
    'critical',
    2,
    '{"location": "src/handlers/query.go:156-162", "description": "Unsanitized user input in SQL query"}'::jsonb,
    '["Validate and parameterize all database queries", "Use prepared statements", "Add input validation layer"]'::jsonb,
    'CVE-2024-1234'
),
(
    (SELECT id FROM scans WHERE repo_id = (SELECT id FROM repositories WHERE name = 'api-gateway' LIMIT 1) 
     AND scan_type = 'security' LIMIT 1),
    'Exposed API Key',
    'critical',
    1,
    '{"location": ".env.example", "description": "Production API key visible in example config"}'::jsonb,
    '["Remove all credentials from version control", "Use secrets manager", "Rotate exposed keys"]'::jsonb,
    NULL
),
(
    (SELECT id FROM scans WHERE repo_id = (SELECT id FROM repositories WHERE name = 'api-gateway' LIMIT 1) 
     AND scan_type = 'security' LIMIT 1),
    'Outdated Dependencies',
    'high',
    5,
    '{"dependencies": ["lodash@4.17.15", "express@4.16.2"]}'::jsonb,
    '["Update to latest patched versions", "Review breaking changes", "Run integration tests"]'::jsonb,
    NULL
),
(
    (SELECT id FROM scans WHERE repo_id = (SELECT id FROM repositories WHERE name = 'api-gateway' LIMIT 1) 
     AND scan_type = 'security' LIMIT 1),
    'Missing Security Headers',
    'medium',
    1,
    '{"header": "X-Content-Type-Options", "description": "Missing MIME type sniffing protection"}'::jsonb,
    '["Add X-Content-Type-Options: nosniff", "Review security headers policy"]'::jsonb,
    NULL
),
-- auth-service findings
(
    (SELECT id FROM scans WHERE repo_id = (SELECT id FROM repositories WHERE name = 'auth-service' LIMIT 1) 
     AND scan_type = 'security' LIMIT 1),
    'Weak Cryptography',
    'high',
    1,
    '{"algorithm": "MD5", "location": "src/crypto/hash.py:23", "description": "MD5 used for password hashing"}'::jsonb,
    '["Replace MD5 with bcrypt or argon2", "Rehash all existing passwords", "Add salt to hashing function"]'::jsonb,
    NULL
),
-- trading-engine findings
(
    (SELECT id FROM scans WHERE repo_id = (SELECT id FROM repositories WHERE name = 'trading-engine' LIMIT 1) 
     AND scan_type = 'security' LIMIT 1),
    'Race Condition',
    'high',
    1,
    '{"location": "src/engine/order_processing.rs:234-245", "description": "Non-atomic order processing"}'::jsonb,
    '["Use mutex locks for order state", "Implement transaction isolation", "Add unit tests for concurrency"]'::jsonb,
    NULL
),
-- data-pipeline code quality findings
(
    (SELECT id FROM scans WHERE repo_id = (SELECT id FROM repositories WHERE name = 'data-pipeline' LIMIT 1) 
     AND scan_type = 'code_quality' LIMIT 1),
    'Low Test Coverage',
    'medium',
    1,
    '{"coverage_percent": 68.5, "uncovered_lines": 245, "files": ["src/transform.scala", "src/validation.scala"]}'::jsonb,
    '["Add unit tests for transform functions", "Increase coverage to >80%", "Add integration tests"]'::jsonb,
    NULL
),
(
    (SELECT id FROM scans WHERE repo_id = (SELECT id FROM repositories WHERE name = 'data-pipeline' LIMIT 1) 
     AND scan_type = 'code_quality' LIMIT 1),
    'Code Complexity',
    'low',
    3,
    '{"metric": "cyclomatic_complexity", "threshold": 10, "violations": 3}'::jsonb,
    '["Refactor complex functions into smaller units", "Extract helper methods"]'::jsonb,
    NULL
);

-- ============================================================================
-- Compliance Issues
-- ============================================================================
INSERT INTO compliance_issues (repo_id, issue_type, status, severity, assigned_to, due_date, description) VALUES
-- auth-service compliance
(
    (SELECT id FROM repositories WHERE name = 'auth-service' LIMIT 1),
    'GDPR Data Retention',
    'in_progress',
    'critical',
    (SELECT id FROM users WHERE github_login = 'alice-tc'),
    CURRENT_DATE + INTERVAL '7 days',
    'User data not being deleted after 30-day retention period'
),
(
    (SELECT id FROM repositories WHERE name = 'auth-service' LIMIT 1),
    'SOC 2 Audit Logging',
    'open',
    'high',
    (SELECT id FROM users WHERE github_login = 'frank-tc'),
    CURRENT_DATE + INTERVAL '14 days',
    'Insufficient audit logging for authentication failures'
),
-- api-gateway compliance
(
    (SELECT id FROM repositories WHERE name = 'api-gateway' LIMIT 1),
    'Data Encryption in Transit',
    'resolved',
    'critical',
    (SELECT id FROM users WHERE github_login = 'bob-tc'),
    CURRENT_DATE - INTERVAL '30 days',
    'HTTPS not enforced on all endpoints',
    'Implemented HTTPS redirect and HSTS headers'
),
-- trading-engine compliance
(
    (SELECT id FROM repositories WHERE name = 'trading-engine' LIMIT 1),
    'PCI DSS Compliance',
    'open',
    'critical',
    (SELECT id FROM users WHERE github_login = 'charlie-sx'),
    CURRENT_DATE + INTERVAL '21 days',
    'Payment card data handled without proper encryption'
);

-- ============================================================================
-- Audit Logs
-- ============================================================================
INSERT INTO audit_logs (org_id, user_id, action, entity_type, entity_id, changes, ip_address, user_agent) VALUES
-- Sample audit trail
(
    (SELECT id FROM organizations WHERE slug = 'techcorp'),
    (SELECT id FROM users WHERE github_login = 'alice-tc'),
    'scan_initiated',
    'scan',
    (SELECT id::TEXT FROM scans WHERE repo_id = (SELECT id FROM repositories WHERE name = 'api-gateway' LIMIT 1) LIMIT 1),
    '{"scan_type": "security", "status": "pending"}'::jsonb,
    '192.168.1.100'::inet,
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'
),
(
    (SELECT id FROM organizations WHERE slug = 'techcorp'),
    (SELECT id FROM users WHERE github_login = 'frank-tc'),
    'finding_reviewed',
    'scan_result',
    (SELECT id::TEXT FROM scan_results LIMIT 1),
    '{"severity": "critical", "acknowledged": true}'::jsonb,
    '192.168.1.101'::inet,
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)'
),
(
    (SELECT id FROM organizations WHERE slug = 'techcorp'),
    (SELECT id FROM users WHERE github_login = 'alice-tc'),
    'compliance_issue_updated',
    'compliance_issue',
    (SELECT id::TEXT FROM compliance_issues WHERE repo_id = (SELECT id FROM repositories WHERE name = 'auth-service' LIMIT 1) LIMIT 1),
    '{"status": "in_progress", "assigned_to": "frank-tc"}'::jsonb,
    '192.168.1.100'::inet,
    'Mozilla/5.0 (X11; Linux x86_64)'
),
(
    (SELECT id FROM organizations WHERE slug = 'startupx'),
    (SELECT id FROM users WHERE github_login = 'charlie-sx'),
    'repository_added',
    'repository',
    (SELECT id::TEXT FROM repositories WHERE name = 'trading-engine' LIMIT 1),
    '{"name": "trading-engine", "url": "https://github.com/startupx/trading-engine"}'::jsonb,
    '203.0.113.42'::inet,
    'Mozilla/5.0 (Windows NT 10.0)'
);

-- ============================================================================
-- Simulations
-- ============================================================================
INSERT INTO simulations (repo_id, name, config, status, results) VALUES
(
    (SELECT id FROM repositories WHERE name = 'api-gateway' LIMIT 1),
    'Network Latency Injection',
    '{"target": "service_mesh", "latency_ms": 500, "affected_percentage": 10}'::jsonb,
    'completed',
    '{"avg_response_time": 750, "error_rate": 0.02, "recovery_time_seconds": 45}'::jsonb
),
(
    (SELECT id FROM repositories WHERE name = 'auth-service' LIMIT 1),
    'Database Connection Pool Exhaustion',
    '{"connections_to_consume": 90, "duration_seconds": 300}'::jsonb,
    'draft',
    NULL
);

-- ============================================================================
-- Simulation Runs
-- ============================================================================
INSERT INTO simulation_runs (sim_id, scenario, outcome, details, duration_ms) VALUES
(
    (SELECT id FROM simulations WHERE name = 'Network Latency Injection' LIMIT 1),
    'Production traffic 10% latency',
    'success',
    '{"requests_processed": 1523, "timeout_count": 15, "recovered_successfully": true}'::jsonb,
    45000
),
(
    (SELECT id FROM simulations WHERE name = 'Network Latency Injection' LIMIT 1),
    'Production traffic 50% latency',
    'partial',
    '{"requests_processed": 892, "timeout_count": 178, "circuit_breaker_triggered": true}'::jsonb,
    62000
);

-- ============================================================================
-- Reports
-- ============================================================================
INSERT INTO reports (org_id, report_type, title, data, visibility, generated_by) VALUES
(
    (SELECT id FROM organizations WHERE slug = 'techcorp'),
    'security',
    'May 2025 Security Findings Summary',
    '{
        "period": "2025-05-01 to 2025-05-04",
        "critical_count": 3,
        "high_count": 8,
        "medium_count": 12,
        "repositories_scanned": 4,
        "top_finding_types": ["SQL Injection", "Exposed Credentials", "Outdated Dependencies"]
    }'::jsonb,
    'org',
    (SELECT id FROM users WHERE github_login = 'alice-tc')
),
(
    (SELECT id FROM organizations WHERE slug = 'techcorp'),
    'compliance',
    'Q2 2025 Compliance Status',
    '{
        "total_issues": 5,
        "open": 3,
        "in_progress": 2,
        "resolved_this_quarter": 8,
        "critical_overdue": 1
    }'::jsonb,
    'org',
    (SELECT id FROM users WHERE github_login = 'frank-tc')
),
(
    (SELECT id FROM organizations WHERE slug = 'startupx'),
    'audit',
    'User Access Activity Log',
    '{
        "period": "Last 7 days",
        "total_actions": 234,
        "users_active": 3,
        "scans_executed": 12,
        "configurations_changed": 3
    }'::jsonb,
    'team',
    (SELECT id FROM users WHERE github_login = 'diana-sx')
);

-- ============================================================================
-- Summary Statistics
-- ============================================================================
SELECT 'SEED DATA SUMMARY' as entity, COUNT(*) as count FROM organizations
UNION ALL SELECT 'users', COUNT(*) FROM users
UNION ALL SELECT 'teams', COUNT(*) FROM teams
UNION ALL SELECT 'team_members', COUNT(*) FROM team_members
UNION ALL SELECT 'repositories', COUNT(*) FROM repositories
UNION ALL SELECT 'scans', COUNT(*) FROM scans
UNION ALL SELECT 'scan_results', COUNT(*) FROM scan_results
UNION ALL SELECT 'compliance_issues', COUNT(*) FROM compliance_issues
UNION ALL SELECT 'audit_logs', COUNT(*) FROM audit_logs
UNION ALL SELECT 'simulations', COUNT(*) FROM simulations
UNION ALL SELECT 'simulation_runs', COUNT(*) FROM simulation_runs
UNION ALL SELECT 'reports', COUNT(*) FROM reports
ORDER BY count DESC;
