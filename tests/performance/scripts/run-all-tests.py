#!/usr/bin/env python3
"""
Comprehensive Performance Test Runner
Executes all 5 load test types with monitoring and result collection
"""

import subprocess
import json
import sys
import time
import os
from datetime import datetime
from pathlib import Path


class PerformanceTestRunner:
    """Run comprehensive performance tests"""

    TESTS = [
        {
            'name': 'baseline',
            'script': 'baseline-100-users-10min.js',
            'description': '100 concurrent users for 10 minutes',
            'duration': '12m',
        },
        {
            'name': 'ramp-up',
            'script': 'ramp-up-100-1000-users-29min.js',
            'description': '100 → 500 → 1000 users over 29 minutes',
            'duration': '31m',
        },
        {
            'name': 'soak',
            'script': 'soak-500-users-4hr.js',
            'description': '500 users for 4 hours',
            'duration': '4h 10m',
        },
        {
            'name': 'spike',
            'script': 'spike-100-1000-100-7min.js',
            'description': 'Sudden spike from 100 to 1000 users',
            'duration': '7m',
        },
        {
            'name': 'stress',
            'script': 'stress-to-failure-incremental.js',
            'description': 'Gradual load increase until failure',
            'duration': '30m',
        },
    ]

    def __init__(self, base_url: str, auth_token: str, skip_tests: list = None):
        """Initialize test runner"""
        self.base_url = base_url
        self.auth_token = auth_token
        self.skip_tests = skip_tests or []
        self.results = {}
        self.start_time = datetime.now()

    def run_all_tests(self):
        """Execute all performance tests"""
        print("\n" + "="*70)
        print("BASECOAT PORTAL - COMPREHENSIVE PERFORMANCE TEST SUITE")
        print("="*70)
        print(f"Start Time: {self.start_time.isoformat()}")
        print(f"Base URL: {self.base_url}\n")

        for test in self.TESTS:
            if test['name'] in self.skip_tests:
                print(f"⏭️  Skipping {test['name']} test (as requested)")
                continue

            print(f"\n{'='*70}")
            print(f"Test: {test['name'].upper()}")
            print(f"Description: {test['description']}")
            print(f"Expected Duration: {test['duration']}")
            print("="*70)

            self.run_test(test)

        self.generate_summary()

    def run_test(self, test: dict):
        """Run a single performance test"""
        script_path = f"./scripts/{test['script']}"

        cmd = [
            'k6',
            'run',
            script_path,
            '--out', f"json=results-{test['name']}.json",
            '--out', 'cloud',
            '-e', f"BASE_URL={self.base_url}",
        ]

        try:
            print(f"\n▶️  Running: {' '.join(cmd)}\n")
            env = os.environ.copy()
            env['API_TOKEN'] = self.auth_token
            result = subprocess.run(cmd, check=True, capture_output=False, env=env)

            # Load and store results
            results_file = f"results-{test['name']}.json"
            with open(results_file, 'r') as f:
                self.results[test['name']] = json.load(f)

            print(f"\n✅ {test['name'].upper()} test completed successfully")

        except subprocess.CalledProcessError as e:
            print(f"\n❌ {test['name'].upper()} test failed: {e}")
            self.results[test['name']] = {'status': 'failed', 'error': str(e)}

    def generate_summary(self):
        """Generate comprehensive test summary"""
        end_time = datetime.now()
        duration = end_time - self.start_time

        print("\n" + "="*70)
        print("TEST EXECUTION SUMMARY")
        print("="*70)
        print(f"Start Time: {self.start_time.isoformat()}")
        print(f"End Time: {end_time.isoformat()}")
        print(f"Total Duration: {duration}")
        print(f"Tests Run: {len(self.results)}")

        # Extract key metrics
        print("\n" + "-"*70)
        print("KEY METRICS")
        print("-"*70)

        for test_name, results in self.results.items():
            if 'status' in results and results['status'] == 'failed':
                print(f"\n{test_name.upper()}: ❌ FAILED")
                print(f"  Error: {results.get('error', 'Unknown error')}")
                continue

            print(f"\n{test_name.upper()}:")

            # Extract metrics
            metrics = results.get('metrics', {})

            p95 = metrics.get('http_req_duration', {}).get('values', {}).get('p95', 'N/A')
            p99 = metrics.get('http_req_duration', {}).get('values', {}).get('p99', 'N/A')
            error_rate = metrics.get('http_req_failed', {}).get('values', {}).get('rate', 'N/A')
            throughput = metrics.get('http_reqs', {}).get('values', {}).get('rate', 'N/A')

            print(f"  Response Time (p95): {p95}ms")
            print(f"  Response Time (p99): {p99}ms")
            print(f"  Error Rate: {error_rate}")
            print(f"  Throughput: {throughput} req/s")

            # Determine pass/fail
            if isinstance(p95, (int, float)) and p95 < 2000:
                print(f"  Status: ✅ PASS")
            else:
                print(f"  Status: ⚠️  REVIEW")

        # Overall summary
        print("\n" + "-"*70)
        print("OVERALL STATUS")
        print("-"*70)

        failed_tests = sum(1 for r in self.results.values() if r.get('status') == 'failed')
        passed_tests = len(self.results) - failed_tests

        if failed_tests == 0:
            print(f"✅ ALL {len(self.results)} TESTS PASSED")
        else:
            print(f"⚠️  {passed_tests} passed, {failed_tests} failed")

        # Save summary
        summary = {
            'start_time': self.start_time.isoformat(),
            'end_time': end_time.isoformat(),
            'total_duration_seconds': duration.total_seconds(),
            'tests_run': len(self.results),
            'tests_passed': passed_tests,
            'tests_failed': failed_tests,
            'results': self.results,
        }

        with open('performance-test-summary.json', 'w') as f:
            json.dump(summary, f, indent=2)

        print(f"\n📊 Summary saved to: performance-test-summary.json")


def main():
    import argparse

    parser = argparse.ArgumentParser(description='Run comprehensive performance tests')
    parser.add_argument('--base-url', default='https://staging-api.basecoat.dev/v1',
                        help='API base URL')
    parser.add_argument('--api-token', required=False,
                        help='API authentication token')
    parser.add_argument('--skip', nargs='+', default=[],
                        help='Tests to skip (baseline, ramp-up, soak, spike, stress)')

    args = parser.parse_args()

    # Use environment variable if token not provided; never default to a placeholder secret.
    auth_token = args.api_token or os.environ.get('API_TOKEN')
    if not auth_token:
        parser.error('API token is required via --api-token or API_TOKEN environment variable')

    runner = PerformanceTestRunner(args.base_url, auth_token, args.skip)
    runner.run_all_tests()


if __name__ == '__main__':
    main()
