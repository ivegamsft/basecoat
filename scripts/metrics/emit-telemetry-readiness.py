"""
BaseCoat Telemetry Readiness Emitter

Checks whether required telemetry dependencies are present and writes a
readiness summary to dashboard/metrics/telemetry-readiness.json.

When APPLICATIONINSIGHTS_CONNECTION_STRING is set, emits a
BaseCoatTelemetryReadiness custom event to App Insights.

Environment variables:
    APPLICATIONINSIGHTS_CONNECTION_STRING — App Insights connection string (optional)
    COPILOT_METRICS_TOKEN                 — PAT with read:org scope (optional)
    DASHBOARD_REPOS                       — JSON array of monitored repos
    OUTPUT_DIR                            — Output directory (default: dashboard/metrics)
"""

import json
import os
import sys
from datetime import datetime, timezone
from urllib.request import Request, urlopen
from urllib.error import HTTPError

from repo_inputs import normalize_dashboard_repos


OUTPUT_DIR = os.environ.get("OUTPUT_DIR", "dashboard/metrics")


def check_dependencies():
    """Check which telemetry dependencies are present."""
    missing = []
    warnings = []

    app_insights = os.environ.get("APPLICATIONINSIGHTS_CONNECTION_STRING", "")
    copilot_token = os.environ.get("COPILOT_METRICS_TOKEN", "")
    dashboard_repos = os.environ.get("DASHBOARD_REPOS", "")

    if not app_insights:
        missing.append(
            "APPLICATIONINSIGHTS_CONNECTION_STRING not set — App Insights emission disabled"
        )

    if not copilot_token:
        missing.append(
            "COPILOT_METRICS_TOKEN not set — reviewer_closure and intake_completeness metrics unavailable"
        )

    if not dashboard_repos:
        missing.append(
            "DASHBOARD_REPOS not configured — no repos scanned"
        )
    else:
        repos = normalize_dashboard_repos(dashboard_repos)
        if not repos:
            missing.append("DASHBOARD_REPOS is an empty list — no repos will be scanned")

    if missing:
        overall = "not-ready" if len(missing) >= 2 else "partial"
    else:
        overall = "ready"

    return {
        "overall": overall,
        "missing_dependencies": missing,
        "warnings": warnings,
    }


def emit_app_insights(connection_string, payload):
    """Emit a custom event to App Insights via direct ingestion."""
    try:
        ikey = ""
        ingestion_endpoint = "https://dc.services.visualstudio.com/"
        for part in connection_string.split(";"):
            key, _, val = part.partition("=")
            if key.strip().lower() == "instrumentationkey":
                ikey = val.strip()
            elif key.strip().lower() == "ingestionendpoint":
                ingestion_endpoint = val.strip().rstrip("/") + "/"

        if not ikey:
            print(
                "  WARNING: Could not extract InstrumentationKey from connection string",
                file=sys.stderr,
            )
            return

        envelope = {
            "name": "Microsoft.ApplicationInsights.Event",
            "time": payload["collected_at"],
            "iKey": ikey,
            "data": {
                "baseType": "EventData",
                "base": {
                    "ver": 2,
                    "name": "BaseCoatTelemetryReadiness",
                    "properties": {
                        "overall": payload["readiness"]["overall"],
                        "missing_count": str(len(payload["readiness"]["missing_dependencies"])),
                        "warning_count": str(len(payload["readiness"]["warnings"])),
                        "repos_configured": str(len(normalize_dashboard_repos(os.environ.get("DASHBOARD_REPOS", "[]")))),
                        "app_insights_connected": str(
                            bool(os.environ.get("APPLICATIONINSIGHTS_CONNECTION_STRING", ""))
                        ).lower(),
                        "copilot_token_present": str(
                            bool(os.environ.get("COPILOT_METRICS_TOKEN", ""))
                        ).lower(),
                    },
                },
            },
        }

        url = f"{ingestion_endpoint}v2/track"
        data = json.dumps(envelope).encode("utf-8")
        req = Request(url, data=data, method="POST")
        req.add_header("Content-Type", "application/json")
        with urlopen(req, timeout=10) as resp:
            print(f"  App Insights emission: HTTP {resp.status}")
    except Exception as exc:
        print(f"  WARNING: App Insights emission failed: {exc}", file=sys.stderr)


def main():
    print("Telemetry Readiness Check...")

    readiness = check_dependencies()
    collected_at = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")

    payload = {
        "schema_version": "1.0.0",
        "collected_at": collected_at,
        "readiness": readiness,
    }

    os.makedirs(OUTPUT_DIR, exist_ok=True)
    out_path = os.path.join(OUTPUT_DIR, "telemetry-readiness.json")
    with open(out_path, "w") as f:
        json.dump(payload, f, indent=2)
    print(f"  Written: {out_path}")

    overall = readiness["overall"]
    if readiness["missing_dependencies"]:
        for dep in readiness["missing_dependencies"]:
            print(f"  MISSING: {dep}", file=sys.stderr)
    if readiness["warnings"]:
        for warn in readiness["warnings"]:
            print(f"  WARNING: {warn}", file=sys.stderr)

    print(f"  Readiness: {overall}")

    conn_str = os.environ.get("APPLICATIONINSIGHTS_CONNECTION_STRING", "")
    if conn_str:
        print("  Emitting to App Insights...")
        emit_app_insights(conn_str, payload)
    else:
        print("  App Insights emission skipped (APPLICATIONINSIGHTS_CONNECTION_STRING not set).")


if __name__ == "__main__":
    main()
