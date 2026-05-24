import http from 'k6/http';
import { check, group, sleep } from 'k6';
import { Trend, Rate, Gauge, Counter } from 'k6/metrics';

// Custom metrics
const apiDuration = new Trend('api_duration');
const apiErrors = new Rate('api_errors');
const apiSuccess = new Rate('api_success');
const memoryLeak = new Gauge('memory_leak_indicator');
const connectionPoolSize = new Gauge('db_connection_pool_size');
const cacheHitRate = new Rate('cache_hit_rate');

// Configuration
const BASE_URL = __ENV.BASE_URL || 'https://staging-api.basecoat.dev/v1';
const API_TOKEN = __ENV.API_TOKEN || 'test-token-123';

// Soak test: 500 users for 4 hours
export const options = {
  stages: [
    // Ramp-up: 5 minutes to 500 users
    { duration: '5m', target: 500 },

    // Soak: 4 hours at 500 users
    { duration: '4h', target: 500 },

    // Ramp-down: 5 minutes to 0
    { duration: '5m', target: 0 },
  ],
  thresholds: {
    'http_req_duration': ['p(95)<500', 'p(99)<1000'],
    'http_req_failed': ['rate<0.005'],
    'api_duration': ['p(95)<500'],
    'api_errors': ['rate<0.005'],
  },
  summaryTrendStats: ['avg', 'min', 'med', 'max', 'p(50)', 'p(90)', 'p(95)', 'p(99)'],
};

// Execution context for tracking
let executionStartTime = Date.now();

export default function () {
  const currentTime = Date.now();
  const elapsedSeconds = (currentTime - executionStartTime) / 1000;
  const elapsedHours = Math.floor(elapsedSeconds / 3600);
  const elapsedMinutes = Math.floor((elapsedSeconds % 3600) / 60);

  group(`Soak Test - Elapsed Time: ${elapsedHours}h ${elapsedMinutes}m`, () => {
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

      // Check for cache hit indicator (X-Cache-Hit header)
      const cacheHit = auditResponse.headers['X-Cache-Hit'] === 'true' ? 1 : 0;
      cacheHitRate.add(cacheHit);

      check(auditResponse, {
        'audit_list_status_200': (r) => r.status === 200,
        'audit_list_duration_stable': (r) => r.timings.duration < 600,
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

      const cacheHit = dashResponse.headers['X-Cache-Hit'] === 'true' ? 1 : 0;
      cacheHitRate.add(cacheHit);

      check(dashResponse, {
        'dashboard_status_200': (r) => r.status === 200,
        'dashboard_duration_stable': (r) => r.timings.duration < 600,
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

      const cacheHit = reportResponse.headers['X-Cache-Hit'] === 'true' ? 1 : 0;
      cacheHitRate.add(cacheHit);

      check(reportResponse, {
        'report_status_200': (r) => r.status === 200,
        'report_duration_stable': (r) => r.timings.duration < 600,
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

  // Simulate connection pool tracking (would be pulled from metrics in real scenario)
  connectionPoolSize.add(50 + Math.random() * 10); // Simulate stable connection pool
}

export function handleSummary(data) {
  return {
    'stdout': textSummary(data, { indent: ' ', enableColors: true }),
    'performance-soak-summary.json': JSON.stringify(data),
  };
}
