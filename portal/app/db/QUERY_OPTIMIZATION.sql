-- ============================================================================
-- Basecoat Portal - Query Optimization Playbook
-- Common patterns, anti-patterns, and best practices
-- ============================================================================

-- ============================================================================
-- 1. N+1 Query Prevention
-- ============================================================================

-- ❌ ANTI-PATTERN: N+1 queries in application loop
-- SELECT * FROM repositories WHERE org_id = $1;
-- LOOP over repos:
--   SELECT COUNT(*) FROM scans WHERE repo_id = repo.id
--   SELECT MAX(completed_at) FROM scans WHERE repo_id = repo.id

-- ✅ PATTERN: JOIN with aggregation (single query)
SELECT 
    r.id,
    r.name,
    COUNT(s.id)::INT as scan_count,
    MAX(s.completed_at) as last_scan,
    COUNT(sr.id) FILTER (WHERE sr.severity = 'critical')::INT as critical_count
FROM repositories r
LEFT JOIN scans s ON r.id = s.repo_id
LEFT JOIN scan_results sr ON s.id = sr.scan_id AND s.status = 'completed'
WHERE r.org_id = '00000000-0000-0000-0000-000000000001'
GROUP BY r.id, r.name
ORDER BY last_scan DESC;

-- ============================================================================
-- 2. Efficient Pagination
-- ============================================================================

-- ❌ ANTI-PATTERN: OFFSET with large numbers (slow full table scan)
SELECT * FROM scans OFFSET 1000000 LIMIT 50;

-- ✅ PATTERN: Keyset pagination (uses index directly)
SELECT * FROM scans 
WHERE created_at < $1  -- Cursor position
ORDER BY created_at DESC
LIMIT 50;

-- ✅ PATTERN: Alternative with ID cursor
SELECT * FROM audit_logs 
WHERE id < $1          -- Last seen ID
AND org_id = $2
ORDER BY id DESC
LIMIT 50;

-- ============================================================================
-- 3. Filtering by Status (Partial Indexes)
-- ============================================================================

-- ✅ Query that uses partial index (idx_scans_pending)
-- Time: ~10ms on 10M rows
SELECT COUNT(*) FROM scans 
WHERE status IN ('pending', 'in_progress')
AND repo_id = $1;

-- Without partial index would scan all rows:
-- Time: ~500ms on 10M rows
-- SELECT COUNT(*) FROM scans WHERE repo_id = $1

-- ============================================================================
-- 4. Severity Filtering with Composite Index
-- ============================================================================

-- ✅ Uses composite index (idx_scan_results_scan_severity)
-- Time: ~50ms on 5M rows
SELECT 
    id,
    finding_type,
    count,
    details
FROM scan_results
WHERE scan_id = $1
AND severity IN ('critical', 'high')
ORDER BY severity DESC;

-- Aggregate findings by severity (uses same index)
SELECT 
    severity,
    COUNT(*) as count,
    ARRAY_AGG(finding_type) as types
FROM scan_results
WHERE scan_id = $1
GROUP BY severity
ORDER BY CASE severity
    WHEN 'critical' THEN 1
    WHEN 'high' THEN 2
    WHEN 'medium' THEN 3
    WHEN 'low' THEN 4
    ELSE 5 END;

-- ============================================================================
-- 5. Efficient Time-Based Queries
-- ============================================================================

-- ✅ Uses index (idx_audit_logs_org_timestamp)
-- Time: ~30ms
SELECT 
    id,
    user_id,
    action,
    entity_type,
    timestamp
FROM audit_logs
WHERE org_id = $1
AND timestamp > CURRENT_TIMESTAMP - INTERVAL '7 days'
ORDER BY timestamp DESC
LIMIT 100;

-- ✅ Range query (still index-efficient)
SELECT COUNT(*) as daily_actions
FROM audit_logs
WHERE org_id = $1
AND timestamp >= CURRENT_DATE
AND timestamp < CURRENT_DATE + INTERVAL '1 day';

-- ❌ ANTI-PATTERN: Extracting date for filtering (disables index)
-- WHERE DATE(timestamp) = CURRENT_DATE  -- SLOW, disables index
-- WHERE timestamp::DATE = CURRENT_DATE  -- SLOW, disables index

-- ============================================================================
-- 6. JOIN Optimization
-- ============================================================================

-- ✅ Efficient multi-table join (no N+1)
SELECT 
    r.name as repo_name,
    s.scan_type,
    COUNT(sr.id) as finding_count,
    COUNT(sr.id) FILTER (WHERE sr.severity = 'critical') as critical
FROM repositories r
INNER JOIN scans s ON r.id = s.repo_id
LEFT JOIN scan_results sr ON s.id = sr.scan_id
WHERE r.org_id = $1
AND s.status = 'completed'
AND s.completed_at > CURRENT_DATE - INTERVAL '30 days'
GROUP BY r.id, r.name, s.id, s.scan_type
ORDER BY critical DESC;

-- ============================================================================
-- 7. JSONB Searching
-- ============================================================================

-- ✅ Using @> operator (works with GIN index)
SELECT 
    id,
    finding_type,
    details
FROM scan_results
WHERE details @> '{"severity_cvss": {"score": 9}}'::jsonb
LIMIT 10;

-- ✅ Using -> operator for nested access
SELECT 
    id,
    details ->> 'location' as location,
    (details -> 'line_numbers' ->> 'start')::INT as start_line
FROM scan_results
WHERE details::TEXT LIKE '%sql%'  -- Optional text search
LIMIT 20;

-- ✅ Array aggregation of JSONB
SELECT 
    scan_id,
    JSONB_AGG(details) as all_findings
FROM scan_results
WHERE severity = 'critical'
GROUP BY scan_id;

-- ❌ ANTI-PATTERN: Casting to TEXT for search (slower)
-- WHERE details::TEXT LIKE '%pattern%'  -- Better with full-text search

-- ============================================================================
-- 8. Aggregation Optimization
-- ============================================================================

-- ✅ Efficient org-level aggregation
SELECT 
    o.id,
    o.name,
    COUNT(DISTINCT r.id)::INT as repo_count,
    COUNT(DISTINCT s.id)::INT as total_scans,
    COUNT(DISTINCT s.id) FILTER (WHERE s.status = 'in_progress')::INT as in_progress,
    COUNT(sr.id) FILTER (WHERE sr.severity = 'critical')::INT as critical_findings,
    COUNT(sr.id) FILTER (WHERE sr.severity = 'high')::INT as high_findings,
    MAX(s.completed_at) as last_scan_time
FROM organizations o
LEFT JOIN repositories r ON o.id = r.org_id AND r.is_active = TRUE
LEFT JOIN scans s ON r.id = s.repo_id AND s.created_at > CURRENT_DATE - INTERVAL '90 days'
LEFT JOIN scan_results sr ON s.id = sr.scan_id AND s.status = 'completed'
GROUP BY o.id, o.name
ORDER BY critical_findings DESC;

-- ============================================================================
-- 9. Sorted Result Sets
-- ============================================================================

-- ✅ Uses index for order (idx_repositories_last_scanned DESC)
SELECT 
    name,
    url,
    last_scanned_at,
    scan_count
FROM repositories
WHERE org_id = $1 AND is_active = TRUE
ORDER BY last_scanned_at DESC
LIMIT 20;

-- ✅ Multi-column sort (uses index if column order matches)
SELECT 
    id,
    name,
    created_at
FROM teams
WHERE org_id = $1
ORDER BY created_at DESC, name ASC
LIMIT 50;

-- ============================================================================
-- 10. UNION vs OR (Which is faster?)
-- ============================================================================

-- ✅ UNION ALL (can use multiple indexes)
SELECT id, name, created_at FROM repositories WHERE org_id = $1 AND language = 'Go'
UNION ALL
SELECT id, name, created_at FROM repositories WHERE org_id = $1 AND is_active = FALSE
ORDER BY created_at DESC;

-- Alternative: OR with index merge (PostgreSQL usually chooses best)
SELECT id, name, created_at FROM repositories
WHERE org_id = $1 AND (language = 'Go' OR is_active = FALSE)
ORDER BY created_at DESC;

-- Test with EXPLAIN ANALYZE to see which is faster:
EXPLAIN ANALYZE SELECT ...

-- ============================================================================
-- 11. EXISTS vs IN (Correlated Subqueries)
-- ============================================================================

-- ✅ EXISTS (usually faster for large subsets)
SELECT 
    r.id,
    r.name
FROM repositories r
WHERE EXISTS (
    SELECT 1 FROM scans s
    WHERE s.repo_id = r.id
    AND s.status = 'in_progress'
);

-- ✅ IN with subquery (good for small result sets)
SELECT 
    r.id,
    r.name
FROM repositories r
WHERE r.id IN (
    SELECT repo_id FROM scans
    WHERE status = 'in_progress'
);

-- ❌ ANTI-PATTERN: Correlated subquery in SELECT (slow)
-- SELECT id, name, (SELECT COUNT(*) FROM scans s WHERE s.repo_id = r.id)
-- FROM repositories r;

-- ✅ BETTER: Use JOIN with GROUP BY
-- SELECT r.id, r.name, COUNT(s.id)
-- FROM repositories r
-- LEFT JOIN scans s ON r.id = s.repo_id
-- GROUP BY r.id, r.name;

-- ============================================================================
-- 12. Window Functions (Efficient Ranking)
-- ============================================================================

-- ✅ Rank repos by finding severity (no join repetition)
SELECT 
    r.id,
    r.name,
    sr.severity,
    COUNT(*) as count,
    ROW_NUMBER() OVER (PARTITION BY r.id ORDER BY COUNT(*) DESC) as rank
FROM repositories r
JOIN scans s ON r.id = s.repo_id
JOIN scan_results sr ON s.id = sr.scan_id
WHERE s.status = 'completed'
GROUP BY r.id, r.name, sr.severity
ORDER BY r.id, rank;

-- ✅ Find top N repos by critical findings
SELECT 
    r.id,
    r.name,
    critical_count,
    ROW_NUMBER() OVER (ORDER BY critical_count DESC) as rank
FROM (
    SELECT 
        r.id,
        r.name,
        COUNT(*) as critical_count
    FROM repositories r
    JOIN scans s ON r.id = s.repo_id
    JOIN scan_results sr ON s.id = sr.scan_id
    WHERE sr.severity = 'critical' AND s.status = 'completed'
    GROUP BY r.id, r.name
) ranked
WHERE ROW_NUMBER() OVER (ORDER BY critical_count DESC) <= 10;

-- ============================================================================
-- 13. CTE (Common Table Expressions) for Clarity
-- ============================================================================

-- ✅ CTE makes complex query readable
WITH recent_scans AS (
    SELECT 
        id,
        repo_id,
        scan_type,
        status,
        completed_at
    FROM scans
    WHERE completed_at > CURRENT_TIMESTAMP - INTERVAL '7 days'
),
critical_findings AS (
    SELECT 
        scan_id,
        finding_type,
        COUNT(*) as count
    FROM scan_results
    WHERE severity = 'critical'
    GROUP BY scan_id, finding_type
)
SELECT 
    r.name as repo_name,
    rs.scan_type,
    cf.finding_type,
    cf.count
FROM recent_scans rs
JOIN repositories r ON rs.repo_id = r.id
LEFT JOIN critical_findings cf ON rs.id = cf.scan_id
ORDER BY rs.completed_at DESC;

-- ============================================================================
-- 14. Query Execution Analysis
-- ============================================================================

-- Enable timing info
\timing

-- Analyze query plan (shows index usage)
EXPLAIN ANALYZE
SELECT * FROM scan_results 
WHERE scan_id = '00000000-0000-0000-0000-000000000001'
AND severity IN ('critical', 'high');

-- Verbose EXPLAIN (shows full details)
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT COUNT(*) FROM audit_logs
WHERE org_id = '00000000-0000-0000-0000-000000000001'
AND timestamp > CURRENT_TIMESTAMP - INTERVAL '7 days';

-- ============================================================================
-- 15. Query Performance Monitoring
-- ============================================================================

-- Find slowest queries (requires pg_stat_statements)
SELECT 
    mean_exec_time::INT as avg_ms,
    calls,
    SUBSTR(query, 1, 80) as query_snippet
FROM pg_stat_statements
WHERE query NOT LIKE '%pg_stat%'
ORDER BY mean_exec_time DESC
LIMIT 10;

-- Find queries with high I/O
SELECT 
    query,
    blk_read_time::INT as total_read_ms,
    blk_write_time::INT as total_write_ms
FROM pg_stat_statements
WHERE blk_read_time > 0
ORDER BY blk_read_time DESC
LIMIT 10;

-- ============================================================================
-- PERFORMANCE BASELINES (Target times on 10M audit_logs, 5M scan_results)
-- ============================================================================

-- Recent audit logs (7 days): < 50ms ✓ (idx_audit_logs_org_timestamp)
-- Org scan summary: < 200ms ✓ (composite join)
-- Critical findings by repo: < 100ms ✓ (idx_scan_results_critical)
-- Open compliance issues: < 75ms ✓ (idx_compliance_issues_open)
-- Pagination (keyset): < 30ms ✓ (no OFFSET needed)

-- ============================================================================
-- END OF OPTIMIZATION PLAYBOOK
-- ============================================================================
