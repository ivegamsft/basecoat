---
name: bom-validation
compatibility: [github-copilot-cli]
description: "Validates Workcell BOMs against plant registry and CAF naming rules. USE FOR: validating BOM completeness before S2, detecting circular dependencies, enforcing CAF naming compliance, checking registry references before handoff. DO NOT USE FOR: approving incomplete BOMs, inferring missing resources, writing application code, running release/deployment tasks."

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


