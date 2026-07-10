---
name: ci-cd-diagnostics
description: "Use when producing a raw CI/CD diagnostics snapshot with measured repository metrics only. USE FOR: collect PR lifecycle timing, queue/requeue stats, conflict counts, sprint merge-distribution buckets, and backlog deltas with source commands. DO NOT USE FOR: remediation plans, policy recommendations, workflow rewrites, or speculative estimates."
compatibility: [github-copilot-cli]
category: operations
visibility: public
metadata:
  category: operations
  maturity: stable
  audience:
    - developer
allowed-tools: []
---

# CI/CD Diagnostics Skill

Use this skill to generate a data-only diagnostics report for release engineering.

## When to Use

- Inventory current pipeline behavior with measurable numbers.
- Produce a single metric table with command-backed evidence.
- Explicitly mark missing data as blocked with the exact reason.

## Workflow

1. Collect system-shape, PR lifecycle, queue, conflict, sprint, and backlog metrics.
2. Prefer direct `gh`/API evidence and deterministic calculations.
3. If a metric cannot be retrieved, emit `BLOCKED: <reason>` with the failed command or missing source.
4. Return one table only: `Metric | Value | Source/command used`.
5. Do not include recommendations, root-cause analysis, or fixes.

## Output Contract

- Exactly one filled table with all required metrics.
- No narrative analysis.
- No guessed values.

## References

- [`references/spec.md`](references/spec.md)
- [`references/design-debate.md`](references/design-debate.md)
- [`references/collector-contract.md`](references/collector-contract.md)
