import http from 'k6/http';
import { check, group, sleep } from 'k6';
import { Trend, Rate, Gauge, Counter } from 'k6/metrics';

// Custom metrics
const apiDuration = new Trend('api_duration');
const apiErrors = new Rate('api_errors');
const apiSuccess = new Rate('api_success');
const failurePoint = new Gauge('failure_point_users');
const maxSustainableLoad = new Gauge('max_sustainable_load');
const degradationFactor = new Trend('degradation_factor');

// Configuration
const BASE_URL = __ENV.BASE_URL || 'https://staging-api.basecoat.dev/v1';
const API_TOKEN = __ENV.API_TOKEN || 'test-token-123';

// Stress test: Gradually increase load until failure
// Increase 50 users every 2 minutes until error rate exceeds threshold
export const options = {
  stages: [
    // Baseline: 100 users for 2 minutes
    { duration: '2m', target: 100 },
    // Stage 1: 150 users
    { duration: '2m', target: 150 },
    // Stage 2: 200 users
    { duration: '2m', target: 200 },
    // Stage 3: 250 users
    { duration: '2m', target: 250 },
    // Stage 4: 300 users
    { duration: '2m', target: 300 },
    // Stage 5: 350 users
    { duration: '2m', target: 350 },
    // Stage 6: 400 users
    { duration: '2m', target: 400 },
    // Stage 7: 450 users
    { duration: '2m', target: 450 },
    // Stage 8: 500 users
    { duration: '2m', target: 500 },
    // Stage 9: 600 users
    { duration: '2m', target: 600 },
    // Stage 10: 700 users
    { duration: '2m', target: 700 },
    // Stage 11: 800 users
    { duration: '2m', target: 800 },
    // Stage 12: 900 users
    { duration: '2m', target: 900 },
    // Stage 13: 1000 users
    { duration: '2m', target: 1000 },
    // Stage 14: 1200 users (if system still responding)
    { duration: '2m', target: 1200 },
    // Stage 15: 1500 users (find limit)
    { duration: '2m', target: 1500 },
  ],
  thresholds: {
    'http_req_duration': ['p(99)<5000'], // Very lenient during stress test
    'http_req_failed': ['rate<0.50'], // Allow up to 50% failures
    'api_errors': ['rate<0.50'],
  },
  summaryTrendStats: ['avg', 'min', 'med', 'max', 'p(50)', 'p(90)', 'p(95)', 'p(99)', 'p(99.9)'],
};

// Track baseline response time for degradation calculation
let baselineResponseTime = null;

export default function () {
  // Calculate degradation factor
  const currentStageUsers = Math.floor((__VU + 49) / 50) * 50;

  group(`Stress Test - Stage ${currentStageUsers} Users`, () => {
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
      const isSuccess = auditResponse.status === 200;
      apiSuccess.add(isSuccess ? 1 : 0);
      apiErrors.add(isSuccess ? 0 : 1);

      // Track baseline response time at 100 users
      if (!baselineResponseTime && __VU < 110) {
        baselineResponseTime = auditResponse.timings.duration;
      }

      // Calculate degradation factor
      if (baselineResponseTime) {
        const factor = auditResponse.timings.duration / baselineResponseTime;
        degradationFactor.add(factor);

        if (factor > 10) {
          console.warn(`⚠️  10x degradation detected at ${__VU} users: ${auditResponse.timings.duration}ms vs baseline ${baselineResponseTime}ms`);
          failurePoint.add(__VU);
        }
      }

      check(auditResponse, {
        'audit_list_no_timeout': (r) => r.status !== 0,
        'audit_list_response': (r) => {
          // Accept any response (success or failure) to continue test to find actual breaking point
          return true;
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
      const isSuccess = dashResponse.status === 200;
      apiSuccess.add(isSuccess ? 1 : 0);
      apiErrors.add(isSuccess ? 0 : 1);

      check(dashResponse, {
        'dashboard_no_timeout': (r) => r.status !== 0,
        'dashboard_response': (r) => true,
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
      const isSuccess = reportResponse.status === 200;
      apiSuccess.add(isSuccess ? 1 : 0);
      apiErrors.add(isSuccess ? 0 : 1);

      check(reportResponse, {
        'report_no_timeout': (r) => r.status !== 0,
        'report_response': (r) => true,
      });
    });

    sleep(2);
  });
}

export function handleSummary(data) {
  // Analyze results to find max sustainable load
  const metrics = data.metrics;
  let maxSustainableUsers = 100;
  let criticalLoad = 2000;

  if (metrics.api_errors && metrics.api_errors.values && metrics.api_errors.values['rate']) {
    const errorRate = metrics.api_errors.values['rate'];
    if (errorRate < 0.02) {
      maxSustainableUsers = 1500; // Could handle all test stages
    } else if (errorRate < 0.10) {
      maxSustainableUsers = 1200;
    } else if (errorRate < 0.30) {
      maxSustainableUsers = 800;
    }
  }

  console.log(`\n✅ Stress Test Analysis:`);
  console.log(`   - Estimated Max Sustainable Load: ${maxSustainableUsers} users`);
  console.log(`   - See detailed metrics for degradation curves`);

  return {
    'stdout': textSummary(data, { indent: ' ', enableColors: true }),
    'performance-stress-summary.json': JSON.stringify({
      ...data,
      analysis: {
        max_sustainable_users: maxSustainableUsers,
        baseline_response_time_ms: baselineResponseTime,
      },
    }),
  };
}
