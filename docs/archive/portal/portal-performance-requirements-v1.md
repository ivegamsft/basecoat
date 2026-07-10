# Basecoat Portal Wave 3 — Performance Requirements

## Executive Summary

This document defines comprehensive performance requirements, scalability strategies, load testing procedures, and optimization strategies for the Basecoat Portal Wave 3. The portal is designed to serve 100–1000+ concurrent users with a focus on governance, security audit, and compliance tracking capabilities.

### Performance Targets

| Layer | Metric | Target | Percentile |
|-------|--------|--------|-----------|
| Frontend | Page Load Time | < 2s | 90th |
| API | Response Time | < 500ms | 99th |
| Database | Query Time | < 100ms | Average |
| Reports | Generation Time | < 30s | 99th |
| UI | Interactive Time | < 100ms | 99th |

---

## 1. Performance Targets

### 1.1 Frontend Performance

**Page Load Time Target**: < 2 seconds (90th percentile)

- **Measurement**: Time from navigation start to fully interactive (Largest Contentful Paint + interaction handler availability)
- **Components**:
  - Initial HTML download: < 500ms
  - CSS parsing and render-blocking: < 300ms
  - JavaScript parse and execute: < 400ms
  - Resource loading (images, fonts): < 800ms
  - Hydration/interactivity: < 100ms

**Core Web Vitals Requirements**:
- **LCP (Largest Contentful Paint)**: < 2.5s
- **FID (First Input Delay)**: < 100ms
- **CLS (Cumulative Layout Shift)**: < 0.1

---

### 1.2 API Response Time

**Response Time Target**: < 500ms (99th percentile)

- **Breakdown by endpoint type**:
  - **Read endpoints**: < 200ms (99th percentile)
  - **Write endpoints**: < 300ms (99th percentile)
  - **Aggregation endpoints**: < 500ms (99th percentile)
  - **Batch endpoints**: < 1s (99th percentile)

**Includes**:
- Network latency: ~50ms (Azure intra-region)
- Backend processing: ~150–300ms
- Database query: < 100ms
- Cache hit response: < 10ms

---

### 1.3 Database Performance

**Query Time Target**: < 100ms (average), < 250ms (95th percentile)

- **Index-backed queries**: < 10ms
- **Aggregation queries**: < 50ms
- **Join queries (≤ 3 tables)**: < 50ms
- **Batch queries (≤ 100 rows)**: < 100ms
- **Full table scans**: Eliminated via indexing

**Connection Pool**: 50 connections max per pod, 150 connections max across 3-pod cluster

---

### 1.4 Report Generation

**Report Generation Target**: < 30 seconds (99th percentile)

- **Small reports (< 1000 rows)**: < 5s
- **Medium reports (1000–10,000 rows)**: < 15s
- **Large reports (10,000+ rows)**: < 30s
- **Executive dashboards**: < 2s (cached, pre-aggregated)

---

### 1.5 UI Interactivity

**Time to Interactive (TTI)**: < 100ms (99th percentile)

- **Button click response**: < 50ms
- **Scroll responsiveness**: 60 FPS (16.67ms per frame)
- **Modal/overlay display**: < 100ms
- **Form field focus/blur**: < 50ms

---

## 2. Scalability Analysis

### 2.1 Deployment Tiers

#### Tier 1: 100 Concurrent Users
- **Pod Replicas**: 1
- **Pod Spec**: 2 CPU, 4GB RAM
- **Database**: Single-instance (Azure Database for PostgreSQL - Flexible Server)
- **Cache**: Single-node Redis (6GB)
- **Storage**: 100GB database, 20GB cache hotset
- **Expected Load**: ~200 requests/second (RPS)

#### Tier 2: 500 Concurrent Users
- **Pod Replicas**: 2 (load-balanced)
- **Pod Spec**: 2 CPU, 4GB RAM per pod (4 CPU, 8GB total)
- **Database**: Primary + read replica (async replication)
- **Cache**: 2-node Redis cluster (12GB distributed)
- **Storage**: 250GB database, 50GB cache hotset
- **Expected Load**: ~1000 RPS

#### Tier 3: 1000+ Concurrent Users (Multi-Region)
- **Pod Replicas**: 3 per region × N regions (9+ pods minimum)
- **Pod Spec**: 2 CPU, 4GB RAM per pod (6 CPU, 12GB per region)
- **Database**: Multi-primary cluster (cross-region replication, RTT < 100ms)
- **Cache**: Redis Cluster mode (30GB distributed, 3 shards × 2 replicas)
- **Storage**: 500GB+ database, 150GB cache hotset per region
- **Expected Load**: 5000+ RPS

### 2.2 Scalability Metrics

| Metric | Tier 1 | Tier 2 | Tier 3 |
|--------|--------|--------|--------|
| Concurrent Users | 100 | 500 | 1000+ |
| RPS | ~200 | ~1000 | 5000+ |
| Pod Count | 1 | 2 | 3+ per region |
| P99 Latency | < 400ms | < 500ms | < 600ms |
| Database Connections | 25–40 | 50–80 | 150+ |
| Cache Hit Ratio | > 70% | > 75% | > 80% |

### 2.3 Horizontal Scaling Strategy

**Kubernetes Autoscaling**:
- **HPA Trigger 1**: CPU > 70% → add pod (max 5 per deployment)
- **HPA Trigger 2**: Memory > 80% → add pod
- **HPA Cooldown**: 2 minutes after scale-up, 5 minutes after scale-down
- **Target Load**: 40 RPS per pod (scale-up at 70 RPS, scale-down at 30 RPS)

**Database Scaling**:
- Read replicas added at Tier 2; read-heavy queries routed via connection pool
- Connection pool overflow → circuit breaker (fail fast at 150 connections)

**Cache Scaling**:
- Redis eviction policy: `allkeys-lru` (least recently used)
- Memory pressure threshold: 85% triggers auto-scaling/cluster expansion

---

## 3. Load Testing Strategy

### 3.1 Load Testing Tools & Setup

**Primary Tool**: Apache JMeter or k6 (script-based, portable)

**Test Environment**:
- Staging cluster matching production (same pod/DB config per tier)
- Network isolation: Dedicated subnet, no production traffic
- Baseline: Current production metrics captured before each test

### 3.2 Load Test Types

#### 3.2.1 Baseline Test
**Objective**: Establish performance baseline at normal load

- **User Count**: 100 (Tier 1)
- **Duration**: 10 minutes
- **Ramp-up**: 2 minutes (0 → 100)
- **Think Time**: 5 seconds (user pacing)
- **Success Criteria**:
  - P99 API latency < 500ms
  - Error rate < 0.5%
  - CPU utilization < 50%
  - Memory utilization < 60%

#### 3.2.2 Ramp-Up Test
**Objective**: Validate scaling behavior as load increases

- **Phase 1**: 100 users for 10 min
- **Phase 2**: Ramp to 500 users over 10 min
- **Phase 3**: 500 users for 10 min
- **Phase 4**: Ramp to 1000 users over 10 min
- **Phase 5**: 1000 users for 10 min
- **Total Duration**: 50 minutes
- **Success Criteria**:
  - Pod scaling completes within 2 min
  - P99 latency remains < 600ms during scaling
  - No connection timeouts
  - Cache hit ratio maintained > 70%

#### 3.2.3 Soak Test
**Objective**: Detect memory leaks, connection exhaustion, and degradation over time

- **User Count**: 500 (Tier 2)
- **Duration**: 24 hours
- **Request Distribution**:
  - 40% read (dashboard, audit logs)
  - 40% API queries (governance data)
  - 20% reports (aggregations)
- **Success Criteria**:
  - Memory stable (< 5% growth over 24h)
  - Connection count stable
  - P99 latency drift < 10%
  - Error rate < 0.1%
  - No pod restarts

#### 3.2.4 Spike Test
**Objective**: Validate behavior under sudden load surge

- **Phase 1**: 100 users for 5 min (baseline)
- **Phase 2**: Instantly jump to 1000 users for 10 min
- **Phase 3**: Return to 100 users
- **Success Criteria**:
  - P99 latency spike < 2s (temporary acceptable)
  - Error rate < 1% during spike
  - Auto-scaling triggers correctly
  - System recovers within 5 min post-spike
  - No circuit breaker triggers

#### 3.2.5 Stress Test
**Objective**: Identify breaking point and degradation curve

- **Starting Load**: 100 users
- **Ramp-up**: +100 users every 5 minutes until failure
- **Failure Criteria**:
  - Error rate > 5%
  - P99 latency > 5s
  - Pod crash loop detected
  - Database connection exhaustion
- **Expected Breaking Point**: 2000–3000 RPS (well above Tier 3 targets)

### 3.3 Test Scenarios

**User Journey 1: Security Auditor**
```
1. Login (POST /auth/login) - 1s
2. View dashboard (GET /api/dashboard) - 3s
3. Filter audit logs (GET /api/audit-logs?filter=...) - 2s
4. View log details (GET /api/audit-logs/{id}) - 1s
5. Export report (POST /api/reports/export) - 5s
6. Logout (POST /auth/logout) - 1s
```

**User Journey 2: Compliance Manager**
```
1. Login - 1s
2. View governance policies (GET /api/policies) - 2s
3. Update policy (PATCH /api/policies/{id}) - 2s
4. View compliance status (GET /api/compliance/status) - 3s
5. Generate compliance report (POST /api/reports/compliance) - 8s
6. Logout - 1s
```

**User Journey 3: System Administrator**
```
1. Login - 1s
2. View system metrics (GET /api/admin/metrics) - 2s
3. Update configuration (PATCH /api/admin/config) - 2s
4. View logs (GET /api/admin/logs) - 3s
5. Logout - 1s
```

---

## 4. Database Optimization Strategy

### 4.1 Indexing Strategy

**Mandatory Indexes**:
- `audit_logs (timestamp DESC, user_id, action)` — for log filtering
- `policies (org_id, created_at DESC)` — for policy listing
- `compliance_status (org_id, status, updated_at DESC)` — for dashboard
- `users (email UNIQUE)` — for authentication
- `teams (org_id, team_id UNIQUE)` — for team lookups

**Composite Indexes**:
```sql
CREATE INDEX idx_audit_logs_org_user_time ON audit_logs(org_id, user_id, timestamp DESC);
CREATE INDEX idx_policies_org_status_time ON policies(org_id, status, created_at DESC);
CREATE INDEX idx_compliance_org_category ON compliance_status(org_id, category, status);
```

**Full-Text Search**:
```sql
CREATE INDEX idx_policies_search ON policies USING GIN(to_tsvector('english', name || ' ' || description));
```

### 4.2 Query Optimization

**N+1 Query Prevention**:
- Use JOIN instead of loop + query
- Use batch loading: `SELECT * FROM policies WHERE org_id = ANY($1::uuid[])`
- Implement query result caching (Redis)

**Connection Pool Configuration**:
- Min connections: 10
- Max connections: 50 per pod
- Idle timeout: 30 minutes
- Max lifetime: 60 minutes

### 4.3 Materialized Views

**For Dashboard (refreshed every 5 min)**:
```sql
CREATE MATERIALIZED VIEW dashboard_summary AS
SELECT org_id, COUNT(*) audit_count, 
       COUNT(DISTINCT user_id) user_count,
       MAX(timestamp) last_audit
FROM audit_logs
WHERE timestamp > NOW() - INTERVAL '7 days'
GROUP BY org_id;
```

**For Compliance Status**:
```sql
CREATE MATERIALIZED VIEW compliance_snapshot AS
SELECT org_id, category, status, COUNT(*) count
FROM compliance_status
GROUP BY org_id, category, status;
```

### 4.4 Prepared Statements

All queries use parameterized statements to prevent SQL injection and improve query plan caching:
```sql
PREPARE login_user AS
  SELECT id, email, password_hash FROM users WHERE email = $1;

PREPARE fetch_audit_logs AS
  SELECT * FROM audit_logs 
  WHERE org_id = $1 AND timestamp > $2 
  ORDER BY timestamp DESC 
  LIMIT $3;
```

---

## 5. API Optimization Strategy

### 5.1 Response Compression

**GZIP Compression**:
- Enable on all endpoints returning > 1KB
- Compression level: 6 (balance speed/compression)
- Exclude: Binary formats (images, PDFs)

**Content Negotiation**:
- Clients request preferred encoding: `Accept-Encoding: gzip, deflate, br`
- Server responds with `Content-Encoding: gzip`

### 5.2 Pagination & Filtering

**Pagination**:
```json
{
  "data": [...],
  "pagination": {
    "page": 1,
    "per_page": 100,
    "total": 5000,
    "total_pages": 50
  }
}
```
- Default: 100 items/page
- Max: 500 items/page
- Use cursor-based pagination for large result sets

**Server-Side Filtering**:
```
GET /api/audit-logs?org_id=abc&action=POLICY_UPDATE&timestamp_after=2024-01-01&limit=100
```

**Server-Side Sorting**:
```
GET /api/policies?sort=-created_at,name&limit=50
```

### 5.3 Caching Headers

| Endpoint Type | Cache-Control | TTL |
|---|---|---|
| Dashboard | `public, max-age=300` | 5 min |
| Audit Logs | `private, max-age=60` | 1 min |
| Policies | `public, max-age=600` | 10 min |
| User Data | `private, no-cache` | — |
| Reports | `private, max-age=3600` | 1 hour |

**ETag Support**:
- Generate ETag from content hash
- Clients send `If-None-Match: "<etag>"`
- Server responds with 304 Not Modified (0 payload)

### 5.4 Lazy Loading & Async Operations

**Lazy Load Related Data**:
```json
{
  "policy": {
    "id": "abc",
    "name": "Security Policy",
    "_links": {
      "audit_logs": "/api/policies/abc/audit-logs"
    }
  }
}
```

**Async Report Generation**:
```json
POST /api/reports
{
  "type": "compliance",
  "org_id": "abc"
}

Response: 202 Accepted
{
  "task_id": "task-xyz",
  "status_url": "/api/reports/task-xyz/status",
  "estimated_time": 15
}
```

### 5.5 API Versioning

- URL-based versioning: `/api/v1/policies`, `/api/v2/policies`
- Support 2 major versions simultaneously
- Deprecation headers: `Deprecation: true`, `Sunset: Sun, 31 Dec 2024 23:59:59 GMT`

---

## 6. Frontend Optimization Strategy

### 6.1 Code Splitting & Lazy Loading

**Route-Based Code Splitting**:
```javascript
const Dashboard = React.lazy(() => import('./pages/Dashboard'));
const Policies = React.lazy(() => import('./pages/Policies'));
const Reports = React.lazy(() => import('./pages/Reports'));
```

**Component-Level Lazy Loading**:
```javascript
const AuditLog = React.lazy(() => import('./components/AuditLog'));
```

**Lazy Load Resources**:
- Load analytics scripts (Datadog, etc.) after page interactive
- Load web fonts asynchronously
- Defer non-critical CSS

### 6.2 Image Optimization

**Responsive Images**:
```html
<picture>
  <source srcset="image-large.webp" media="(min-width: 1200px)" />
  <source srcset="image-medium.webp" media="(min-width: 768px)" />
  <source srcset="image-small.webp" media="(max-width: 767px)" />
  <img src="image-fallback.png" alt="description" loading="lazy" />
</picture>
```

**Format Priority**:
1. WebP (supported browsers)
2. AVIF (next-gen, < 10KB)
3. PNG/JPEG (fallback)

**Size Targets**:
- Small: < 50KB
- Medium: < 200KB
- Large: < 500KB

### 6.3 CSS & JavaScript Optimization

**CSS**:
- Minify: Remove whitespace, compress
- Critical CSS inlined in HTML (< 5KB)
- Non-critical CSS loaded asynchronously

**JavaScript**:
- Minify & tree-shake unused code
- Bundle splitting: Vendor (~200KB), App (~150KB), Pages (lazy-loaded)
- Source maps generated for production debugging

### 6.4 Bundling & Caching

**Webpack/Vite Config**:
```javascript
{
  entry: {
    main: './src/index.js',
    vendor: ['react', 'react-dom'],
    dashboard: './src/pages/Dashboard',
    policies: './src/pages/Policies'
  },
  output: {
    filename: '[name].[contenthash].js',
    chunkFilename: '[name].[contenthash].chunk.js'
  }
}
```

**Cache Busting**:
- Use content hash in filenames
- Set long cache headers for versioned assets
- Service Worker for offline caching

### 6.5 Performance Monitoring (Client-Side)

**Web Vitals API**:
```javascript
import { getCLS, getFID, getFCP, getLCP, getTTFB } from 'web-vitals';

getCLS(console.log);  // Cumulative Layout Shift
getFID(console.log);  // First Input Delay
getFCP(console.log);  // First Contentful Paint
getLCP(console.log);  // Largest Contentful Paint
getTTFB(console.log); // Time to First Byte
```

---

## 7. Caching Strategy

### 7.1 Cache Layers

**Layer 1: Browser Cache**
- Static assets: 1 year (`max-age=31536000`)
- API responses: 5–10 minutes

**Layer 2: CDN Cache**
- Static files (JS, CSS, images): 1 year
- API responses: 5 minutes (only public endpoints)

**Layer 3: Redis Cache**

| Data Type | TTL | Size (Tier 3) |
|---|---|---|
| Dashboard metrics | 5 min | 100MB |
| Audit log summaries | 1 hour | 500MB |
| Policy data | 10 min | 200MB |
| User/team data | 5 min | 100MB |
| Compliance status | 10 min | 150MB |
| Report templates | 1 day | 50MB |

### 7.2 Cache Invalidation

**Time-Based Expiration**:
- Set TTL on all Redis keys
- Refresh on read if expired

**Event-Based Invalidation**:
```javascript
// When policy updated
await redis.del(`policy:${policyId}`);
await redis.del(`dashboard:${orgId}`);

// Batch invalidation
await redis.del(
  `audit-logs:${orgId}:*`,
  `compliance:${orgId}:*`
);
```

**Cache Warming**:
```javascript
// Pre-load at deployment
async function warmCache() {
  const policies = await db.query('SELECT * FROM policies');
  for (const policy of policies) {
    await redis.set(
      `policy:${policy.id}`,
      JSON.stringify(policy),
      { EX: 600 }
    );
  }
}
```

---

## 8. Monitoring & Observability

### 8.1 APM Tool Integration

**Recommended**: Datadog, New Relic, or Dynatrace

**Metrics to Track**:

#### Application Metrics
- **Request Latency**: P50, P95, P99 (by endpoint)
- **Throughput**: Requests/sec (by status code)
- **Error Rate**: 4xx, 5xx per endpoint
- **Custom Metrics**:
  - Audit log ingestion rate
  - Report generation time
  - Policy update latency
  - Compliance check duration

#### Infrastructure Metrics
- **Pod Metrics**:
  - CPU usage (target < 70%)
  - Memory usage (target < 80%)
  - Network I/O
  - Disk I/O
- **Database Metrics**:
  - Connection pool utilization
  - Slow query count (> 100ms)
  - Replication lag (< 1s)
  - Cache hit ratio (> 75%)
- **Cache Metrics**:
  - Redis memory usage
  - Eviction rate
  - Hit/miss ratio

### 8.2 Alerting Thresholds

| Alert | Threshold | Severity | Action |
|---|---|---|---|
| API P99 Latency | > 1s | Warning | Investigate scaling |
| API P99 Latency | > 2s | Critical | Page on-call |
| Error Rate | > 1% | Warning | Check logs |
| Error Rate | > 5% | Critical | Page on-call |
| Pod CPU | > 80% | Warning | Check load |
| Pod Memory | > 85% | Warning | Check for leaks |
| DB Connection Pool | > 90% utilized | Warning | Scale replicas |
| Cache Hit Ratio | < 60% | Warning | Investigate eviction |
| Database Replication Lag | > 5s | Critical | Page on-call |

### 8.3 Dashboards

**Real-Time Operations Dashboard**:
- Current RPS, P99 latency, error rate
- Pod count, resource utilization
- Top slow endpoints
- Active alerts

**Historical Trend Dashboard**:
- 24h/7d/30d latency trends
- Capacity planning graph
- Error rate trends
- Cache hit ratio history

**Compliance Audit Dashboard**:
- Audit log ingestion rate
- Policy update frequency
- Compliance status distribution

---

## 9. Performance Optimization Checklist

### Phase 1: Pre-Load Test (Before Any Testing)
- [ ] Enable GZIP compression on all endpoints
- [ ] Implement database indexing per Section 4.1
- [ ] Deploy materialized views for dashboard
- [ ] Configure Redis cache with TTL strategy (Section 7)
- [ ] Enable HTTP caching headers (Section 5.3)
- [ ] Implement ETag support
- [ ] Set up pagination (default 100 items/page)
- [ ] Implement API rate limiting (100 req/sec per client)
- [ ] Deploy CDN for static assets

### Phase 2: Application Optimization
- [ ] Code-split routes (React.lazy)
- [ ] Minify CSS/JS
- [ ] Optimize images (WebP, responsive)
- [ ] Implement lazy image loading
- [ ] Configure bundle splitting
- [ ] Enable service worker for offline
- [ ] Test Core Web Vitals locally (< 2.5s LCP)

### Phase 3: Infrastructure Setup
- [ ] Configure Kubernetes HPA (trigger 70% CPU, 80% memory)
- [ ] Set up 2-pod deployment for Tier 2
- [ ] Configure database read replicas
- [ ] Enable Redis cluster mode for Tier 3
- [ ] Deploy CDN (CloudFlare, Azure CDN)
- [ ] Configure SSL/TLS certificates

### Phase 4: Monitoring & Observability
- [ ] Deploy APM agent (Datadog/New Relic)
- [ ] Create real-time operations dashboard
- [ ] Set up alerting thresholds (Section 8.2)
- [ ] Configure distributed tracing
- [ ] Enable custom metrics (audit ingestion, report generation)
- [ ] Set up log aggregation (ELK stack, Datadog logs)

### Phase 5: Load Testing & Validation
- [ ] Execute baseline test (Tier 1, 100 users)
- [ ] Execute ramp-up test (100 → 500 → 1000 users)
- [ ] Execute 24h soak test (500 users, detect leaks)
- [ ] Execute spike test (100 → 1000 instant)
- [ ] Execute stress test (find breaking point)
- [ ] Validate no connection exhaustion
- [ ] Validate cache hit ratio > 75%
- [ ] Validate memory stable (< 5% growth in 24h)

### Phase 6: Production Rollout
- [ ] Enable monitoring in production
- [ ] Gradual rollout (10% → 50% → 100% traffic)
- [ ] Monitor P99 latency, error rate, resource usage
- [ ] Set up on-call alerting
- [ ] Document runbook for performance incidents
- [ ] Schedule monthly performance review

---

## 10. Performance Incident Runbook

### P99 Latency Spike (> 1s)

**Diagnosis**:
1. Check real-time dashboard: RPS, error rate, pod CPU/memory
2. Check top slow endpoints in APM
3. Check database replication lag
4. Check Redis memory usage and eviction rate

**Mitigation** (in order):
1. Scale pods: `kubectl scale deploy/basecoat --replicas=5`
2. Clear Redis cache for high-traffic keys: `redis-cli FLUSHDB`
3. Kill long-running queries: Check database slow query log
4. Switch to read replicas if replication lag < 2s
5. Enable circuit breaker on affected endpoints

**Recovery**:
- Monitor P99 latency for 10 minutes
- Gradually scale down if recovered
- Post-incident: Review slow endpoint query plans

### Connection Pool Exhaustion

**Diagnosis**:
1. Check database connection count: `SELECT count(*) FROM pg_stat_activity;`
2. Check for idle connections: `SELECT idle_in_transaction_session_count FROM pg_stat_database;`
3. Check connection pool utilization in APM

**Mitigation**:
1. Scale API pods to reduce per-pod connections
2. Increase connection pool size (max +20)
3. Kill idle connections: `SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE state = 'idle' AND query_start < NOW() - INTERVAL '5 minutes';`
4. Enable connection multiplexing (pgbouncer)

---

## 11. Performance Requirements Summary

| Component | Target | Tier 1 | Tier 2 | Tier 3 |
|---|---|---|---|---|
| Page Load | < 2s | ✅ | ✅ | ✅ |
| API Latency (P99) | < 500ms | ✅ | ✅ | < 600ms |
| Database Query | < 100ms | ✅ | ✅ | ✅ |
| Report Gen | < 30s | ✅ | ✅ | ✅ |
| UI Interactivity | < 100ms | ✅ | ✅ | ✅ |
| Cache Hit Ratio | > 75% | > 70% | > 75% | > 80% |
| Error Rate | < 0.5% | ✅ | ✅ | ✅ |
| Concurrent Users | Supported | 100 | 500 | 1000+ |
| RPS | Sustained | ~200 | ~1000 | 5000+ |

---

## Appendix: Testing Configuration Files

### Apache JMeter Test Plan (Baseline)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<jmeterTestPlan>
  <hashTree>
    <ThreadGroup>
      <elementProp name="ThreadGroup.main_controller"/>
      <stringProp name="ThreadGroup.num_threads">100</stringProp>
      <stringProp name="ThreadGroup.ramp_time">120</stringProp>
      <stringProp name="ThreadGroup.duration">600</stringProp>
    </ThreadGroup>
    <HTTPSampler>
      <stringProp name="HTTPSampler.domain">api.basecoat.local</stringProp>
      <stringProp name="HTTPSampler.path">/api/audit-logs</stringProp>
      <stringProp name="HTTPSampler.method">GET</stringProp>
    </HTTPSampler>
    <ResultCollector>
      <stringProp name="filename">results.jtl</stringProp>
    </ResultCollector>
  </hashTree>
</jmeterTestPlan>
```

---

## Document Version History

| Version | Date | Author | Changes |
|---|---|---|---|
| v1.0 | 2024-01-15 | Performance Analyst | Initial comprehensive requirements |
