---
name: Feature Request
about: Suggest a new feature or enhancement
title: "Enhancement: "
labels: "enhancement"
---

## Description

<!-- Concise summary of the feature request -->

## Intake Contract

### RCA

<!-- Root cause or failure mode that justifies the work. If not applicable, write N/A and why. -->

### Design

<!-- Proposed design or implementation shape. If not applicable, write N/A and why. -->

### Debate

<!-- Alternatives considered and why this approach wins. If not applicable, write N/A and why. -->

### PRD and Spec References

- PRD: <link or N/A with rationale>
- Spec: <link or N/A with rationale>

### Planning Metadata

| Field | Value |
|---|---|
| Target sprint | |
| Priority | |
| Expected change size | small / medium / large |
| Risky-path indicator | yes / no |

## Problem Statement

<!-- What problem does this solve?
- What's the current pain point?
- How does it affect users or workflows?
-->

## Proposed Solution

<!-- How should this feature work?
- What should the user experience be?
- Are there any edge cases to consider?
-->

## Alternative Solutions

<!-- Have you considered other approaches? -->

## Additional Context

<!-- Any other context, mockups, or examples? -->

## Labels

Please ensure the following labels are applied:

**Required:**

- `enhancement` (pre-selected)
- **Issue Type**: `enhancement` (already set)
- **Asset Type** (if applicable): `agent`, `skill`, `instruction`, or `prompt`

The triage workflow mirrors the selected type label into the native issue `Type`
field and the selected priority label into the native `Priority` field.

**Recommended:**

- `priority:critical` if this is a launch blocker
- `priority:high` if high business value
- `priority:medium` if moderate impact
- `priority:low` if nice-to-have
- Sprint label: `sprint-YYYY-MM` (for example, `sprint-2026-05`)
- Use `needs-triage` and `needs-info` only if a sprint cannot be assigned yet.

See [`docs/GOVERNANCE.md`](../../docs/GOVERNANCE.md#canonical-label-set-for-new-work) for canonical labels and migration guidance.
