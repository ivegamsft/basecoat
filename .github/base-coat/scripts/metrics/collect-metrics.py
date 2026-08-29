"""
Base Coat Adoption Metrics Collector

Collects metrics from GitHub APIs and outputs JSON for the dashboard.
Reads configuration from environment variables (set by GitHub Actions secrets).
No secrets are stored in this file.

Usage:
    python collect-metrics.py

Environment variables (set by GitHub Actions from secrets):
    GITHUB_TOKEN          — GitHub token with repo access
    COPILOT_METRICS_TOKEN — Token with org:read for Copilot API (optional, falls back to GITHUB_TOKEN)
    DASHBOARD_ORG         — Organization name
    DASHBOARD_REPOS       — JSON array of repos to monitor
"""

import json
import os
import sys
from datetime import datetime, timedelta, timezone
from urllib.request import Request, urlopen
from urllib.error import HTTPError

try:
    from repo_inputs import normalize_dashboard_repos
except ModuleNotFoundError:
    from pathlib import Path
    import sys as _sys

    _sys.path.insert(0, str(Path(__file__).resolve().parent))
    from repo_inputs import normalize_dashboard_repos


def get_env(name, required=True):
    value = os.environ.get(name, "")
    if required and not value:
        print(f"ERROR: Environment variable {name} not set.", file=sys.stderr)
        sys.exit(1)
    return value


def github_api(url, token):
    """Make authenticated GitHub API request."""
    req = Request(url)
    req.add_header("Authorization", f"token {token}")
    req.add_header("Accept", "application/vnd.github+json")
    req.add_header("X-GitHub-Api-Version", "2022-11-28")
    try:
        with urlopen(req) as resp:
            return json.loads(resp.read().decode())
    except HTTPError as e:
        if e.code == 404:
            return None
        print(f"  WARNING: API error {e.code} for {url}", file=sys.stderr)
        return None


def fetch_text(url):
    """Fetch raw text from a signed URL (no GitHub auth header required)."""
    req = Request(url)
    req.add_header("Accept", "application/json, text/plain, application/x-ndjson")
    try:
        with urlopen(req) as resp:
            return resp.read().decode()
    except HTTPError as e:
        print(f"  WARNING: Could not download report ({e.code}) from {url}", file=sys.stderr)
        return ""


def to_int(value):
    """Best-effort numeric conversion for report fields."""
    if value is None:
        return 0
    try:
        return int(value)
    except (TypeError, ValueError):
        return 0


def collect_dashboard_repos(raw_value):
    """Normalize dashboard repository configuration into repo slugs."""
    return normalize_dashboard_repos(raw_value)


def repo_is_accessible(repo, token):
    """Return True when GitHub can resolve the repository."""
    return github_api(f"https://api.github.com/repos/{repo}", token) is not None


def unavailable_repo_metrics(error):
    return {
        "available": False,
        "error": error,
        "pull_requests": {
            "available": False,
            "error": error,
            "prs_merged_28d": 0,
            "cycle_time_median_hours": 0,
        },
        "ci": {
            "available": False,
            "error": error,
            "success_rate": 0,
            "pass_rate": 0,
            "ci_pass_rate_last_20_runs": 0,
            "ci_pass_rate_last_100_runs": 0,
            "total_runs_sampled": 0,
            "runs_sampled_last_20": 0,
            "successful_runs_last_20": 0,
        },
        "issues": {
            "available": False,
            "error": error,
            "issues_closed_28d": 0,
            "resolution_time_median_hours": 0,
        },
        "basecoat_coverage": {
            "available": False,
            "error": error,
            "agents": 0,
            "instructions": 0,
            "skills": 0,
            "prompts": 0,
            "percentage": 0,
        },
    }


def collect_copilot_metrics(org, token):
    """Collect Copilot usage metrics for the organization."""
    print(f"  Collecting Copilot metrics for {org}...")
    report = github_api(
        f"https://api.github.com/orgs/{org}/copilot/metrics/reports/organization-28-day/latest",
        token,
    )
    if not report:
        print("  WARNING: Could not fetch Copilot metrics (need org admin scope)")
        return {"available": False}

    links = report.get("download_links", [])
    if not links:
        print("  WARNING: Copilot metrics report has no download links")
        return {"available": False}

    raw = fetch_text(links[0])
    rows = []
    for line in raw.splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            rows.append(json.loads(line))
        except json.JSONDecodeError:
            continue

    if not rows:
        return {"available": True, "days": []}

    total_active = sum(
        to_int(day.get("total_active_users") or day.get("daily_active_users"))
        for day in rows
    )
    total_cli = sum(to_int(day.get("daily_active_cli_users")) for day in rows)
    total_cloud_agent = sum(
        to_int(day.get("daily_active_copilot_cloud_agent_users")) for day in rows
    )

    return {
        "available": True,
        "report_start_day": report.get("report_start_day"),
        "report_end_day": report.get("report_end_day"),
        "total_active_users": total_active,
        "daily_active_cli_users_sum": total_cli,
        "daily_active_cloud_agent_users_sum": total_cloud_agent,
        "days": rows[-28:] if len(rows) > 28 else rows,
    }


def collect_pr_metrics(repo, token):
    """Collect PR velocity metrics for a repo."""
    print(f"  Collecting PR metrics for {repo}...")
    if not repo_is_accessible(repo, token):
        return unavailable_repo_metrics("inaccessible_repo")

    since_dt = datetime.now(timezone.utc) - timedelta(days=28)

    # Get recently closed PRs
    prs = github_api(
        f"https://api.github.com/repos/{repo}/pulls?state=closed&sort=updated&per_page=50",
        token
    ) or []

    cycle_times = []
    for pr in prs:
        if not pr.get("merged_at"):
            continue
        created = datetime.fromisoformat(pr["created_at"].replace("Z", "+00:00"))
        merged = datetime.fromisoformat(pr["merged_at"].replace("Z", "+00:00"))
        if merged < since_dt:
            continue
        hours = (merged - created).total_seconds() / 3600
        cycle_times.append(hours)

    if cycle_times:
        cycle_times.sort()
        median = cycle_times[len(cycle_times) // 2]
        p95 = cycle_times[int(len(cycle_times) * 0.95)]
    else:
        median = 0
        p95 = 0

    return {
        "prs_merged_28d": len(cycle_times),
        "cycle_time_median_hours": round(median, 1),
        "cycle_time_p95_hours": round(p95, 1)
    }


def collect_ci_metrics(repo, token):
    """Collect CI pass-rate metrics for a repo."""
    print(f"  Collecting CI metrics for {repo}...")
    if not repo_is_accessible(repo, token):
        return unavailable_repo_metrics("inaccessible_repo")

    runs = github_api(
        f"https://api.github.com/repos/{repo}/actions/runs?per_page=100&status=completed",
        token
    )
    if not runs or "workflow_runs" not in runs:
        return {
            "success_rate": 0,
            "pass_rate": 0,
            "ci_pass_rate_last_20_runs": 0,
            "ci_pass_rate_last_100_runs": 0,
            "total_runs_sampled": 0,
            "runs_sampled_last_20": 0,
            "successful_runs_last_20": 0,
        }

    workflow_runs = runs["workflow_runs"][:100]

    # Prefer canonical CI workflows for signal quality.
    canonical_ci_names = {"ci", "pr validation", "validate basecoat", "validate base coat"}
    ci_runs = [r for r in workflow_runs if (r.get("name") or "").strip().lower() in canonical_ci_names]
    sampled_runs = ci_runs if ci_runs else workflow_runs

    # Exclude non-signal conclusions from denominator.
    measurable_runs = [
        r for r in sampled_runs
        if r.get("conclusion") in {"success", "failure", "timed_out", "startup_failure"}
    ]
    measurable_20 = measurable_runs[:20]
    success_total = sum(1 for r in measurable_runs if r.get("conclusion") == "success")
    success_20 = sum(1 for r in measurable_20 if r.get("conclusion") == "success")
    total = len(measurable_runs)
    total_20 = len(measurable_20)

    pass_rate_100 = round(success_total / total * 100, 1) if total > 0 else 0
    pass_rate_20 = round(success_20 / total_20 * 100, 1) if total_20 > 0 else 0

    return {
        "success_rate": pass_rate_100,  # Backward-compatible field.
        "pass_rate": pass_rate_100,
        "ci_pass_rate_last_20_runs": pass_rate_20,
        "ci_pass_rate_last_100_runs": pass_rate_100,
        "total_runs_sampled": total,
        "runs_sampled_last_20": total_20,
        "successful_runs_last_20": success_20,
    }


def collect_issue_metrics(repo, token):
    """Collect issue resolution metrics."""
    print(f"  Collecting issue metrics for {repo}...")
    if not repo_is_accessible(repo, token):
        return unavailable_repo_metrics("inaccessible_repo")

    since = (datetime.now(timezone.utc) - timedelta(days=28)).isoformat()

    issues = github_api(
        f"https://api.github.com/repos/{repo}/issues?state=closed&since={since}&per_page=50",
        token
    ) or []

    # Filter out PRs (they show up in issues endpoint)
    issues = [i for i in issues if "pull_request" not in i]

    resolution_times = []
    for issue in issues:
        created = datetime.fromisoformat(issue["created_at"].replace("Z", "+00:00"))
        closed = datetime.fromisoformat(issue["closed_at"].replace("Z", "+00:00"))
        hours = (closed - created).total_seconds() / 3600
        resolution_times.append(hours)

    median = 0
    if resolution_times:
        resolution_times.sort()
        median = resolution_times[len(resolution_times) // 2]

    return {
        "issues_closed_28d": len(resolution_times),
        "resolution_time_median_hours": round(median, 1)
    }


def collect_basecoat_coverage(repo, token):
    """Check which Base Coat assets are present in the target repo."""
    print(f"  Checking Base Coat coverage in {repo}...")
    if not repo_is_accessible(repo, token):
        return unavailable_repo_metrics("inaccessible_repo")

    # Check for common basecoat directories
    coverage = {}
    for path in [".github/agents", ".github/instructions", ".github/skills", ".github/prompts"]:
        result = github_api(
            f"https://api.github.com/repos/{repo}/contents/{path}",
            token
        )
        if result and isinstance(result, list):
            coverage[path.split("/")[-1]] = len(result)
        else:
            coverage[path.split("/")[-1]] = 0

    total_possible = 43 + 27 + 21 + 3  # agents + instructions + skills + prompts
    total_found = sum(coverage.values())
    coverage["percentage"] = round(total_found / total_possible * 100, 1)

    return coverage


def render_summary(metrics):
    """Render the adoption metrics summary markdown."""
    lines = []
    lines.append("# Adoption Metrics Summary")
    lines.append("")
    lines.append(f"Collected: {metrics['collected_at'][:10]}")
    lines.append("")
    lines.append("## Copilot Usage")
    lines.append("")
    if metrics["copilot"]["available"]:
        lines.append(f"- Active users: {metrics['copilot'].get('total_active_users', 'N/A')}")
        lines.append("")
    else:
        lines.append("- Copilot metrics not available (check token permissions)")
        lines.append("")
    lines.append("## Repository Metrics")
    lines.append("")
    lines.append("| Repo | PRs Merged | Cycle Time | CI Success (100 runs) | CI Pass Rate (20 runs) | Coverage |")
    lines.append("|------|-----------|------------|-----------------------|------------------------|----------|")
    for repo, data in metrics["repos"].items():
        pr = data.get("pull_requests", {})
        ci = data.get("ci", {})
        cov = data.get("basecoat_coverage", {})
        if data.get("available") is False:
            lines.append(f"| {repo} | unavailable | unavailable | unavailable | unavailable | unavailable |")
            continue
        ci_success = ci.get("success_rate", 0)
        ci_pass_20 = ci.get("ci_pass_rate_last_20_runs", ci_success)
        sampled_20 = ci.get("runs_sampled_last_20", 0)
        success_20 = ci.get("successful_runs_last_20", 0)
        lines.append(
            f"| {repo} | {pr.get('prs_merged_28d', 0)} | {pr.get('cycle_time_median_hours', 0)}h | "
            f"{ci_success}% | {ci_pass_20}% ({success_20}/{sampled_20}) | {cov.get('percentage', 0)}% |"
        )
    lines.append("")
    return "\n".join(lines)


def detect_degradation(current, history):
    """Compare current metrics to recent history and flag regressions."""
    alerts = []
    if len(history) < 2:
        return alerts

    prev = history[-2]

    # Check Copilot active user decline
    if current["copilot"]["available"] and prev.get("copilot", {}).get("available"):
        curr_users = current["copilot"].get("total_active_users", 0)
        prev_users = prev["copilot"].get("total_active_users", 0)
        if prev_users > 0 and curr_users < prev_users * 0.9:
            alerts.append({
                "type": "copilot_active_users_drop",
                "severity": "warning",
                "message": f"Copilot active users dropped from {prev_users} to {curr_users}",
                "previous": prev_users,
                "current": curr_users,
            })

    # Check per-repo CI success rate drop
    for repo, data in current.get("repos", {}).items():
        if data.get("available") is False:
            continue
        prev_repo = prev.get("repos", {}).get(repo, {})
        curr_ci = data.get("ci", {}).get("pass_rate", data.get("ci", {}).get("success_rate", 100))
        prev_ci = prev_repo.get("ci", {}).get("pass_rate", prev_repo.get("ci", {}).get("success_rate", 100))
        if prev_ci > 0 and curr_ci < prev_ci - 15:
            alerts.append({
                "type": "ci_success_drop",
                "severity": "warning",
                "repo": repo,
                "message": f"CI success rate for {repo} dropped from {prev_ci}% to {curr_ci}%",
                "previous": prev_ci,
                "current": curr_ci
            })

        # Check PR cycle time increase (>50% slower)
        curr_cycle = data.get("pull_requests", {}).get("cycle_time_median_hours", 0)
        prev_cycle = prev_repo.get("pull_requests", {}).get("cycle_time_median_hours", 0)
        if prev_cycle > 0 and curr_cycle > prev_cycle * 1.5:
            alerts.append({
                "type": "cycle_time_increase",
                "severity": "info",
                "repo": repo,
                "message": f"PR cycle time for {repo} increased from {prev_cycle}h to {curr_cycle}h",
                "previous": prev_cycle,
                "current": curr_cycle
            })

    return alerts


def main():
    print("Base Coat Adoption Metrics Collector")
    print("=" * 40)

    token = get_env("GITHUB_TOKEN")
    copilot_token = os.environ.get("COPILOT_METRICS_TOKEN", token)
    org = get_env("DASHBOARD_ORG")
    repos_json = get_env("DASHBOARD_REPOS")
    repos = collect_dashboard_repos(repos_json)

    print(f"Organization: {org}")
    print(f"Repos to monitor: {repos}")
    print("")

    # Collect metrics
    metrics = {
        "collected_at": datetime.now(timezone.utc).isoformat(),
        "organization": org,
        "copilot": collect_copilot_metrics(org, copilot_token),
        "repos": {}
    }

    for repo in repos:
        print(f"\n── {repo} ──")
        if not repo_is_accessible(repo, token):
            metrics["repos"][repo] = unavailable_repo_metrics("inaccessible_repo")
            continue
        metrics["repos"][repo] = {
            "available": True,
            "pull_requests": collect_pr_metrics(repo, token),
            "ci": collect_ci_metrics(repo, token),
            "issues": collect_issue_metrics(repo, token),
            "basecoat_coverage": collect_basecoat_coverage(repo, token)
        }

    # Output
    output_dir = os.environ.get("OUTPUT_DIR", "metrics")
    os.makedirs(output_dir, exist_ok=True)

    # Write current metrics
    output_path = os.path.join(output_dir, "latest.json")
    with open(output_path, "w") as f:
        json.dump(metrics, f, indent=2)
    print(f"\n✓ Metrics written to {output_path}")

    # Append to history
    history_path = os.path.join(output_dir, "history.json")
    history = []
    if os.path.exists(history_path):
        with open(history_path) as f:
            history = json.load(f)

    history.append(metrics)
    # Keep last 52 weeks
    history = history[-52:]

    with open(history_path, "w") as f:
        json.dump(history, f, indent=2)
    print(f"✓ History updated ({len(history)} data points)")

    # Check for degradation signals and output alerts
    alerts = detect_degradation(metrics, history)
    alerts_path = os.path.join(output_dir, "alerts.json")
    with open(alerts_path, "w") as f:
        json.dump(alerts, f, indent=2)
    if alerts:
        print(f"⚠ {len(alerts)} degradation alert(s) detected")
    else:
        print("✓ No degradation signals")

    # Generate summary markdown
    summary_path = os.path.join(output_dir, "SUMMARY.md")
    with open(summary_path, "w") as f:
        f.write(render_summary(metrics))
    print(f"✓ Summary written to {summary_path}")


if __name__ == "__main__":
    main()
