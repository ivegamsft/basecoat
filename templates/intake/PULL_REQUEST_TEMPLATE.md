# Summary

Describe the change and user impact.

## Validation

List how you validated the change.

## Intake Contract

### RCA

<!-- Root cause or failure mode that justified the change. If not applicable, write N/A and why. -->

### Design

<!-- Proposed design or implementation shape. If not applicable, write N/A and why. -->

Change scope: TBD
Source issues: TBD
Independently deliverable units: TBD
Unit inventory: TBD
Expected files: TBD
Expected changed lines (additions + deletions): TBD
Classification rationale: TBD
Mechanical batch exception evidence: none

<!--
For a proposed mechanical batch exception, replace "none" with "proposed" and
add one JSON code fence with exactly these fields:
command, tool_version, input_revision, file_inventory, smaller_batches_not_viable,
reproduction_diff_evidence, validation_command, validation_result,
rollback_procedure, source_issues, head_sha, base_sha.
file_inventory entries contain path, status, and previous_path (empty for non-renames).
After reviewing the evidence, a qualified human must put this exact standalone
line in their latest APPROVED review on the current head:
Batch exception: <40-character-head-sha> <64-character-evidence-sha256>
-->

### Debate

<!-- Alternatives considered and why this approach won. If not applicable, write N/A and why. -->

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

## Governance

> [!IMPORTANT]
> If this PR touches labels, templates, governance docs, agents, skills, or workflows, include the governance reference and migration notes in the description.
> Governance reference: `.github/base-coat/docs/reference/governance-contract.md`

## Risk and Rollout

- Risk level:
- Rollout plan:
- Rollback plan:
