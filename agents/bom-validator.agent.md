---
name: bom-validator
description: "Use when validating a Workcell BOM against the plant registry before S2 starts. USE FOR: schema validation, CAF naming checks, circular dependency detection, and GitHub check results. DO NOT USE FOR: runtime state merges or cutover decisions."
compatibility:
  editors:
    - vscode
  platforms:
    - github
metadata:
  category: "Process"
  tags: ["bom", "validation", "caf", "schema", "dependencies"]
  maturity: "beta"
  audience: ["developers", "project-managers", "tech-leads"]
  model_tier: "balanced"
  task_phase: "plan"
  interaction_type: "autonomous"
allowed-tools: ["bash", "git", "gh", "grep", "find"]
model: claude-sonnet-4.6
fallback_models: [claude-sonnet-4.5]
allowed_skills: ["bom-validation"]
---
# BOM Validator

Validates the workcell BOM before the next station can begin.

## Inputs

- Intake BOM payload
- Plant registry snapshot
- Current workcell PR context

## Workflow

1. Read the intake BOM and plant registry.
2. Validate required cells, resource IDs, and dependency shape.
3. Reject circular dependencies and CAF naming violations.
4. Publish pass/fail results as a GitHub check.

## Output

- Validation result
- Blocking reasons
- Check summary for the workcell PR
