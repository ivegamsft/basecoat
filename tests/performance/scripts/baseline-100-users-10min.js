import http from 'k6/http';
import { check, group, sleep } from 'k6';
import { Trend, Rate, Gauge, Counter } from 'k6/metrics';

// Custom metrics
const apiDuration = new Trend('api_duration');
const apiErrors = new Rate('api_errors');
const apiSuccess = new Rate('api_success');
const concurrentUsers = new Gauge('concurrent_users');

// Configuration
const BASE_URL = __ENV.BASE_URL || 'https://staging-api.basecoat.dev/v1';
const API_TOKEN = __ENV.API_TOKEN || 'test-token-123';

// VUs and duration (can be overridden from command line)
export const options = {
  stages: [
    { duration: '1m', target: 100 },      // Ramp up to 100 users
    { duration: '10m', target: 100 },     // Hold 100 users
    { duration: '1m', target: 0 },        // Ramp down
  ],
  thresholds: {
    'http_req_duration': ['p(95)<500', 'p(99)<800'],
    'http_req_failed': ['rate<0.01'],
    'api_duration': ['p(95)<500', 'p(99)<800'],
    'api_errors': ['rate<0.01'],
  },
  summaryTrendStats: ['avg', 'min', 'med', 'max', 'p(50)', 'p(95)', 'p(99)', 'p(99.9)'],
};

export default function () {
  // Update concurrent users gauge
  concurrentUsers.add(__VU);

  group('Baseline Load Test - Core Endpoints', () => {
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

      check(auditResponse, {
        'audit_list_status_200': (r) => r.status === 200,
        'audit_list_duration_p95': (r) => r.timings.duration < 500,
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

    // Think time between requests
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
        'dashboard_status_200': (r) => r.status === 200,
        'dashboard_duration_p95': (r) => r.timings.duration < 500,
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

    // Think time between requests
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
        'report_status_200': (r) => r.status === 200,
        'report_duration_p95': (r) => r.timings.duration < 500,
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

    // Think time between requests
    sleep(2);
  });
}

export function handleSummary(data) {
  return {
    'stdout': textSummary(data, { indent: ' ', enableColors: true }),
    'performance-baseline-summary.json': JSON.stringify(data),
  };
}
