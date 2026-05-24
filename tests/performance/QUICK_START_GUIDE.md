# Performance Testing Quick Start Guide

## 📊 Overview

This guide helps you quickly get started with the Basecoat Portal performance testing suite.

**Five Load Test Types:**
1. **Baseline** - 100 users, 10 min (establishes performance baseline)
2. **Ramp-Up** - 100 → 1000 users, 29 min (validates scalability)
3. **Soak** - 500 users, 4 hours (detects memory leaks)
4. **Spike** - 100 → 1000 users instantly (tests recovery)
5. **Stress** - Gradual increase until failure (finds limits)

---

## 🚀 Quick Start (5 minutes)

### 1. Install k6

```bash
# macOS
brew install k6

# Windows (Chocolatey)
choco install k6

# Linux (Ubuntu/Debian)
sudo apt-get install k6

# Verify installation
k6 version
```

### 2. Set Environment Variables

```bash
export BASE_URL="https://staging-api.basecoat.dev/v1"
export API_TOKEN="your-test-token-here"
```

### 3. Run Baseline Test (10 minutes)

```bash
cd tests/performance/scripts
k6 run baseline-100-users-10min.js \
  --out json=results.json \
  -e BASE_URL="$BASE_URL" \
  -e API_TOKEN="$API_TOKEN"
```

### 4. View Results

```bash
# Text summary
cat results.json | jq '.metrics.http_req_duration.values'

# Generate report
python analyze-results.py \
  --current results.json \
  --baseline ../metrics/baseline-100-users.json
```

---

## 📋 Pre-Test Checklist

Before running any test, verify:

- [ ] **Staging API is running** - `curl https://staging-api.basecoat.dev/v1/health`
- [ ] **Database is ready** - Check staging DB dashboard
- [ ] **Redis cache is active** - Test cache connectivity
- [ ] **Monitoring dashboard is open** - Monitor metrics in real-time
- [ ] **Load generator has sufficient resources** - 16GB RAM for 1000+ users
- [ ] **Team is available** - Performance testing requires real-time monitoring
- [ ] **Communication channel is open** - Slack/Teams for updates

---

## 🧪 Running All Tests

Execute the comprehensive test suite:

```bash
python scripts/run-all-tests.py \
  --base-url "https://staging-api.basecoat.dev/v1" \
  --api-token "$API_TOKEN"
```

**Expected total duration:** ~5.5 hours

```
Baseline:   12 min ✅
Ramp-up:    31 min ✅
Soak:       4h 10 min ✅
Spike:      7 min ✅
Stress:     30 min ✅
───────────────────
Total:      5h 30 min
```

---

## 📊 Monitoring During Tests

### Grafana Dashboard

1. Open: `https://grafana.staging.basecoat.dev`
2. Select dashboard: "Basecoat Portal Performance Baseline"
3. Watch these metrics:
   - **Response Time (p95)** - Target: < 500ms
   - **Error Rate** - Target: < 1%
   - **Throughput** - Target: 200+ req/s (baseline)
   - **Database Connections** - Target: < 100
   - **CPU/Memory** - Alert if > 80%

### Real-Time Monitoring Commands

```bash
# Watch metrics (terminal)
watch -n 5 'k6 stats'

# Monitor database
psql -U admin -d staging -c "SELECT count(*) FROM pg_stat_activity;"

# Monitor Redis
redis-cli INFO stats
```

---

## 🎯 Success Criteria Quick Reference

### Baseline Test (100 users)

| Metric | Target | PASS | WARN |
|--------|--------|------|------|
| p95 Response Time | < 500ms | ✅ | ⚠️ 501-550ms |
| p99 Response Time | < 800ms | ✅ | ⚠️ 801-880ms |
| Error Rate | < 1% | ✅ | ⚠️ 1-1.1% |

### Ramp-Up Test (100→1000 users)

| Metric | Target | PASS | WARN |
|--------|--------|------|------|
| p95 @ 500 users | < 600ms | ✅ | ⚠️ |
| p95 @ 1000 users | < 800ms | ✅ | ⚠️ |
| Error Rate @ peak | < 2% | ✅ | ⚠️ |

### Soak Test (500 users, 4h)

| Metric | Target | PASS | WARN |
|--------|--------|------|------|
| Avg Response Time | < 500ms | ✅ | ⚠️ |
| Memory Growth | < 100MB/hr | ✅ | ⚠️ |
| Error Rate | < 0.5% | ✅ | ⚠️ |

### Spike Test (100→1000→100)

| Metric | Target | PASS | WARN |
|--------|--------|------|------|
| Recovery Time | < 30s | ✅ | ⚠️ |
| Error Rate During Spike | < 5% | ✅ | ⚠️ |
| Error Rate After Recovery | < 1% | ✅ | ⚠️ |

---

## 🔍 Analyzing Results

### Using the Analysis Script

```bash
python scripts/analyze-results.py \
  --current results-latest.json \
  --baseline metrics/baseline-100-users.json \
  --threshold 0.10 \
  --markdown
```

### Manual Analysis

```bash
# Extract key metrics
jq '.metrics | {
  "p95": .http_req_duration.values.p95,
  "p99": .http_req_duration.values.p99,
  "error_rate": .http_req_failed.values.rate,
  "throughput": .http_reqs.values.rate
}' results.json
```

---

## ⚡ Common Issues & Solutions

### Issue: Connection Refused
```
Error: dial tcp: connect: connection refused
```
**Solution:** Verify API is running - `curl https://staging-api.basecoat.dev/v1/health`

### Issue: High Response Times at Start
```
Response time (p95): 2000ms (much higher than expected)
```
**Solution:** Wait for warm-up phase (first 2-3 minutes). This is normal.

### Issue: Memory Exhaustion
```
k6: out of memory
```
**Solution:** Reduce concurrent users or run from multiple machines

### Issue: Database Connection Pool Exhausted
```
Error: connection pool exhausted
```
**Solution:** Increase connection pool size or scale horizontally

### Issue: Cache Eviction Storm
```
Redis evictions spike dramatically
```
**Solution:** Increase Redis memory or review cache key strategy

---

## 📈 Performance Optimization Opportunities

### If Response Time is High (> 500ms):
1. Profile database queries - identify slow queries
2. Add indexes on commonly filtered columns
3. Implement caching for expensive operations
4. Denormalize data for common aggregations

### If Error Rate is High (> 1%):
1. Check database connection pool
2. Review application logs for errors
3. Verify external dependencies
4. Test database failover scenarios

### If Throughput is Low (< 190 req/s):
1. Add API server replicas
2. Optimize request handling code
3. Implement request batching
4. Use connection pooling

### If Memory is Growing (Memory Leak):
1. Profile heap memory usage
2. Check for unclosed connections
3. Review event listener registrations
4. Add memory limits to prevent cascade

---

## 📞 Support & Escalation

### Performance Baseline (100 users)
- **Owner:** Performance Engineering Team
- **Escalation:** If p95 > 1000ms, escalate to Backend Team
- **Contact:** performance@basecoat.dev

### Scaling Issues (500+ users)
- **Owner:** Infrastructure Team
- **Escalation:** If cascading failures detected
- **Contact:** infrastructure@basecoat.dev

### Database Bottlenecks
- **Owner:** Database Team
- **Escalation:** If connection pool exhaustion
- **Contact:** database@basecoat.dev

---

## 📚 Additional Resources

- [Full Testing Suite Documentation](./PERFORMANCE_BASELINE_TESTING_SUITE_v1.md)
- [Performance Requirements](../PORTAL_PERFORMANCE_REQUIREMENTS_v1.md)
- [k6 Documentation](https://k6.io/docs/)
- [Grafana Dashboard Guide](../grafana-dashboard-config.json)
- [Prometheus Alerts](../performance-alerts.yml)

---

## 🎓 Team Training

### For Performance Testers
1. Read this Quick Start Guide
2. Run baseline test (10 min)
3. Analyze results with analysis script
4. Monitor Grafana dashboard during test

### For DevOps Engineers
1. Review Prometheus configuration
2. Setup Grafana dashboards
3. Configure alert notifications
4. Document escalation procedures

### For Backend Developers
1. Understand performance targets
2. Profile your code changes
3. Run baseline test on PRs
4. Optimize hot paths

---

**Last Updated:** Wave 3 Day 2  
**Version:** 1.0  
**Status:** Active  
