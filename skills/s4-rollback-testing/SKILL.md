---
name: s4-rollback-testing
description: "Use when designing or running S4 rollback drills, rollback verification, or recovery smoke tests. This skill makes rollback a practiced S4 habit by sequencing deploy, wait, rollback, verify, and smoke-test steps."
compatibility:
  editors:
    - vscode
  platforms:
    - github
metadata:
  category: "DevOps"
  tags: ["s4", "rollback", "testing", "smoke", "recovery"]
  maturity: "beta"
  audience: ["developers", "project-managers", "tech-leads"]
allowed-tools: ["bash", "git", "grep", "find"]
visibility: "internal"
---
# S4 Rollback Testing Skill

Use this skill to make rollback a practiced, repeatable S4 habit instead of a one-time hope.

## Workflow

1. Deploy to S4 staging.
2. Wait for the soak window.
3. Trigger rollback.
4. Verify the old path is active.
5. Run smoke tests and record the result.

## Non-Goals

- Do not skip the rollback step.
- Do not treat a successful deploy as proof that rollback works.
