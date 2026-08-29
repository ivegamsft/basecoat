---
name: delivery-autopilot
description: "Use when an approved feature or fix should progress to production through governed automation with minimal human intervention. USE FOR: approve-once delivery orchestration, deterministic dry-run rehearsal of status/merge/escalation logic, and policy-aligned remediation payload generation for blocked stages. DO NOT USE FOR: bypassing branch protection or approval boundaries, replacing implementation agents for code changes, or manual one-off deployment operations."
compatibility: [github-copilot-cli, github-actions]
category: workflow
visibility: public
metadata:
  category: workflow
  maturity: alpha
  audience:
    - developer
    - tech-lead
allowed-tools: []
---

# Delivery Autopilot Skill

Use this skill to run approve-once automation loops with deterministic helper scripts and workflow handoff contracts.

## Inputs

1. `repo`: `owner/repo`
2. `issue_number` and/or `pr_number`
3. `required_checks`: list of required check contexts
4. `dry_run`: boolean

## Script Pipeline

1. `scripts/delivery-autopilot/evaluate-status.ps1`
2. `scripts/delivery-autopilot/execute-merge.ps1`
3. `scripts/delivery-autopilot/build-escalation-payload.ps1`

All scripts support deterministic `-DryRun` mode and JSON outputs for workflow handoff.

## Integration Path

These three workflows are optional downstream consumers of this skill's output
files, not preconditions the skill depends on: each is an opt-in `templates`
class entry in `scripts/configure-downstream-workflows.ps1`, not installed by
default. If a workflow below isn't installed, its output JSON file simply goes
unconsumed -- no delivery-autopilot script fails or blocks on its absence.

1. `basecoat-pr-auto-merge-executor.yml` consumes merge-readiness posture.
2. `post-merge-release-chain.yml` consumes merge results to dispatch release gate workflow.
3. `automation-stuck-state-watchdog.yml` consumes escalation payload data when SLA stages stall.

## Output Contract

- `test-results/delivery-autopilot/status-summary.json`
- `test-results/delivery-autopilot/merge-result.json`
- `test-results/delivery-autopilot/escalation-payload.json`
