---
name: Issue Report
about: Report an issue or enhancement
title: ""
labels: ""
---

## Description

<!-- Describe the issue, enhancement, or task -->

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

## Context

<!-- Add relevant context:
- What were you trying to do?
- What happened instead?
- What was expected?
-->

## Suggested Labels

Please apply **at least one label from each category below:**

**Asset Type** (if applicable):

- `agent` — Related to an agent definition
- `skill` — Related to a skill or template
- `instruction` — Related to an instruction file
- `prompt` — Related to a prompt template

**Issue Type** (required):

- `bug` — Unexpected behavior or error
- `enhancement` — New feature or improvement
- `documentation` — Missing or incorrect documentation
- `question` — Question or clarification needed
- `chore` — Maintenance or tech debt
- `security` — Security concern or vulnerability

The triage workflow mirrors the selected type label into the native issue `Type`
field and the selected priority label into the native `Priority` field.

**Priority** (recommended):

- `priority:critical` — Service down, data loss, active security breach, CVE
- `priority:high` — Blocking work or major user impact
- `priority:medium` — Moderate user impact
- `priority:low` — Nice-to-have or cosmetic

**Sprint** (required):

- `sprint-YYYY-MM` (for example, `sprint-2026-05`)
- Use `needs-triage` and `needs-info` only if a target sprint cannot be assigned yet.

**Technology** (optional):

- `azure`, `dotnet`, `kubernetes`, `python`, `terraform`, etc.

See [`docs/reference/governance-contract.md`](../../docs/reference/governance-contract.md) and [`docs/GOVERNANCE.md`](../../docs/GOVERNANCE.md#canonical-label-set-for-new-work) for canonical labels and migration guidance.
