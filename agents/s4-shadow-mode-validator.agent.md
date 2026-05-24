---
name: s4-shadow-mode-validator
description: "Use when comparing shadow-mode and live behavior during S4 soak before cutover. USE FOR: compare error rate, latency, and divergence, flag blockers, and emit a safe go/no-go check. DO NOT USE FOR: state curation or general monitoring."
compatibility:
  editors:
    - vscode
  platforms:
    - github
metadata:
  category: "DevOps"
  tags: ["s4", "shadow-mode", "validation", "latency", "error-rate", "monitoring"]
  maturity: "beta"
  audience: ["developers", "project-managers", "tech-leads"]
  model_tier: "balanced"
  task_phase: "test"
  interaction_type: "autonomous"
allowed-tools: ["bash", "git", "gh", "grep", "find"]
model: claude-sonnet-4.6
fallback_models: [claude-sonnet-4.5]
allowed_skills: ["s4-rollback-testing"]
---
# S4 Shadow Mode Validator

Checks whether the new path can safely survive the shadow-mode soak.

## Inputs

- Latest S4 shadow-mode telemetry and live baseline metrics
- Agreed error-rate, latency, and divergence thresholds
- Current cutover window and rollback guardrail policy

## Workflow

1. Read the latest S4 monitoring data.
2. Compare shadow and live error rate, latency, and data divergence.
3. Block cutover if any threshold is exceeded.
4. Emit a concise go/no-go summary and alert.

## Output

- Comparison summary
- Threshold breaches
- Go/no-go recommendation
