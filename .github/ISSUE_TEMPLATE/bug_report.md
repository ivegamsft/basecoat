---
name: Bug Report
about: Report a bug or defect
title: "Bug: "
labels: "bug"
---

## Description

<!-- Concise summary of the bug -->

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

## Steps to Reproduce

1. <!-- First step -->
2. <!-- Second step -->
3. <!-- And so on... -->

## Expected Behavior

<!-- What should happen instead? -->

## Actual Behavior

<!-- What actually happened? -->

## Screenshots or Logs

<!-- If applicable, add screenshots or error logs -->

## Environment

- **OS:** [e.g., Windows, macOS, Linux]
- **Node/Python/Version:** [if applicable]
- **BaseCoat Version:** [if applicable]

## Labels

Please ensure the following labels are applied:

**Required:**

- `bug` (pre-selected)
- **Issue Type**: `bug` (already set)
- **Asset Type** (if applicable): `agent`, `skill`, `instruction`, or `prompt`

The triage workflow mirrors the selected type label into the native issue `Type`
field and the selected priority label into the native `Priority` field.

**Recommended:**

- `priority:critical` if service is down or data loss is possible
- `priority:high` if blocking work
- `priority:medium` if affects normal workflow
- `priority:low` if cosmetic or nice-to-have
- Sprint label: `sprint-YYYY-MM` (for example, `sprint-2026-05`)
- Use `needs-triage` and `needs-info` only if a sprint cannot be assigned yet.

See [`docs/GOVERNANCE.md`](../../docs/GOVERNANCE.md#canonical-label-set-for-new-work) for canonical labels and migration guidance.
