#!/usr/bin/env python3
"""Generate docs/reference/BACKLOG_SESSION_SCORECARD.md."""

from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime
from pathlib import Path


def format_int(value: int | None) -> str:
    if value is None:
        return "-"
    return f"{value:,}"


def format_decimal(value: float | int | None, suffix: str = "") -> str:
    if value is None:
        return "-"
    if isinstance(value, int):
        return f"{value}{suffix}"
    return f"{value:.1f}{suffix}"


def format_bool(value: bool) -> str:
    return "yes" if value else "no"


def escape_cell(value: str) -> str:
    return value.replace("|", r"\|")


def load_source(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def normalize_sessions(source: dict) -> list[dict]:
    sessions = source.get("sessions", [])
    normalized = []
    for session in sessions:
        normalized.append(
            {
                "date": session["date"],
                "label": session["label"],
                "tokens": session["tokens"],
                "events": session["events"],
                "ratio": session["ratio"],
                "phaseCompactions": session["phaseCompactions"],
                "maxPromptKb": session["maxPromptKb"],
                "usedSprintTemplate": session["usedSprintTemplate"],
                "usedFileReferencesOnly": session["usedFileReferencesOnly"],
                "delegatedScanWork": session["delegatedScanWork"],
                "notes": session.get("notes", ""),
            }
        )
    return sorted(normalized, key=lambda item: item["date"], reverse=True)


def summarize(source: dict, sessions: list[dict]) -> dict:
    baseline = source["baseline"]
    thresholds = source["policyThresholds"]
    tracking_window = source["trackingWindow"]
    tracked = sessions[:tracking_window]
    count = len(tracked)
    baseline_midpoint = (
        baseline["expensiveTokensMin"] + baseline["expensiveTokensMax"]
    ) / 2
    in_target = [
        session
        for session in tracked
        if baseline["targetTokensMin"] <= session["tokens"] <= baseline["targetTokensMax"]
    ]
    avg_tokens = round(sum(session["tokens"] for session in tracked) / count) if count else None
    avg_events = round(sum(session["events"] for session in tracked) / count, 1) if count else None
    avg_ratio = round(sum(session["ratio"] for session in tracked) / count, 1) if count else None
    avg_compactions = (
        round(sum(session["phaseCompactions"] for session in tracked) / count, 1) if count else None
    )
    avg_prompt_kb = (
        round(sum(session["maxPromptKb"] for session in tracked) / count, 1) if count else None
    )
    savings_pct = (
        round(((baseline_midpoint - avg_tokens) / baseline_midpoint) * 100, 1)
        if avg_tokens is not None
        else None
    )

    def adoption_count(key: str, predicate=None) -> str:
        if count == 0:
            return "0/0"
        if predicate is None:
            matches = sum(1 for session in tracked if session[key])
        else:
            matches = sum(1 for session in tracked if predicate(session))
        return f"{matches}/{count}"

    if count == 0:
        status = "No backlog sessions have been recorded yet."
    elif count < tracking_window:
        status = (
            f"Tracking in progress: {count}/{tracking_window} session(s) recorded; "
            f"{len(in_target)} in the target band so far."
        )
    elif len(in_target) == count:
        status = "On track: every tracked session is inside the 35-45M target band."
    else:
        status = (
            f"Off track: {len(in_target)}/{count} tracked session(s) are inside the "
            "35-45M target band."
        )

    return {
        "tracked": tracked,
        "count": count,
        "status": status,
        "remaining": max(0, tracking_window - count),
        "inTarget": f"{len(in_target)}/{count}" if count else "0/0",
        "avgTokens": avg_tokens,
        "avgEvents": avg_events,
        "avgRatio": avg_ratio,
        "avgCompactions": avg_compactions,
        "avgPromptKb": avg_prompt_kb,
        "avgSavingsPct": savings_pct,
        "templateReuse": adoption_count("usedSprintTemplate"),
        "fileRefsOnly": adoption_count("usedFileReferencesOnly"),
        "delegatedScan": adoption_count("delegatedScanWork"),
        "phaseCompaction": adoption_count(
            "phaseCompactions",
            predicate=lambda session: session["phaseCompactions"]
            >= thresholds["phaseCompactionsMin"],
        ),
        "promptBudget": adoption_count(
            "maxPromptKb",
            predicate=lambda session: session["maxPromptKb"] <= thresholds["maxPromptKb"],
        ),
    }


def render_markdown(source_file: Path, source_path: Path, output_path: Path, source: dict) -> str:
    baseline = source["baseline"]
    thresholds = source["policyThresholds"]
    sessions = normalize_sessions(source)
    summary = summarize(source, sessions)
    generated = datetime.fromtimestamp(source_file.stat().st_mtime).astimezone().strftime(
        "%Y-%m-%d %H:%M:%S %z"
    )

    lines = [
        "# Backlog Session Scorecard",
        "",
        "Generated from a repository-tracked measurement ledger so issue #1361 has",
        "operational data instead of an advisory-only target.",
        "",
        f"- Generated: {generated}",
        f"- Source data: `{source_path.as_posix()}`",
        f"- Output: `{output_path.as_posix()}`",
        "- Refresh command: `python scripts/generate-backlog-efficiency-scorecard.py`",
        f"- Tracking window: latest {source['trackingWindow']} recorded backlog sessions",
        (
            f"- Target band: {format_int(baseline['targetTokensMin'])}-"
            f"{format_int(baseline['targetTokensMax'])} tokens"
        ),
        (
            f"- Expensive baseline: {format_int(baseline['expensiveTokensMin'])}-"
            f"{format_int(baseline['expensiveTokensMax'])} tokens"
        ),
        (
            f"- Best measured reference: {format_int(baseline['bestReferenceTokens'])} tokens, "
            f"{baseline['bestReferenceEvents']} events, {baseline['bestReferenceRatio']}x ratio"
        ),
        "",
        "## Scorecard Summary",
        "",
        summary["status"],
        "",
        "| Metric | Value |",
        "|---|---|",
        f"| Sessions recorded | {summary['count']} |",
        f"| Sessions remaining to fill window | {summary['remaining']} |",
        f"| Sessions in 35-45M target band | {summary['inTarget']} |",
        f"| Average tokens | {format_int(summary['avgTokens'])} |",
        f"| Average events | {format_decimal(summary['avgEvents'])} |",
        f"| Average ratio | {format_decimal(summary['avgRatio'], 'x')} |",
        f"| Average savings vs 76M midpoint | {format_decimal(summary['avgSavingsPct'], '%')} |",
        f"| Average phase compactions | {format_decimal(summary['avgCompactions'])} |",
        f"| Average max prompt size | {format_decimal(summary['avgPromptKb'], ' KB')} |",
        "",
        "## Policy Adoption",
        "",
        "| Practice | Threshold | Adoption |",
        "|---|---|---|",
        f"| Phase-boundary compaction | >= {thresholds['phaseCompactionsMin']} compactions | {summary['phaseCompaction']} |",
        f"| Sprint template reuse | `usedSprintTemplate = true` | {summary['templateReuse']} |",
        f"| File-reference-only prompts | `usedFileReferencesOnly = true` | {summary['fileRefsOnly']} |",
        f"| Delegated scan work | `delegatedScanWork = true` | {summary['delegatedScan']} |",
        f"| Max prompt size budget | <= {thresholds['maxPromptKb']} KB | {summary['promptBudget']} |",
        "",
        "## Session Ledger",
        "",
    ]

    if summary["tracked"]:
        lines.extend(
            [
                "| Date | Session | Tokens | Events | Ratio | Compactions | Max Prompt | Template | File Refs | Delegated Scan | Notes |",
                "|---|---|---:|---:|---:|---:|---:|---|---|---|---|",
            ]
        )
        for session in summary["tracked"]:
            lines.append(
                "| "
                + " | ".join(
                    [
                        session["date"],
                        escape_cell(session["label"]),
                        format_int(session["tokens"]),
                        format_int(session["events"]),
                        format_decimal(session["ratio"], "x"),
                        format_int(session["phaseCompactions"]),
                        format_decimal(session["maxPromptKb"], " KB"),
                        format_bool(session["usedSprintTemplate"]),
                        format_bool(session["usedFileReferencesOnly"]),
                        format_bool(session["delegatedScanWork"]),
                        escape_cell(session["notes"] or "-"),
                    ]
                )
                + " |"
            )
    else:
        lines.extend(
            [
                "No backlog sessions have been logged yet. Add entries to",
                f"`{source_path.as_posix()}` after each long run and regenerate this report.",
            ]
        )

    lines.extend(
        [
            "",
            "## Logging Contract",
            "",
            "Record one object per backlog session with these required fields:",
            "",
            "```json",
            "{",
            '  "date": "2026-06-13",',
            '  "label": "Backlog sprint execution",',
            '  "tokens": 41200000,',
            '  "events": 188,',
            '  "ratio": 233,',
            '  "phaseCompactions": 2,',
            '  "maxPromptKb": 6.4,',
            '  "usedSprintTemplate": true,',
            '  "usedFileReferencesOnly": true,',
            '  "delegatedScanWork": true,',
            '  "notes": "Compact at triage->implementation and implementation->merge-waiting."' ,
            "}",
            "```",
            "",
            "Use this scorecard together with `docs/templates/sprint-structure.md` and",
            "`.github/instructions/cost-optimization.instructions.md` to keep the next",
            f"{source['trackingWindow']} backlog sessions inside the 35-45M token target band.",
            "",
        ]
    )

    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true", help="Fail if the scorecard is stale.")
    args = parser.parse_args()

    repo_root = Path(__file__).resolve().parents[1]
    source_path = repo_root / ".github" / "backlog-session-metrics.json"
    output_path = repo_root / "docs" / "reference" / "BACKLOG_SESSION_SCORECARD.md"

    source = load_source(source_path)
    rendered = render_markdown(
        source_path,
        source_path.relative_to(repo_root),
        output_path.relative_to(repo_root),
        source,
    )

    if args.check:
        existing = output_path.read_text(encoding="utf-8") if output_path.exists() else ""
        if existing != rendered:
            print(
                "docs/reference/BACKLOG_SESSION_SCORECARD.md is stale. "
                "Run python scripts/generate-backlog-efficiency-scorecard.py",
                file=sys.stderr,
            )
            return 1
        print("Backlog session scorecard is current.")
        return 0

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(rendered, encoding="utf-8")
    print(f"Wrote {output_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
