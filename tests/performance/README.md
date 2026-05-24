# Basecoat Portal Performance Testing Suite

**Version:** 1.0  
**Status:** Active  
**Last Updated:** Wave 3 Day 2  

---

## 📊 Overview

The Basecoat Portal Performance Testing Suite provides comprehensive load testing infrastructure to establish baseline performance metrics, validate scalability, and identify bottlenecks in the Basecoat Portal implementation.

**Key Features:**
- ✅ Five distinct load test scenarios (baseline, ramp-up, soak, spike, stress)
- ✅ k6 test scripts with realistic user workflows
- ✅ Prometheus metrics collection and Grafana dashboards
- ✅ Automated regression detection for CI/CD pipelines
- ✅ Comprehensive result analysis and reporting
- ✅ Team training materials and runbooks

---

## 📁 Directory Structure

```
tests/performance/
├── PERFORMANCE_BASELINE_TESTING_SUITE_v1.md  # Comprehensive 10+ page documentation
├── QUICK_START_GUIDE.md                      # 5-minute quick start guide
├── README.md                                 # This file
├── grafana-dashboard-config.json             # Grafana dashboard definition
├── prometheus-config.yml                     # Prometheus metrics collection
├── performance-alerts.yml                    # Alert rules and thresholds
├── metrics/
│   └── baseline-100-users.json               # Baseline performance metrics
├── scripts/
│   ├── baseline-100-users-10min.js           # Baseline load test (k6)
│   ├── ramp-up-100-1000-users-29min.js       # Ramp-up test (k6)
│   ├── soak-500-users-4hr.js                 # Soak test (k6)
│   ├── spike-100-1000-100-7min.js            # Spike test (k6)
│   ├── stress-to-failure-incremental.js      # Stress test (k6)
│   ├── analyze-results.py                    # Result analysis tool
│   └── run-all-tests.py                      # Test runner (all 5 tests)
└── .github/workflows/
    └── performance-baseline-pr-check.yml     # CI/CD regression detection
```

---

## 🎯 Performance Targets

### API Response Times

| Endpoint Type | Target | Percentile |
|---------------|--------|-----------|
| Read Endpoints | < 200ms | p99 |
| Write Endpoints | < 300ms | p99 |
| Aggregation Endpoints | < 500ms | p99 |
| Batch Endpoints | < 1s | p99 |

### Load Scalability

| Load Tier | Concurrent Users | Duration | Objective |
|-----------|------------------|----------|-----------|
| Baseline | 100 | 10 min | Normal usage baseline |
| Scaling | 100 → 1000 | 29 min | Verify linear scaling |
| Sustained | 500 | 4 hours | Detect leaks/degradation |
| Spike | 100 → 1000 | 7 min | Verify recovery time |
| Stress | Gradual increase | 30 min | Find max sustainable load |

### Infrastructure Requirements

| Component | Min Spec | Staging Spec |
|-----------|----------|--------------|
| API Server | 2 CPU, 4GB RAM | 4 CPU, 8GB RAM |
| Database | 4 CPU, 16GB RAM | 8 CPU, 32GB RAM |
| Cache (Redis) | 1 CPU, 2GB | 2 CPU, 4GB |
| Load Generator | 8 CPU, 16GB | 16 CPU, 32GB |

---

## 🚀 Getting Started

### 1. Quick Start (5 minutes)
See [QUICK_START_GUIDE.md](./QUICK_START_GUIDE.md) for rapid setup

### 2. Full Documentation
See [PERFORMANCE_BASELINE_TESTING_SUITE_v1.md](./PERFORMANCE_BASELINE_TESTING_SUITE_v1.md) for comprehensive details

### 3. Run Your First Test

```bash
# Install k6
brew install k6

# Set environment
export BASE_URL="https://staging-api.basecoat.dev/v1"
export API_TOKEN="your-token-here"

# Run baseline test
cd scripts
k6 run baseline-100-users-10min.js \
  -e BASE_URL="$BASE_URL" \
  -e API_TOKEN="$API_TOKEN"
```

---

## 📊 Five Load Test Types

### 1. Baseline Test (100 users, 10 minutes)

**Purpose:** Establish baseline performance under normal load

**Profile:**
- 100 concurrent users
- 10-minute duration
- 2-second think time between requests
- Endpoints: audits, dashboard, compliance reports

**Success Criteria:**
- ✅ Response time (p95) < 500ms
- ✅ Error rate < 1%
- ✅ No memory leaks

**Run:**
```bash
k6 run scripts/baseline-100-users-10min.js
```

### 2. Ramp-Up Test (100 → 1000 users, 29 minutes)

**Purpose:** Validate system scales linearly from 100 to 1000 users

**Stages:**
- Warm-up: 100 users for 2 min
- Ramp Phase 1: 100 → 500 users over 10 min
- Ramp Phase 2: 500 → 1000 users over 10 min
- Peak: 1000 users for 5 min
- Cool-down: 1000 → 100 users over 2 min

**Success Criteria:**
- ✅ Response time (p95) < 800ms at 1000 users
- ✅ Error rate < 2% at peak
- ✅ No cascading failures

**Run:**
```bash
k6 run scripts/ramp-up-100-1000-users-29min.js
```

### 3. Soak Test (500 users, 4 hours)

**Purpose:** Detect memory leaks and long-term stability issues

**Profile:**
- 500 concurrent users for 4 hours
- Same endpoints as baseline
- Continuous traffic

**Success Criteria:**
- ✅ Response time remains < 500ms (p95)
- ✅ Memory growth < 100MB/hour
- ✅ Error rate remains < 0.5%
- ✅ Database connections stable

**Run:**
```bash
k6 run scripts/soak-500-users-4hr.js
```

### 4. Spike Test (100 → 1000 → 100 users, 7 minutes)

**Purpose:** Verify system recovers from sudden traffic spikes

**Profile:**
- Baseline: 100 users for 1 min
- Spike: Jump to 1000 users instantly for 5 min
- Cool-down: Return to 100 users over 1 min

**Success Criteria:**
- ✅ Recovery time < 30 seconds
- ✅ Error rate < 5% during spike (temporary acceptable)
- ✅ Error rate returns to < 1% after recovery
- ✅ No cascading failures

**Run:**
```bash
k6 run scripts/spike-100-1000-100-7min.js
```

### 5. Stress Test (Incremental to failure, 30 minutes)

**Purpose:** Find maximum sustainable load and identify failure mode

**Profile:**
- Start: 100 users
- Increase: 50 users every 2 minutes
- Continue until: Error rate > 5% or other failure

**Success Criteria:**
- ✅ Clear identification of max sustainable load
- ✅ Documented failure mode
- ✅ Service recovers cleanly after failure
- ✅ Graceful degradation (no hard crash)

**Run:**
```bash
k6 run scripts/stress-to-failure-incremental.js
```

---

## 📈 Monitoring & Alerts

### Grafana Dashboard

**Location:** `https://grafana.staging.basecoat.dev`

**Rows:**
1. Application Performance - Response times, throughput, error rate
2. Infrastructure - CPU, memory, network
3. Database Performance - Connections, query latency, slow queries
4. Cache Performance - Hit rate, evictions, memory
5. Real-time Alerts - Active alerts and SLA status

### Alert Thresholds

| Alert | Threshold | Duration | Action |
|-------|-----------|----------|--------|
| API Response High | p95 > 1000ms | 2 min | Warning |
| API Response Critical | p95 > 2000ms | 1 min | Critical |
| Error Rate High | > 1% | 2 min | Warning |
| Error Rate Critical | > 5% | 1 min | Critical |
| CPU High | > 80% | 5 min | Warning |
| Memory High | > 85% | 5 min | Warning |
| DB Connections High | > 100 | 2 min | Warning |
| Cache Evictions | > 1000/sec | 1 min | Warning |

---

## 🔄 CI/CD Integration

### Automated Regression Detection

Every PR runs an automated 5-minute baseline test:

```
PR Created
   ↓
Deploy to Staging
   ↓
Run 5-min Baseline Test
   ↓
Compare to Baseline Metrics
   ↓
Generate Regression Report
   ↓
Comment on PR with Results
   ↓
Block Merge if > 10% Regression
```

**Required Secrets:**
- `STAGING_API_TOKEN` - API authentication token
- `K6_CLOUD_TOKEN` - k6 cloud integration (optional)
- `DEPLOYMENT_TOKEN` - Deploy PR to staging

**Configuration File:** `.github/workflows/performance-baseline-pr-check.yml`

---

## 🛠️ Tools & Dependencies

### Required
- **k6** - Load testing framework (v0.50+)
- **Python** - Result analysis (3.8+)
- **curl** - Health checks
- **jq** - JSON processing (optional)

### Optional but Recommended
- **Prometheus** - Metrics collection
- **Grafana** - Metrics visualization
- **Redis CLI** - Cache monitoring
- **psql** - Database monitoring

### Installation

```bash
# k6
brew install k6

# Python dependencies
pip install -r requirements.txt

# Prometheus and Grafana (Docker)
docker-compose -f docker-compose.monitoring.yml up
```

---

## 📋 Test Execution Checklist

Before running any test:

- [ ] Staging API is deployed and healthy
- [ ] Database is in clean state (refreshed snapshot)
- [ ] Redis cache is active
- [ ] Monitoring dashboard is open
- [ ] Alert notifications configured
- [ ] Team is available for real-time monitoring
- [ ] Communication channel (Slack) is active
- [ ] Load generator has sufficient resources
- [ ] Network isolation rules are in place
- [ ] Incident escalation plan is documented

---

## 📊 Result Analysis

### Using the Analysis Script

```bash
python scripts/analyze-results.py \
  --current performance-baseline-results.json \
  --baseline metrics/baseline-100-users.json \
  --threshold 0.10 \
  --markdown
```

### Interpreting Results

- **Response Time:** Measure of how quickly API responds (lower is better)
- **Error Rate:** Percentage of failed requests (lower is better, target < 1%)
- **Throughput:** Requests per second the system can handle
- **Memory:** Used RAM, should stay relatively constant
- **CPU:** System CPU usage (should have headroom)

### Common Patterns

| Pattern | Meaning | Action |
|---------|---------|--------|
| Response time increases linearly | Normal scaling | Continue to next tier |
| Response time increases exponentially | Bottleneck found | Optimize before scaling |
| Memory growing steadily | Possible memory leak | Investigate and profile |
| Sudden spike in errors | Resource exhaustion | Scale or optimize |
| Error rate stays < 1% | System is healthy | ✅ Good sign |

---

## 🐛 Troubleshooting

### k6 won't connect to API
```bash
# Check API health
curl -I https://staging-api.basecoat.dev/v1/health

# Check firewall rules
sudo iptables -L | grep FORWARD
```

### Tests run slowly
- Check database performance
- Verify no background jobs running
- Check for other load tests
- Monitor system resources

### Inconsistent results
- Clear caches between tests
- Ensure database is in same state
- Run test multiple times, average results
- Check for background traffic

### Memory exhaustion
- Reduce VUs (concurrent users)
- Run from multiple load generators
- Use k6 cloud for distributed load
- Profile application memory usage

---

## 📞 Support & Escalation

### Performance Issues

**If response time (p95) > 500ms:**
1. Check Grafana dashboard for bottleneck
2. Review Prometheus metrics
3. Profile database queries (EXPLAIN ANALYZE)
4. Check API application logs

**Escalation Path:**
- Backend Team → Database Team → Infrastructure Team

### Scaling Issues

**If error rate > 1% under 500 users:**
1. Check database connection pool
2. Review application logs
3. Verify resource allocation
4. Test individual components

**Escalation Path:**
- DevOps Team → Infrastructure Team

---

## 📚 Documentation

### Comprehensive Guides
- [Full Testing Suite (10+ pages)](./PERFORMANCE_BASELINE_TESTING_SUITE_v1.md)
- [Quick Start Guide (5 min setup)](./QUICK_START_GUIDE.md)
- [Performance Requirements](../PORTAL_PERFORMANCE_REQUIREMENTS_v1.md)

### Configuration Files
- [Grafana Dashboard](./grafana-dashboard-config.json)
- [Prometheus Alerts](./performance-alerts.yml)
- [Prometheus Config](./prometheus-config.yml)

### k6 Documentation
- [k6 Official Docs](https://k6.io/docs/)
- [k6 API Reference](https://k6.io/docs/javascript-api/)
- [k6 Best Practices](https://k6.io/docs/testing-guides/load-testing/)

---

## 🎓 Team Training

### For New Team Members
1. Read [QUICK_START_GUIDE.md](./QUICK_START_GUIDE.md)
2. Run baseline test locally
3. Review [Grafana Dashboard](./grafana-dashboard-config.json)
4. Attend team training session

### For Performance Engineers
1. Study [PERFORMANCE_BASELINE_TESTING_SUITE_v1.md](./PERFORMANCE_BASELINE_TESTING_SUITE_v1.md)
2. Understand all 5 test types
3. Learn result analysis techniques
4. Configure monitoring and alerts

### For DevOps Engineers
1. Setup Prometheus and Grafana
2. Configure alert notifications
3. Document runbooks
4. Setup CI/CD integration

---

## ✅ Success Criteria

The performance testing suite is considered successful when:

- ✅ All k6 scripts execute without errors
- ✅ Baseline test passes (100 users, < 500ms p95)
- ✅ Ramp-up test completes without cascading failures
- ✅ Soak test maintains performance for 4 hours
- ✅ Spike test recovers within 30 seconds
- ✅ Stress test identifies max sustainable load
- ✅ Monitoring dashboards display all metrics
- ✅ Alerts trigger at configured thresholds
- ✅ CI/CD integration detects regressions
- ✅ Team trained and confident running tests

---

## 📝 Notes

- Tests should be run from a dedicated load generator (separate from API/DB)
- All tests should use staging environment initially
- Production testing requires separate approval and careful scheduling
- Results should be stored for historical trend analysis
- Baselines should be re-established after major infrastructure changes

---

## 📞 Contact

**Performance Engineering:** performance@basecoat.dev  
**DevOps Team:** devops@basecoat.dev  
**Documentation:** See [PERFORMANCE_BASELINE_TESTING_SUITE_v1.md](./PERFORMANCE_BASELINE_TESTING_SUITE_v1.md)

---

**Wave 3 Day 2 - Performance Baseline Setup** ✅
