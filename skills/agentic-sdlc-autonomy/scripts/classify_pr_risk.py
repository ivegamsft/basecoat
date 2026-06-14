#!/usr/bin/env python3
"""Classify PR risk for agentic SDLC autonomy.

Input JSON may be either a structured payload:

  {
    "files": [
      {"path": "docs/readme.md", "additions": 5, "deletions": 1, "patch": "..."}
    ],
    "labels": ["agent-authored"],
    "target_environment": "staging"
  }

or a GitHub-style list of files:

  [
    {"filename": "src/auth/login.ts", "additions": 20, "deletions": 5, "patch": "..."}
  ]

Path patterns default to universal high/critical risk rules. Provide a
--config JSON file to override MEDIUM_PATTERNS (and optionally LOW_PATTERNS
and HIGH_PATTERNS) for your repository layout.

Config file format:

  {
    "LOW_PATTERNS": ["docs/**", "**/*.md"],
    "MEDIUM_PATTERNS": ["src/**", "packages/**", "apps/**"],
    "HIGH_PATTERNS": [".github/workflows/**", "iac/**"]
  }

Outputs JSON with risk, autonomy_level, decision, recommended_labels, and reasons.
"""

from __future__ import annotations

import argparse
import fnmatch
import json
import re
import sys
from pathlib import PurePosixPath
from typing import Any, Iterable

# Default patterns — override via --config for repo-specific layouts
_DEFAULT_LOW_PATTERNS: list[str] = [
    "docs/**",
    "**/*.md",
    "**/*.mdx",
    "**/__tests__/**",
    "**/*.test.*",
    "**/*.spec.*",
]

# Default medium patterns are intentionally generic. Override via --config
# with patterns specific to your repo's source layout (e.g. src/**, apps/**).
_DEFAULT_MEDIUM_PATTERNS: list[str] = [
    "src/**",
    "lib/**",
    "packages/**",
    "apps/**",
]

# Default high-risk patterns cover universal sensitive surfaces across repo layouts.
_DEFAULT_HIGH_PATTERNS: list[str] = [
    ".github/workflows/**",
    ".github/actions/**",
    ".github/lane-flow-policy.yml",
    ".github/dependabot.yml",
    "iac/**",
    "infra/**",
    "pulumi/**",
    "terraform/**",
    "bicep/**",
    "cloudformation/**",
    "kubernetes/**",
    "helm/**",
    "charts/**",
    "**/migrations/**",
    "db/**",
    "database/**",
    "**/auth/**",
    "**/security/**",
    "**/permissions/**",
    "**/secrets/**",
    "**/.env*",
    "**/Dockerfile",
    "Dockerfile",
]

HIGH_KEYWORDS: list[str] = [
    r"\bproduction\b",
    r"\bprod-full\b",
    r"\bworkflow_dispatch\b",
    r"\bpermissions:\s*",
    r"\bid-token:\s*write\b",
    r"\bsecrets\.",
    r"\bDATABASE_URL\b",
    r"\baz deployment group create\b",
    r"\bkubectl apply\b",
    r"\bterraform apply\b",
]

CRITICAL_KEYWORDS: list[str] = [
    r"\bDROP\s+TABLE\b",
    r"\bDROP\s+COLUMN\b",
    r"\bTRUNCATE\b",
    r"\bDELETE\s+FROM\b",
    r"\bALTER\s+COLUMN\b",
    r"\bDROP\s+DATABASE\b",
    r"\baz deployment group delete\b",
    r"\baz resource delete\b",
    r"\bkubectl delete\b",
    r"\bterraform destroy\b",
    r"\bfederated credential\b",
    r"\badmin bypass\b",
    r"\brequired_approving_review_count\s*[:=]\s*0\b",
    r"\bcan_admins_bypass\s*[:=]\s*true\b",
]

RISK_ORDER: dict[str, int] = {"low": 0, "medium": 1, "high": 2, "critical": 3}


def _load_config(config_path: str | None) -> tuple[list[str], list[str], list[str]]:
    if not config_path:
        return _DEFAULT_LOW_PATTERNS, _DEFAULT_MEDIUM_PATTERNS, _DEFAULT_HIGH_PATTERNS
    with open(config_path, "r", encoding="utf-8") as fh:
        cfg = json.load(fh)
    low = cfg.get("LOW_PATTERNS", _DEFAULT_LOW_PATTERNS)
    medium = cfg.get("MEDIUM_PATTERNS", _DEFAULT_MEDIUM_PATTERNS)
    high = cfg.get("HIGH_PATTERNS", _DEFAULT_HIGH_PATTERNS)
    return low, medium, high


def normalize_path(path: str) -> str:
    return str(PurePosixPath(path.replace("\\", "/")))


def matches_any(path: str, patterns: Iterable[str]) -> list[str]:
    matched = []
    for pattern in patterns:
        if fnmatch.fnmatch(path, pattern) or fnmatch.fnmatch("/" + path, pattern):
            matched.append(pattern)
    return matched


def regex_hits(text: str, patterns: Iterable[str]) -> list[str]:
    hits = []
    for pattern in patterns:
        if re.search(pattern, text, flags=re.IGNORECASE | re.MULTILINE):
            hits.append(pattern)
    return hits


def extract_files(payload: Any) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    meta: dict[str, Any] = {}
    if isinstance(payload, list):
        return payload, meta
    if isinstance(payload, dict):
        meta = payload
        files = payload.get("files") or payload.get("changed_files") or []
        if not isinstance(files, list):
            raise ValueError("files must be a list")
        return files, meta
    raise ValueError("input must be a JSON object or list")


def classify(
    payload: Any,
    low_patterns: list[str] | None = None,
    medium_patterns: list[str] | None = None,
    high_patterns: list[str] | None = None,
) -> dict[str, Any]:
    low_p = low_patterns or _DEFAULT_LOW_PATTERNS
    med_p = medium_patterns or _DEFAULT_MEDIUM_PATTERNS
    high_p = high_patterns or _DEFAULT_HIGH_PATTERNS

    files, meta = extract_files(payload)
    reasons: list[str] = []
    labels = set(meta.get("labels") or [])
    target_environment = str(meta.get("target_environment") or "").lower()
    total_additions = 0
    total_deletions = 0
    risk = "low"
    lanes: set[str] = set()

    if target_environment in {"production", "prod", "prod-full", "hotfix"}:
        risk = "high"
        reasons.append(f"target environment is {target_environment}")
        lanes.add("lane:deploy")

    for raw_file in files:
        path = normalize_path(
            str(raw_file.get("path") or raw_file.get("filename") or raw_file.get("name") or "")
        )
        additions = int(raw_file.get("additions") or 0)
        deletions = int(raw_file.get("deletions") or 0)
        patch = str(raw_file.get("patch") or raw_file.get("content") or "")
        total_additions += additions
        total_deletions += deletions

        if not path:
            continue

        critical_hits = regex_hits(patch, CRITICAL_KEYWORDS)
        if critical_hits:
            risk = "critical"
            reasons.append(f"critical pattern in {path}: {', '.join(critical_hits[:3])}")

        high_hits = matches_any(path, high_p)
        if high_hits and RISK_ORDER[risk] < RISK_ORDER["high"]:
            risk = "high"
            reasons.append(f"high-risk path {path} matched {high_hits[0]}")

        high_keyword_hits = regex_hits(patch, HIGH_KEYWORDS)
        if high_keyword_hits and RISK_ORDER[risk] < RISK_ORDER["high"]:
            risk = "high"
            reasons.append(f"high-risk keyword in {path}: {', '.join(high_keyword_hits[:3])}")

        low_hits = matches_any(path, low_p)
        medium_hits = matches_any(path, med_p)
        if medium_hits and not low_hits and RISK_ORDER[risk] < RISK_ORDER["medium"]:
            risk = "medium"
            reasons.append(f"runtime/app path {path} matched {medium_hits[0]}")

        if any(token in path for token in ["migrations/", "db/", "database/"]):
            lanes.add("lane:database")
        if matches_any(path, ["iac/**", "infra/**", "terraform/**", "bicep/**", "cloudformation/**"]):
            lanes.add("lane:iac")
        if matches_any(path, [".github/workflows/**", ".github/actions/**"]):
            lanes.add("lane:deploy")
        if matches_any(path, ["**/auth/**", "**/security/**"]):
            lanes.add("lane:security")

    changed_lines = total_additions + total_deletions
    if changed_lines > 600 and RISK_ORDER[risk] < RISK_ORDER["high"]:
        risk = "high"
        reasons.append(f"large PR: {changed_lines} changed lines exceeds 600")
    elif changed_lines > 300 and risk == "low":
        risk = "medium"
        reasons.append(f"large low-risk surface: {changed_lines} changed lines exceeds 300")

    if not reasons:
        reasons.append("no high-risk paths or critical patterns detected")

    if risk == "low":
        autonomy = "A3"
        decision = "auto-merge-eligible"
    elif risk == "medium":
        autonomy = "A4"
        decision = "stronger-checks-required"
    elif risk == "high":
        autonomy = "A5"
        decision = "human-approval-required"
    else:
        autonomy = "A5"
        decision = "plan-only-required"

    recommended_labels = {f"risk:{risk}", decision, *lanes}
    if "agent-authored" in labels:
        recommended_labels.add("agent-authored")

    return {
        "risk": risk,
        "autonomy_level": autonomy,
        "decision": decision,
        "changed_lines": changed_lines,
        "recommended_labels": sorted(recommended_labels),
        "reasons": reasons,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Classify PR risk for agentic SDLC autonomy")
    parser.add_argument("input", nargs="?", help="path to JSON input; defaults to stdin")
    parser.add_argument(
        "--config",
        metavar="FILE",
        help="JSON config file overriding LOW_PATTERNS, MEDIUM_PATTERNS, and/or HIGH_PATTERNS",
    )
    parser.add_argument("--pretty", action="store_true", help="pretty-print JSON output")
    args = parser.parse_args()

    try:
        low_p, med_p, high_p = _load_config(args.config)
        if args.input:
            with open(args.input, "r", encoding="utf-8") as handle:
                payload = json.load(handle)
        else:
            payload = json.load(sys.stdin)
        result = classify(payload, low_patterns=low_p, medium_patterns=med_p, high_patterns=high_p)
    except Exception as exc:  # noqa: BLE001
        print(json.dumps({"error": str(exc)}), file=sys.stderr)
        return 2

    if args.pretty:
        print(json.dumps(result, indent=2, sort_keys=True))
    else:
        print(json.dumps(result, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
