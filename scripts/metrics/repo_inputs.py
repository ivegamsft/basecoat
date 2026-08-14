"""Helpers for normalizing repository list inputs used by BaseCoat metrics."""

from __future__ import annotations

import json
import re


def normalize_dashboard_repos(value):
    """Return a list of repository slugs from scalar, JSON, or delimited input."""
    if value is None:
        return []

    if isinstance(value, str):
        text = value.strip()
        if not text:
            return []

        try:
            parsed = json.loads(text)
        except json.JSONDecodeError:
            parsed = None

        if isinstance(parsed, list):
            items = parsed
        elif isinstance(parsed, str):
            items = [parsed]
        else:
            items = re.split(r"[\n,;]+", text)
    elif isinstance(value, list):
        items = value
    else:
        items = [value]

    repos = []
    for item in items:
        repo = str(item).strip()
        if repo:
            repos.append(repo)
    return repos
