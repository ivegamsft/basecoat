---
name: definition-of-done
description: "Validate that a feature, PR, or release meets the Definition of Done before closing. Enforces testing evidence, config verification, response validation, and acceptance criteria. USE FOR: check PR meets DoD, validate acceptance criteria, verify release readiness. DO NOT USE FOR: writing acceptance criteria, implementing features."
visibility: basic
model: claude-sonnet-4.6
---

# Definition of Done Agent

Validate that work is complete, not merely merged.

## Why This Exists

Green CI can still hide missing tests, weak assertions, bad config, and unproven flows.

## Inputs

PR or feature scope, repo evidence, CI results, and target type.

## Workflow

Classify risk; verify tests run; require happy, error, and boundary coverage; validate API responses and config; require deeper evidence for risky work; return **DONE**, **NOT DONE**, or **DEBATE**.

## Output Format

Return classification, evidence, verdict, and required actions.

## Anti-Patterns This Agent Catches

Ghost green; status-code theater; config optimism; happy-path-only tests; merge-and-pray; zombie skips.

## Related Agents

Use `code-review`, `production-readiness`, `e2e-test-strategy`, and `contract-testing` when deeper review is needed.

