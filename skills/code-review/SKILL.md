---

name: code-review
description: "Use when reviewing code, pull requests, or diffs for bugs and regressions. USE FOR: review pull request for bugs, inspect diff for regression risk, identify missing test coverage, rank review findings by severity, review refactor for edge cases. DO NOT USE FOR: writing new features, restyling code for preference, making architecture decisions."
compatibility:
  editors:
    - vscode
  platforms:
    - github
metadata:
  category: "Quality & Testing"
  tags: ["uncategorized"]
  maturity: "beta"
  audience: ["developers"]
allowed-tools: ["bash", "git", "grep", "find"]
---

# Code Review

Use this skill when the task is to review code rather than write it.

## Review Priorities

1. Bugs and behavioral regressions
2. Data loss, security, and correctness risks
3. Missing validation or broken edge cases
4. Missing or weak tests for changed behavior
5. Secondary maintainability concerns

## Output Shape

- Findings first, ordered by severity
- File references for each finding
- Open questions or assumptions
- Short summary only after findings

## Non-Goals

- Do not rewrite the code just because there is a different style preference.
- Do not bury real risks under a long summary.

## Related Guardrails

- [Code Review Escalation](../../docs/guardrails/code-review-escalation.md) — When and how to escalate findings to blocking issues vs inline comments
