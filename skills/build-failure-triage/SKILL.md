---
name: build-failure-triage
description: "Use when diagnosing failed builds to quickly isolate fault class and restore delivery flow. USE FOR: identify first failing stage, map log signatures to likely causes, recommend smallest safe fix path, and produce validation checklist for CI and local runs. DO NOT USE FOR: writing new feature code, replacing incident commander workflows, or making unreviewed production changes."
compatibility:
  - GHCP
invocation_rules:
  - "Use when a pipeline or local build is red and root-cause triage is required."
visibility: "internal"
---
# Build Failure Triage Skill

Use this skill to create a repeatable triage flow for broken builds and avoid random fix attempts.

## Reference Files

| File | Purpose |
|---|---|
| [`references/triage-workflow.md`](references/triage-workflow.md) | Failure classification matrix and recovery sequence |

## Agent Pairing

- `broken-build-troubleshooter`
- `self-healing-ci`
- `devops-engineer`
