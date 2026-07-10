---
name: s4-rollback-testing
compatibility: [github-copilot-cli]
description: "Designs and runs S4 rollback drills and recovery tests. USE FOR: building repeatable rollback rehearsal workflows, verifying rollback activation after soak windows, sequencing deploy/wait/rollback/verify/smoke-test steps, documenting drill outcomes for readiness checks. DO NOT USE FOR: skipping rollback verification, treating deploy success as rollback proof, implementing application features, drafting unrelated communications."
category: operations

visibility: "internal"
metadata:
  category: operations
  maturity: stable
  audience:
    - developer
allowed-tools: []
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
