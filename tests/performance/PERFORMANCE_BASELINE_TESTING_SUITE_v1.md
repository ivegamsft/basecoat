# Basecoat Portal Performance Baseline Testing Suite

**Document Version**: 1.0  
**Last Updated**: Wave 3 Day 2  
**Status**: Active  

---

## Executive Summary

This comprehensive performance testing suite provides a structured approach to establishing, validating, and monitoring performance baselines for the Basecoat Portal. The suite includes five load testing scenarios, k6 test scripts, success criteria, monitoring dashboard setup, CI/CD integration procedures, and result analysis templates.

**Target Performance Metrics:**
- Page Load Time: < 2s (90th percentile)
- API Response Time: < 500ms (95th percentile)
- Database Query Time: < 100ms (average)
- Error Rate: < 1% at baseline load

**Scalability Target:** 100 → 500 → 1000+ concurrent users

---

## Table of Contents

1. [Overview & Objectives](#overview--objectives)
2. [Load Testing Framework](#load-testing-framework)
3. [Five Load Test Types](#five-load-test-types)
4. [Success Criteria](#success-criteria)
5. [Test Procedures](#test-procedures)
6. [Monitoring Dashboard Setup](#monitoring-dashboard-setup)
7. [CI/CD Integration](#cicd-integration)
8. [Result Analysis & Reporting](#result-analysis--reporting)
9. [Performance Optimization Recommendations](#performance-optimization-recommendations)
10. [Troubleshooting & Recovery](#troubleshooting--recovery)

---

## Overview & Objectives

### Objectives

1. **Establish Performance Baselines** - Document baseline performance metrics for 100 concurrent users
2. **Validate Scalability** - Verify system can scale from 100 to 1000+ concurrent users
3. **Identify Bottlenecks** - Detect limiting factors (CPU, memory, DB connections, cache)
4. **Stress Test Infrastructure** - Find failure points and maximum sustainable load
5. **Continuous Monitoring** - Automate baseline tests and regression detection
6. **Document Procedures** - Provide runbooks for team training and knowledge transfer

### Success Criteria

- ✅ All k6/JMeter test scripts execute without errors
- ✅ Baseline test passes with 100 concurrent users (< 500ms 95th percentile)
- ✅ Ramp-up test completes 1000 users without cascading failures
- ✅ Soak test maintains performance for 4 hours (< 500ms response time)
- ✅ Spike test recovers within 30 seconds
- ✅ Stress test identifies maximum sustainable load
- ✅ Monitoring dashboards configured and alerting active
- ✅ CI/CD pipeline includes automated baseline tests
- ✅ Team trained on executing and analyzing tests

---

## Load Testing Framework

### Testing Tool: k6

**Why k6?**
- Modern, lightweight load testing tool written in Go
- JavaScript-based test scripting (familiar to teams)
- Built-in support for gradual ramp-up, soak, and stress testing
- Cloud execution support for distributed load
- Detailed performance metrics and thresholds
- Excellent integration with CI/CD pipelines
- Real-time performance dashboards

### k6 Installation

**Windows:**
```powershell
choco install k6
```

**macOS:**
```bash
brew install k6
```

**Linux:**
```bash
sudo apt-get install k6
```

**Docker:**
```bash
docker pull grafana/k6
```

### Test Environment Setup

#### 1. Staging Database

- **Data Volume:**
  - 10,000 audit records (realistic compliance data)
  - 100,000 issues (from various repositories)
  - 500 teams and 5,000 members
  - 1,000 active repositories

- **Refresh Strategy:**
  - Daily refresh from production snapshot (anonymized)
  - Cleared between spike and stress tests
  - Full reset for regression tests

#### 2. Staging API Server

- **Configuration:**
  - Same codebase as production (same optimization levels)
  - Production-equivalent resource allocation (initially)
  - Separate load generator to avoid resource contention
  - Network latency simulation (50ms added to match production)

#### 3. Load Generator Server

- **Requirements:**
  - Separate from API and database servers
  - Sufficient bandwidth (at 1000 concurrent users)
  - 16GB RAM minimum (for k6 orchestration)
  - Provisioned in same region/VPC as staging (low latency)

#### 4. Network Isolation

- **Connection Limits:**
  - Firewall rules to prevent load generator from affecting other systems
  - Dedicated API endpoint for performance testing
  - Rate limiting temporarily disabled for testing

---

## Five Load Test Types

### 1. Baseline Load Test

**Objective:** Establish performance baseline at 100 concurrent users (typical daytime usage)

**Load Profile:**
- Constant load: 100 concurrent users
- Duration: 10 minutes
- Think time: 2 seconds between requests
- Ramp-up: 1 minute to reach full load
- Ramp-down: 1 minute to graceful shutdown

**Endpoints Tested:**
- `/api/v1/audits?limit=50` - List audits (read)
- `/api/v1/dashboard/metrics` - Dashboard metrics (aggregation)
- `/api/v1/reports/compliance?period=30` - Compliance report (complex query)

**Success Criteria:**
- Response time (p95): < 500ms
- Response time (p99): < 800ms
- Error rate: < 1% (< 1 error per 100 requests)
- No memory leaks detected
- Database connections: < 50 active

**Expected Output:**
- Test duration: ~12 minutes
- Total requests: ~20,000
- Successful requests: ≥ 19,800
- Failed requests: ≤ 200

### 2. Ramp-Up Load Test

**Objective:** Validate system can gradually scale to 1000 concurrent users

**Load Profile:**

| Stage | Duration | User Count | Objective |
|-------|----------|------------|-----------|
| Warm-up | 2 min | 100 → 100 | Stabilize system |
| Ramp-up Phase 1 | 10 min | 100 → 500 | Gradual scaling |
| Ramp-up Phase 2 | 10 min | 500 → 1000 | Peak load |
| Peak Hold | 5 min | 1000 | Verify stability at peak |
| Cool-down | 2 min | 1000 → 100 | Graceful shutdown |

**Total Duration:** 29 minutes

**Success Criteria:**
- Response time (p95) during ramp-up: < 800ms
- Response time (p95) at peak (1000 users): < 1000ms
- Error rate during ramp-up: < 2%
- No cascading failures or timeouts
- Database connections scale proportionally (max 150 connections across cluster)
- API throughput increases linearly with user count

**Identify Bottlenecks:**
- Note response time degradation at each stage
- Monitor CPU/memory utilization growth
- Track database connection pool usage
- Identify which endpoint degrades first

### 3. Soak Load Test

**Objective:** Detect memory leaks, connection pool exhaustion, and performance degradation over time

**Load Profile:**
- Constant load: 500 concurrent users
- Duration: 4 hours
- Think time: 2 seconds between requests
- Ramp-up: 5 minutes
- Ramp-down: 5 minutes

**Endpoints:** Same 3 core endpoints (audits, dashboard, reports)

**Success Criteria:**
- Response time remains < 500ms (p95) throughout test
- No memory growth > 100MB per hour
- Database connections stable (no growth)
- Error rate remains < 0.5% throughout test
- No timeouts or connection pool exhaustion
- 4-hour total request count: ~7.2M requests
- Successful requests: ≥ 7.14M (99.5% success rate)

**Monitoring Focus:**
- Memory utilization trend (linear growth indicates leak)
- Database connection pool stability
- Cache hit rate consistency
- Garbage collection pauses
- Long-running query accumulation

### 4. Spike Load Test

**Objective:** Verify system recovers gracefully from sudden traffic spikes

**Load Profile:**
- Baseline: 100 concurrent users
- Spike: Ramp to 1000 users instantly (no gradual ramp-up)
- Spike duration: 5 minutes
- Cool-down: 1 minute to 100 users
- Total duration: 7 minutes

**Success Criteria:**
- **Recovery Time:** System responds to first request within 30 seconds of spike
- **Queue Depth:** Request queue never exceeds 100 requests
- **Cascading Failures:** None - system should slow down but not crash
- **Error Rate During Spike:** < 5% acceptable (temporary error spike)
- **Error Rate After Recovery:** < 1% (returns to baseline)
- **Response Time Post-Recovery:** Returns to < 500ms within 2 minutes

**Failure Indicators:**
- Circuit breaker trips and doesn't recover
- Database connections exhaust and requests fail
- Cache eviction storms causing cascading query failures
- Memory pressure causing OOM events
- Request queue grows unbounded

### 5. Stress Test

**Objective:** Find maximum sustainable load and identify failure mode

**Load Profile:**
- Start: 100 concurrent users
- Ramp: Increase 50 users every 2 minutes until failure
- Success target: Gradual response time degradation
- Failure target: Error rate exceeds 5% for > 1 minute

**Load Schedule:**
```
00:00 - 02:00:   100 users
02:00 - 04:00:   150 users
04:00 - 06:00:   200 users
06:00 - 08:00:   250 users
... (continue until failure or max capacity)
```

**Success Criteria:**
- Clear identification of maximum sustainable load
- Failure mode documented (what breaks first?)
- Degradation curve understood (response time vs. users)
- Service restarts cleanly after failure
- No data corruption or inconsistency on failure

**Failure Points to Identify:**
1. **First Failure Symptom:** (e.g., DB connection pool exhaustion)
2. **Critical Load:** Users count where system becomes unusable (> 2s response time)
3. **Collapse Load:** Users count where error rate exceeds 50%
4. **Recovery Time:** Minutes needed to recover after removing load

---

## Success Criteria

### Baseline Test (100 users, 10 min)

| Metric | Target | Threshold |
|--------|--------|-----------|
| Response Time (p95) | < 500ms | ✅ Pass if < 550ms |
| Response Time (p99) | < 800ms | ✅ Pass if < 880ms |
| Error Rate | < 1% | ✅ Pass if < 1.1% |
| Throughput | 200+ req/s | ✅ Pass if > 190 req/s |
| Max Response Time | N/A | ⚠️ Monitor if > 5s |

### Ramp-Up Test (100 → 1000 users, 29 min)

| Metric | Target | Threshold |
|--------|--------|-----------|
| Response Time (p95) at 500 users | < 600ms | ✅ Pass if < 660ms |
| Response Time (p95) at 1000 users | < 800ms | ✅ Pass if < 880ms |
| Error Rate at 1000 users | < 2% | ✅ Pass if < 2.2% |
| Throughput at 1000 users | 900+ req/s | ✅ Pass if > 850 req/s |
| Cascading Failures | None | ✅ Must be zero |

### Soak Test (500 users, 4 hours)

| Metric | Target | Threshold |
|--------|--------|-----------|
| Response Time (p95) | < 500ms | ✅ Pass if < 550ms |
| Memory Leak | < 100MB/hr | ✅ Pass if growth linear |
| Error Rate | < 0.5% | ✅ Pass if < 0.55% |
| Connection Pool Stability | No growth | ✅ Pass if stable ±5 connections |
| Success Rate | ≥ 99.5% | ✅ Pass if ≥ 99.4% |

### Spike Test (100 → 1000 → 100 users, 7 min)

| Metric | Target | Threshold |
|--------|--------|-----------|
| Recovery Time | < 30s | ✅ Pass if < 33s |
| Queue Depth Max | < 100 | ✅ Pass if max queue < 110 |
| Error Rate During Spike | < 5% | ✅ Pass if < 5.5% |
| Error Rate Post-Recovery | < 1% | ✅ Pass if < 1.1% |
| Response Time Return to Normal | < 2 min | ✅ Pass if recovers within 2:30 |

### Stress Test

| Metric | Target | Threshold |
|--------|--------|-----------|
| Maximum Sustainable Load | Identified | ✅ Pass if clearly documented |
| Failure Mode Documented | Yes | ✅ Pass if root cause known |
| Graceful Degradation | Yes | ✅ Pass if no crash below 5k req/s |
| Recovery After Failure | < 5 min | ✅ Pass if restarts cleanly |

---

## Test Procedures

### Pre-Test Checklist

Before each test, verify:

- [ ] Load generator server is ready (isolated, sufficient resources)
- [ ] Staging API is deployed with correct configuration
- [ ] Database is in clean state (refreshed from production snapshot)
- [ ] Monitoring dashboard is active and recording metrics
- [ ] Alert thresholds are configured
- [ ] Team is available for real-time monitoring
- [ ] Incident playbook is accessible
- [ ] Communication channel (Slack/Teams) is open for updates
- [ ] Test cancellation plan is documented (if needed)

### During Test

**Real-Time Monitoring:**

1. **First 30 seconds:** Watch for immediate connection/DNS errors
2. **First minute:** Verify response times stabilize (no large spike)
3. **Ongoing:** Monitor dashboard every 5 minutes for drift
4. **Response time degradation:** If > 25% degradation, escalate
5. **Error rate spike:** If > 5%, stop test and investigate

**Stop Conditions:**

- Response time (p95) > 5x baseline (e.g., > 2.5s for 500ms baseline)
- Error rate > 10%
- Database is unresponsive (all requests timeout)
- Memory usage > 90% available
- Clear cascading failures

### Post-Test Analysis

1. **Collect Results**
   - Export test logs from k6 cloud
   - Download metrics from Prometheus
   - Generate dashboard snapshots

2. **Analysis Questions**
   - Did we meet success criteria?
   - Where is the bottleneck?
   - What needs optimization?
   - Are results repeatable?

3. **Generate Report** (See Section 8)

4. **Plan Follow-up**
   - Optimization tasks
   - Configuration changes
   - Re-testing schedule

---

## Monitoring Dashboard Setup

### Metrics Collection (Prometheus)

Configure Prometheus scrape jobs:

```yaml
scrape_configs:
  - job_name: 'basecoat-api'
    static_configs:
      - targets: ['staging-api:9090']
    scrape_interval: 15s
    scrape_timeout: 10s

  - job_name: 'postgres'
    static_configs:
      - targets: ['staging-db:9187']
    scrape_interval: 15s

  - job_name: 'redis'
    static_configs:
      - targets: ['staging-redis:9121']
    scrape_interval: 15s
```

### Grafana Dashboard Configuration

**Dashboard Name:** Basecoat Portal Performance Baseline

**Rows:**

#### Row 1: Application Performance

- **Response Time Distribution** (p50, p95, p99, max)
- **Throughput** (requests per second, success rate)
- **Error Rate** (%, broken down by status code)
- **User Load** (current concurrent users, ramp-up rate)

#### Row 2: Infrastructure

- **CPU Usage** (API pods, database server, Redis)
- **Memory Usage** (API pods, database server, Redis)
- **Network Throughput** (inbound, outbound)
- **Disk I/O** (read/write operations)

#### Row 3: Database Performance

- **Connection Pool** (active, idle, waiting)
- **Query Performance** (p50, p95, p99 latency)
- **Slow Query Log** (top 10 slow queries)
- **Transaction Count** (commits, rollbacks)

#### Row 4: Cache Performance

- **Hit Rate** (%, requests hitting cache)
- **Eviction Rate** (items evicted per second)
- **Memory Usage** (%, fragmentation ratio)
- **Key Statistics** (total keys, avg key size)

#### Row 5: Alerting Status

- **Active Alerts** (table of triggered alerts)
- **Alert Frequency** (histogram of alerts over time)
- **SLA Status** (% of time under thresholds)

### Alert Thresholds

| Alert | Threshold | Duration | Severity |
|-------|-----------|----------|----------|
| Response Time High | p95 > 1000ms | 2 min | Warning |
| Response Time Critical | p95 > 2000ms | 1 min | Critical |
| Error Rate High | > 1% | 2 min | Warning |
| Error Rate Critical | > 5% | 1 min | Critical |
| CPU High | > 80% | 5 min | Warning |
| Memory High | > 85% | 5 min | Warning |
| DB Connections High | > 100 | 2 min | Warning |
| Cache Evictions | > 1000/sec | 1 min | Warning |

---

## CI/CD Integration

### Automated Baseline Test on Each PR

**Trigger:** On every PR to `main` or `staging` branch

**Procedure:**

1. Deploy PR code to temporary staging environment
2. Run 5-minute baseline test (reduced duration for CI)
3. Compare results to baseline metrics (stored in git)
4. Generate regression report (attach to PR)
5. Comment on PR with results
6. Block merge if > 10% performance regression

**Configuration (GitHub Actions):**

```yaml
name: Performance Regression Check

on:
  pull_request:
    branches: [main, staging]

jobs:
  performance:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Deploy PR to staging
        run: ./scripts/deploy-pr-staging.sh

      - name: Wait for deployment
        run: sleep 60

      - name: Run baseline test
        run: k6 run tests/baseline-5min.js --out json=results.json

      - name: Analyze results
        run: |
          python scripts/analyze-regression.py \
            --current results.json \
            --baseline metrics/baseline-100-users.json \
            --threshold 0.10

      - name: Comment on PR
        uses: actions/github-script@v6
        with:
          script: |
            const fs = require('fs');
            const report = fs.readFileSync('regression-report.md', 'utf8');
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: report
            });
```

### Performance Metrics Storage

Store baseline metrics in `metrics/` directory:

```
metrics/
├── baseline-100-users.json
├── ramp-up-100-1000-users.json
├── soak-500-users-4hr.json
├── spike-100-1000-100.json
└── stress-to-failure.json
```

Each file contains:

```json
{
  "test_name": "Baseline 100 Users",
  "date": "2024-02-15T10:30:00Z",
  "duration_seconds": 600,
  "concurrent_users": 100,
  "metrics": {
    "response_time_p50_ms": 150,
    "response_time_p95_ms": 450,
    "response_time_p99_ms": 750,
    "response_time_max_ms": 3200,
    "throughput_req_per_sec": 200,
    "error_rate_percent": 0.8,
    "success_rate_percent": 99.2,
    "total_requests": 120000,
    "failed_requests": 960
  }
}
```

### Historical Trend Analysis

**Dashboard:** Performance Trends (7-day, 30-day, 90-day views)

**Metrics Tracked:**
- Response time trend (p95)
- Error rate trend
- Throughput trend
- Success rate trend
- Infrastructure cost correlation

**Regression Detection:**
- Alert if p95 increases > 10% week-over-week
- Alert if error rate increases > 0.5% absolute
- Flag for review if throughput decreases > 5%

---

## Result Analysis & Reporting

### Test Result Summary Template

**Report Title:** Performance Test Results - [Test Type] - [Date]

#### 1. Executive Summary
- Test objective
- Pass/fail status
- Key findings (1-3 bullet points)
- Recommendations (if any)

#### 2. Test Configuration
- Load profile (users, duration, ramp-up)
- Endpoints tested
- Environment (staging version, DB snapshot)
- Duration and time of test

#### 3. Results Table

| Metric | Target | Result | Status |
|--------|--------|--------|--------|
| Response Time (p95) | < 500ms | 480ms | ✅ Pass |
| Response Time (p99) | < 800ms | 750ms | ✅ Pass |
| Error Rate | < 1% | 0.8% | ✅ Pass |
| Throughput | 200+ req/s | 205 req/s | ✅ Pass |
| Max Response Time | N/A | 3.2s | ⚠️ Monitor |

#### 4. Performance Graphs

1. Response time over time (line chart)
2. Error rate over time (line chart)
3. Response time distribution (histogram)
4. Endpoint performance comparison (bar chart)
5. Resource utilization (CPU, memory, disk)

#### 5. Bottleneck Analysis

**Question:** What is limiting throughput?

**Answer:** (Choose one or more)
- [ ] CPU maxed out on API server
- [ ] Database connection pool exhausted
- [ ] Memory pressure causing GC pauses
- [ ] Disk I/O bottleneck
- [ ] Network bandwidth limit
- [ ] Cache eviction storms
- [ ] Application code hotspot (specify)

**Evidence:**
- Link to detailed metrics/logs
- Screenshots of monitoring dashboard
- Specific query or function causing issue

#### 6. Comparison to Baseline

- Response time change: X% (was Y, now Z)
- Error rate change: X% (was Y, now Z)
- Throughput change: X% (was Y, now Z)
- Regression or improvement?

#### 7. Recommendations

1. **Immediate Actions** (if failures detected)
2. **Optimization Opportunities** (performance improvements)
3. **Configuration Adjustments** (resource allocation changes)
4. **Re-testing Plan** (when to re-run test)

#### 8. Appendix

- Full test logs (k6 output)
- Prometheus query results
- Database explain plans (for slow queries)
- Alert logs (any alerts triggered)

---

## Performance Optimization Recommendations

### Common Bottlenecks & Fixes

#### Database Connection Pool Exhaustion

**Symptom:** Error rate increases, "connection pool exhausted" errors

**Fixes:**
- Increase pool size (connection_pool_size config)
- Implement connection retry logic
- Add query timeout to prevent connection starvation
- Scale database read replicas

#### Slow Query Performance

**Symptom:** Response time (p95) increases gradually, database CPU high

**Fixes:**
- Add indexes on commonly filtered columns
- Review explain plans for full table scans
- Implement query result caching
- Denormalize data for common aggregations

#### Memory Leaks

**Symptom:** Memory usage grows throughout soak test, eventual OOM

**Fixes:**
- Profile heap usage (Node: heap snapshots, Python: memory_profiler)
- Check for unclosed connections/resources
- Review event listener registrations
- Add memory limits to prevent cascade failures

#### Cache Eviction Storms

**Symptom:** Cache hit rate drops suddenly, response times increase

**Fixes:**
- Increase cache size
- Review cache key strategy (too many unique keys?)
- Implement TTL strategy for cache invalidation
- Add cache warming on startup

#### CPU Saturation

**Symptom:** CPU at 100%, response times increase, error rate spikes

**Fixes:**
- Profile CPU (flame graphs)
- Optimize hot code paths
- Add request batching
- Scale horizontally (add more pods)

---

## Troubleshooting & Recovery

### Common Issues & Solutions

#### Test Won't Start

**Issue:** k6 fails to connect to API endpoint

**Solution:**
1. Verify staging API is running: `curl -I https://staging-api.basecoat.dev/health`
2. Check network connectivity from load generator
3. Verify API credentials in test script
4. Check firewall rules

#### Performance Results Inconsistent

**Issue:** Same test gives different results each run

**Solution:**
1. Clear caches between tests
2. Ensure database is in same state (refresh from snapshot)
3. Check for background jobs/maintenance
4. Monitor for other users/tests on staging
5. Run test multiple times, average results

#### Database Crashes During Test

**Issue:** Database becomes unresponsive

**Solution:**
1. Check database logs for OOM or connection pool errors
2. Restart database service
3. Review connection pool configuration
4. Increase max connections
5. Implement circuit breaker to fail gracefully

#### Load Generator Runs Out of Memory

**Issue:** k6 fails with "out of memory"

**Solution:**
1. Reduce concurrent users (start with 100, not 1000)
2. Add more RAM to load generator
3. Run test from multiple machines (distributed load)
4. Use k6 cloud for unlimited scale

---

## Appendix A: Quick Start Guide

### Step 1: Install k6

```bash
# macOS
brew install k6

# Windows (Chocolatey)
choco install k6

# Linux
sudo apt-get install k6
```

### Step 2: Clone Test Scripts

```bash
cd basecoat/tests/performance/scripts
```

### Step 3: Run Baseline Test

```bash
k6 run baseline-100-users-10min.js \
  --vus 100 \
  --duration 10m \
  --out json=results.json
```

### Step 4: View Results

```bash
# Summary in terminal
k6 run baseline-100-users-10min.js --summary-export=results-summary.json

# Web dashboard (k6 cloud)
k6 cloud baseline-100-users-10min.js
```

### Step 5: Analyze Results

```bash
python scripts/analyze-results.py results.json
```

---

## Appendix B: Performance Requirements Reference

See `PORTAL_PERFORMANCE_REQUIREMENTS_v1.md` for:
- Detailed performance targets by layer
- Scalability analysis (100/500/1000+ users)
- Infrastructure recommendations
- Caching strategy
- CDN configuration
- Query optimization patterns

---

**Document End**
