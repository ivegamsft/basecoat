import http from 'k6/http';
import { check, group, sleep } from 'k6';
import { Trend, Rate, Gauge, Counter } from 'k6/metrics';

// Custom metrics
const apiDuration = new Trend('api_duration');
const apiErrors = new Rate('api_errors');
const apiSuccess = new Rate('api_success');
const recoveryTime = new Gauge('recovery_time_ms');
const queueDepth = new Gauge('queue_depth');
const cascadingFailure = new Counter('cascading_failure_events');

// Configuration
const BASE_URL = __ENV.BASE_URL || 'https://staging-api.basecoat.dev/v1';
const API_TOKEN = __ENV.API_TOKEN || 'test-token-123';

// Spike test: Sudden jump from 100 to 1000 users
export const options = {
  stages: [
    // Baseline: 100 users for 1 minute
    { duration: '1m', target: 100 },

    // Spike: Jump to 1000 users instantly (0 ramp-up)
    { duration: '5m', target: 1000 },

    // Cool-down: Ramp down to 100 users over 1 minute
    { duration: '1m', target: 100 },
  ],
  thresholds: {
    'http_req_duration': ['p(95)<1500', 'p(99)<2500'],
    'http_req_failed': ['rate<0.05'], // 5% acceptable during spike
    'api_duration': ['p(95)<1500'],
    'api_errors': ['rate<0.05'],
  },
  summaryTrendStats: ['avg', 'min', 'med', 'max', 'p(50)', 'p(90)', 'p(95)', 'p(99)', 'p(99.9)'],
};

// Track when spike occurs
let spikeStartTime = null;
let recoveryDetected = false;
let firstResponseInSpike = null;

export default function () {
  // Mark spike start time at 1000 users
  if (!spikeStartTime && __VU > 100) {
    spikeStartTime = Date.now();
    console.log('📊 SPIKE DETECTED: Ramp from 100 to 1000 users started');
  }

  group('Spike Test - Traffic Surge & Recovery', () => {
    // Test 1: List Audits (Read endpoint)
    group('GET /audits', () => {
      const auditResponse = http.get(`${BASE_URL}/audits?limit=50&offset=0`, {
        headers: {
          'Authorization': `Bearer ${API_TOKEN}`,
          'Content-Type': 'application/json',
        },
        tags: { name: 'ListAudits' },
      });

      apiDuration.add(auditResponse.timings.duration, { endpoint: 'audits' });
      apiSuccess.add(auditResponse.status === 200 ? 1 : 0);
      apiErrors.add(auditResponse.status !== 200 ? 1 : 0);

      // Track first response during spike
      if (spikeStartTime && !firstResponseInSpike) {
        firstResponseInSpike = Date.now();
        const responseTime = firstResponseInSpike - spikeStartTime;
        console.log(`⏱️  First response in spike: ${responseTime}ms`);
        if (responseTime <= 30000) {
          recoveryTime.add(responseTime);
        }
      }

      // Detect cascading failures
      if (auditResponse.status >= 500 && __VU > 800) {
        cascadingFailure.add(1);
        console.warn(`⚠️  Cascading failure detected: ${auditResponse.status} at ${__VU} users`);
      }

      check(auditResponse, {
        'audit_list_no_timeout': (r) => r.status !== 0 && r.status !== 504,
        'audit_list_recovery': (r) => {
          // During recovery phase, we expect occasional failures but eventual success
          if (spikeStartTime && Date.now() - spikeStartTime > 120000) {
            // After 2 minutes, expect success
            return r.status === 200;
          }
          return r.status === 200 || r.status >= 400; // Accept errors during spike
        },
      });
    });

    sleep(2);

    // Test 2: Dashboard Metrics (Aggregation endpoint)
    group('GET /dashboard/metrics', () => {
      const dashResponse = http.get(`${BASE_URL}/dashboard/metrics`, {
        headers: {
          'Authorization': `Bearer ${API_TOKEN}`,
          'Content-Type': 'application/json',
        },
        tags: { name: 'DashboardMetrics' },
      });

      apiDuration.add(dashResponse.timings.duration, { endpoint: 'dashboard' });
      apiSuccess.add(dashResponse.status === 200 ? 1 : 0);
      apiErrors.add(dashResponse.status !== 200 ? 1 : 0);

      check(dashResponse, {
        'dashboard_no_timeout': (r) => r.status !== 0 && r.status !== 504,
        'dashboard_recovery': (r) => {
          if (spikeStartTime && Date.now() - spikeStartTime > 120000) {
            return r.status === 200;
          }
          return r.status === 200 || r.status >= 400;
        },
      });
    });

    sleep(2);

    // Test 3: Compliance Report (Complex aggregation endpoint)
    group('GET /reports/compliance', () => {
      const reportResponse = http.get(`${BASE_URL}/reports/compliance?period=30`, {
        headers: {
          'Authorization': `Bearer ${API_TOKEN}`,
          'Content-Type': 'application/json',
        },
        tags: { name: 'ComplianceReport' },
      });

      apiDuration.add(reportResponse.timings.duration, { endpoint: 'compliance' });
      apiSuccess.add(reportResponse.status === 200 ? 1 : 0);
      apiErrors.add(reportResponse.status !== 200 ? 1 : 0);

      check(reportResponse, {
        'report_no_timeout': (r) => r.status !== 0 && r.status !== 504,
        'report_recovery': (r) => {
          if (spikeStartTime && Date.now() - spikeStartTime > 120000) {
            return r.status === 200;
          }
          return r.status === 200 || r.status >= 400;
        },
      });
    });

    sleep(2);
  });
}

export function handleSummary(data) {
  return {
    'stdout': textSummary(data, { indent: ' ', enableColors: true }),
    'performance-spike-summary.json': JSON.stringify(data),
  };
}
