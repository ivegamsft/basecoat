#!/usr/bin/env python3
"""
Performance Test Result Analyzer
Analyzes k6 test results and compares against baseline metrics
"""

import json
import sys
import argparse
from datetime import datetime
from pathlib import Path
from typing import Dict, Tuple, Optional


class PerformanceAnalyzer:
    """Analyze performance test results and detect regressions"""

    def __init__(self, baseline_file: str, current_file: str, threshold: float = 0.10):
        """
        Initialize analyzer with baseline and current results

        Args:
            baseline_file: Path to baseline metrics JSON
            current_file: Path to current test results JSON
            threshold: Regression threshold (default: 10%)
        """
        self.baseline = self._load_metrics(baseline_file)
        self.current = self._load_metrics(current_file)
        self.threshold = threshold
        self.regressions = []

    @staticmethod
    def _load_metrics(file_path: str) -> Dict:
        """Load metrics from JSON file"""
        try:
            with open(file_path, 'r') as f:
                return json.load(f)
        except FileNotFoundError:
            print(f"❌ File not found: {file_path}")
            sys.exit(1)

    def analyze_response_time(self) -> Tuple[bool, str]:
        """Analyze response time metrics (p95, p99)"""
        baseline_p95 = self.baseline.get('metrics', {}).get('response_time_p95_ms', 0)
        current_p95 = self._extract_percentile(self.current, 'p95')

        if baseline_p95 == 0:
            return True, "Baseline p95 not available"

        regression = ((current_p95 - baseline_p95) / baseline_p95)

        if regression > self.threshold:
            msg = f"❌ P95 Response Time Regression: {current_p95}ms vs {baseline_p95}ms ({regression*100:.1f}%)"
            self.regressions.append(msg)
            return False, msg
        else:
            return True, f"✅ P95 Response Time OK: {current_p95}ms (baseline: {baseline_p95}ms, {regression*100:.1f}%)"

    def analyze_error_rate(self) -> Tuple[bool, str]:
        """Analyze error rate metrics"""
        baseline_error = self.baseline.get('metrics', {}).get('error_rate_percent', 0) / 100
        current_error = self._extract_error_rate(self.current)

        if baseline_error == 0 and current_error == 0:
            return True, "✅ Error Rate OK: 0%"

        if baseline_error == 0:
            return False, f"❌ Error Rate increased from 0% to {current_error*100:.2f}%"

        regression = ((current_error - baseline_error) / baseline_error)

        if regression > self.threshold:
            msg = f"❌ Error Rate Regression: {current_error*100:.2f}% vs {baseline_error*100:.2f}% ({regression*100:.1f}%)"
            self.regressions.append(msg)
            return False, msg
        else:
            return True, f"✅ Error Rate OK: {current_error*100:.2f}% (baseline: {baseline_error*100:.2f}%)"

    def analyze_throughput(self) -> Tuple[bool, str]:
        """Analyze throughput metrics"""
        baseline_throughput = self.baseline.get('metrics', {}).get('throughput_req_per_sec', 0)
        current_throughput = self._extract_throughput(self.current)

        if baseline_throughput == 0:
            return True, "Baseline throughput not available"

        regression = ((baseline_throughput - current_throughput) / baseline_throughput)

        if regression > self.threshold:
            msg = f"❌ Throughput Degradation: {current_throughput} req/s vs {baseline_throughput} req/s ({regression*100:.1f}%)"
            self.regressions.append(msg)
            return False, msg
        else:
            return True, f"✅ Throughput OK: {current_throughput} req/s (baseline: {baseline_throughput} req/s)"

    @staticmethod
    def _extract_percentile(data: Dict, percentile: str) -> float:
        """Extract percentile from k6 results"""
        try:
            return data['metrics']['http_req_duration']['values'][percentile]
        except KeyError:
            return 0

    @staticmethod
    def _extract_error_rate(data: Dict) -> float:
        """Extract error rate from k6 results"""
        try:
            return data['metrics']['http_req_failed']['values']['rate']
        except KeyError:
            return 0

    @staticmethod
    def _extract_throughput(data: Dict) -> float:
        """Extract throughput from k6 results"""
        try:
            return data['metrics']['http_reqs']['values']['rate']
        except KeyError:
            return 0

    def generate_report(self) -> str:
        """Generate comprehensive analysis report"""
        report = []
        report.append("\n" + "="*70)
        report.append("PERFORMANCE TEST ANALYSIS REPORT")
        report.append("="*70 + "\n")

        report.append(f"Generated: {datetime.now().isoformat()}")
        report.append(f"Threshold: {self.threshold*100:.1f}%\n")

        # Analyze metrics
        rt_pass, rt_msg = self.analyze_response_time()
        report.append(rt_msg)

        er_pass, er_msg = self.analyze_error_rate()
        report.append(er_msg)

        tp_pass, tp_msg = self.analyze_throughput()
        report.append(tp_msg)

        # Summary
        report.append("\n" + "-"*70)
        if rt_pass and er_pass and tp_pass:
            report.append("✅ OVERALL: PASS - No regressions detected")
        else:
            report.append("❌ OVERALL: FAIL - Regressions detected:")
            for regression in self.regressions:
                report.append(f"   {regression}")

        report.append("-"*70 + "\n")

        return "\n".join(report)

    def generate_markdown_report(self) -> str:
        """Generate markdown report for PR comments"""
        rt_pass, rt_msg = self.analyze_response_time()
        er_pass, er_msg = self.analyze_error_rate()
        tp_pass, tp_msg = self.analyze_throughput()

        status = "✅ PASS" if (rt_pass and er_pass and tp_pass) else "❌ FAIL"

        report = f"""## {status} Performance Regression Check

| Metric | Status | Details |
|--------|--------|---------|
| Response Time (p95) | {'✅' if rt_pass else '❌'} | {rt_msg.split(':', 1)[1].strip() if ':' in rt_msg else rt_msg} |
| Error Rate | {'✅' if er_pass else '❌'} | {er_msg.split(':', 1)[1].strip() if ':' in er_msg else er_msg} |
| Throughput | {'✅' if tp_pass else '❌'} | {tp_msg.split(':', 1)[1].strip() if ':' in tp_msg else tp_msg} |

**Threshold:** {self.threshold*100:.1f}%

---
"""
        return report


def main():
    parser = argparse.ArgumentParser(description='Analyze performance test results')
    parser.add_argument('--current', required=True, help='Current test results (JSON)')
    parser.add_argument('--baseline', required=True, help='Baseline metrics (JSON)')
    parser.add_argument('--threshold', type=float, default=0.10, help='Regression threshold (default: 0.10)')
    parser.add_argument('--markdown', action='store_true', help='Generate markdown report')

    args = parser.parse_args()

    analyzer = PerformanceAnalyzer(args.baseline, args.current, args.threshold)

    if args.markdown:
        report = analyzer.generate_markdown_report()
    else:
        report = analyzer.generate_report()

    print(report)

    # Write report to file
    report_file = 'performance-analysis-report.md' if args.markdown else 'performance-analysis-report.txt'
    with open(report_file, 'w') as f:
        f.write(report)

    # Exit with appropriate code
    sys.exit(0 if not analyzer.regressions else 1)


if __name__ == '__main__':
    main()
