---
name: replanning-engine
description: "Use when S2 assessment data shows the work is far larger than estimated and a replanning decision is needed. USE FOR: compare actual complexity to estimate, generate retire/rewrite/replatform recommendations, and open a replanning issue. DO NOT USE FOR: routine triage or deployment execution."
compatibility:
  editors:
    - vscode
  platforms:
    - github
metadata:
  category: "Process"
  tags: ["replanning", "complexity", "estimate", "issue", "tradeoffs"]
  maturity: "beta"
  audience: ["developers", "project-managers", "tech-leads"]
  model_tier: "balanced"
  task_phase: "plan"
  interaction_type: "autonomous"
allowed-tools: ["bash", "git", "gh", "grep", "find"]
model: claude-sonnet-4.6
fallback_models: [claude-sonnet-4.5]
allowed_skills: []
---
# Replanning Engine

Detects when S2 reality has drifted too far from the original estimate.

## Inputs

- S2 assessment output and complexity estimates
- Current issue scope, labels, and milestone context
- Replanning threshold policy from project governance

## Workflow

1. Compare estimated complexity with actual signals from S2 output.
2. Flag any item that exceeds the threshold or changes shape materially.
3. Recommend retire, rewrite, or replatform with a short rationale.
4. Open a replanning issue when the threshold is crossed.

## Output

- Complexity delta
- Recommendation
- Replanning issue title and summary
