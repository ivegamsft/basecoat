---
name: bom-validation
description: "Use when validating Workcell BOMs against the plant registry and CAF naming rules before S2 starts. This skill checks completeness, dependency shape, and naming compliance so bad intake never reaches the next station."
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
allowed-tools: ["bash", "git", "grep", "find"]
visibility: "internal"
---
# BOM Validation Skill

Use this skill to validate that a workcell BOM is complete and safe before downstream work begins.

## Workflow

1. Check that all required cells are declared.
2. Confirm resource IDs exist in the plant registry.
3. Reject circular dependencies.
4. Validate CAF naming conventions.
5. Return a short pass/fail summary with the blocker list.

## Non-Goals

- Do not infer missing resources.
- Do not approve a BOM that fails schema or naming checks.
