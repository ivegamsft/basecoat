import http from 'k6/http';
import { check, group, sleep } from 'k6';
import { Trend, Rate, Gauge, Counter } from 'k6/metrics';

// Custom metrics
const apiDuration = new Trend('api_duration');
const apiErrors = new Rate('api_errors');
const apiSuccess = new Rate('api_success');
const concurrentUsers = new Gauge('concurrent_users');
const scalingBottleneck = new Counter('scaling_bottleneck_events');

// Configuration
const BASE_URL = __ENV.BASE_URL || 'https://staging-api.basecoat.dev/v1';
const API_TOKEN = __ENV.API_TOKEN || 'test-token-123';

// Ramp-up stages: Warm-up (100) → Ramp-up Phase 1 (100→500) → Ramp-up Phase 2 (500→1000) → Peak (1000) → Cool-down (1000→100)
export const options = {
  stages: [
    // Warm-up: 2 minutes at 100 users
    { duration: '2m', target: 100 },

    // Ramp-up Phase 1: 10 minutes from 100 to 500 users
    { duration: '10m', target: 500 },

    // Ramp-up Phase 2: 10 minutes from 500 to 1000 users
    { duration: '10m', target: 1000 },

    // Peak Hold: 5 minutes at 1000 users
    { duration: '5m', target: 1000 },

    // Cool-down: 2 minutes from 1000 to 100 users
    { duration: '2m', target: 100 },
  ],
  thresholds: {
    'http_req_duration': ['p(95)<800', 'p(99)<1500'],
    'http_req_failed': ['rate<0.02'],
    'api_duration': ['p(95)<800', 'p(99)<1500'],
    'api_errors': ['rate<0.02'],
  },
  summaryTrendStats: ['avg', 'min', 'med', 'max', 'p(50)', 'p(90)', 'p(95)', 'p(99)', 'p(99.9)'],
};

// Helper function to detect scaling bottlenecks
function detectBottleneck(duration, stageUsers) {
  // Detect if response time increases more than expected with user load
  if (duration > 1000 && stageUsers > 500) {
    scalingBottleneck.add(1);
    console.warn(`⚠️  Performance degradation at ${stageUsers} users: ${duration}ms`);
  }
}

export default function () {
  // Update concurrent users gauge
  concurrentUsers.add(__VU);

  group('Ramp-Up Test - Scaling Load', () => {
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
      detectBottleneck(auditResponse.timings.duration, __VU);

      check(auditResponse, {
        'audit_list_status_200': (r) => r.status === 200,
        'audit_list_no_5xx': (r) => r.status < 500,
        'audit_list_body_valid': (r) => {
          try {
            const body = r.body;
            return body && body.length > 0;
          } catch (e) {
            return false;
          }
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
      detectBottleneck(dashResponse.timings.duration, __VU);

      check(dashResponse, {
        'dashboard_status_200': (r) => r.status === 200,
        'dashboard_no_5xx': (r) => r.status < 500,
        'dashboard_body_valid': (r) => {
          try {
            const body = r.body;
            return body && body.length > 0;
          } catch (e) {
            return false;
          }
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
      detectBottleneck(reportResponse.timings.duration, __VU);

      check(reportResponse, {
        'report_status_200': (r) => r.status === 200,
        'report_no_5xx': (r) => r.status < 500,
        'report_body_valid': (r) => {
          try {
            const body = r.body;
            return body && body.length > 0;
          } catch (e) {
            return false;
          }
        },
      });
    });

    sleep(2);
  });
}

export function handleSummary(data) {
  return {
    'stdout': textSummary(data, { indent: ' ', enableColors: true }),
    'performance-rampup-summary.json': JSON.stringify(data),
  };
}
