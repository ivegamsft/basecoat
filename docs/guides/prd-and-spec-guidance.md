# PRD And Spec Guidance

Use this guide when proposing, planning, or implementing non-trivial changes.

## When To Write A PRD

Write a PRD when a change affects user behavior, product scope, cross-team alignment, or prioritization.

Typical triggers:

- New feature or major enhancement
- Behavior change that affects existing workflows
- Cross-team dependency or handoff
- Initiative with measurable business outcomes

## PRD Template

```markdown
# Product Requirements Document: <Feature Name>

## Problem Statement

## Goals

## Non-Goals

## User Personas and Use Cases

## User Experience Summary

## Functional Requirements

## Non-Functional Requirements

## Success Metrics

## Constraints and Assumptions

## Risks and Open Questions

## Dependencies

## Rollout and Adoption Plan

## References
```

## When To Write A Technical Spec

Write a technical spec when implementation choices, interfaces, data contracts, or operational risk need explicit design review.

Typical triggers:

- New service, API, or integration
- Data model or schema changes
- Security, compliance, or reliability-sensitive changes
- Complex migration or staged rollout

## Technical Spec Template

```markdown
# Technical Specification: <Feature Name>

## Context

## Scope

## Out of Scope

## Architecture Overview

## Data Model and Storage Changes

## API and Interface Contracts

## Security and Privacy Considerations

## Reliability and Failure Modes

## Performance and Capacity Considerations

## Implementation Plan

## Testing Strategy

## Rollout, Migration, and Rollback Plan

## Observability and Operational Readiness

## Risks and Mitigations

## Open Questions

## References
```

## Quality Bar

- Requirements are testable and unambiguous
- Assumptions and constraints are explicit
- Success metrics are measurable
- Security, privacy, and reliability concerns are addressed
- Rollout and rollback paths are defined before implementation starts

## PRD-Spec Traceability

Keep these links explicit:

- PRD requirement -> spec section -> test coverage
- PRD success metric -> telemetry or report source
- Spec risk -> mitigation owner and validation step

## Pull Request Gate

This repository includes a PR gate in `.github/workflows/prd-spec-gate.yml`.

Policy:

- **High-change PRs** (`changed_files >= 12` **and** `additions + deletions >= 500`): **Must** include both PRD and spec references to pass the gate. This is a blocking requirement.
- **Risky-path PRs** (`instructions/`, `skills/`, `agents/`, `scripts/`, `.github/workflows/`): Receive an advisory warning if missing PRD or spec references, but this does not block the PR. Aim to include at least one reference when possible.
- **Merge queue events**: Pass automatically because merge queue payloads do not include pull request body metadata.
- **Bot/agent-authored PRs** (`ibuyspy` or GitHub Bot accounts): Bypass the gate because they do not originate PRD/spec artifacts.
- If a reference is not needed, use `N/A` and add a short rationale.
- You can provide references as markdown links or explicit lines:
  - `PRD: <link or N/A + rationale>`
  - `Spec: <link or N/A + rationale>`
- The `skip-prd-spec-check` label bypasses the gate when explicitly approved by repository maintainers.

Recommended practice:

- Keep PRD and spec documents in a predictable location such as `docs/prd/` and `docs/spec/`.
- Link the exact documents in the pull request description.
