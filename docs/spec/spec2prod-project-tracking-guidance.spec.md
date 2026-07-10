# Technical Specification: Spec2Prod Project Tracking Guidance

## Context

BaseCoat currently has multiple feature-scoped projects and governed ship-it execution workflows. Teams need a consistent project-tracking model that avoids board sprawl while preserving sprint execution visibility and dependency traceability.

This specification defines the canonical tracking guidance and automation behavior for delivery goals executed through the `spec-2-prod` intent contract.

## Scope

1. Define the canonical board topology for delivery tracking.
2. Define when to use feature scope versus sprint scope.
3. Define automated project setup and synchronization behavior.
4. Define dependency-linking requirements across issues and pull requests.
5. Define governance requirements for progression from intake to release.

## Out of Scope

1. Replacing GitHub Issues, Pull Requests, or Projects with external tooling.
2. Autonomous code implementation or merge orchestration.
3. Portfolio forecasting and capacity modeling beyond basic sprint hygiene metrics.

## Architecture Overview

## Tracking model

Use a hybrid model:

1. Scope ownership by feature.
2. Scope flow and release decisions by sprint.
3. Scope intake and prioritization portfolio-wide.

## Canonical boards

1. **Portfolio Intake** (cross-feature):
   - Decision surface for Backlog, Next, Future, and Cut List states.
2. **Sprint Board** (cross-feature, timeboxed):
   - Execution surface for current sprint/release decisions.
3. **Feature Delivery Board** (per approved major feature):
   - Feature-local execution and dependency visualization.

## Automation boundary

Automation provisions and synchronizes structure. Humans retain strategic prioritization decisions.

## `spec-2-prod` intent contract

All board-tracking automation for this feature uses the existing ship-it control-plane contract:

1. `intent`: `spec-2-prod`
2. `goal`: short delivery objective
3. `target_repo`: `owner/repo`
4. `spec_ref`: required for this feature
5. `risk_band`: `low | medium | high | critical`

## Data Model and Storage Changes

No new datastore is required. GitHub Projects and issue/PR metadata remain canonical.

## Required project fields

1. `Status`: Backlog, Next, Future, Cut List, In Progress, In Review, Ready to Ship, Done, Blocked
2. `Scope`: Portfolio, Feature, Sprint
3. `Feature`: canonical feature identifier
4. `Sprint`: sprint identifier or iteration
5. `Priority`: Critical, High, Medium, Low
6. `Risk`: Critical, High, Medium, Low
7. `Dependency State`: None, Blocks, Blocked By, Bidirectional
8. `Evidence State`: Missing, Partial, Complete
9. `Owner`: accountable owner

## Required issue and PR links

1. Spec issue -> control-plane parent issue
2. Control-plane parent issue -> sprint child issues
3. Sprint issues -> implementing pull requests
4. Pull requests -> release evidence references

## API and Interface Contracts

## Board provisioning contract

- Input: repository owner, repository name, feature identifier, spec reference, risk band, owner
- Output:
  1. Portfolio Intake board exists and has required fields/views
  2. Sprint board exists and has required fields/views
  3. Feature board exists only when feature passes provisioning threshold

## Feature-board provisioning threshold

A feature board is auto-created only when all are present:

1. `Owner`
2. `Target sprint` or `target window`
3. `Risk` assignment
4. Dependency map with at least one explicit dependency state

## Sync contract

The ship-it control-plane dispatch flow must:

1. Create one parent issue and three sprint child issues.
2. Apply canonical labels (`spec-2-prod`, `intent-control-plane`, risk label, sprint labels where applicable).
3. Add created artifacts to the configured project board(s).
4. Preserve idempotency on retries.

## Security and Privacy Considerations

1. Restrict project mutation and issue creation permissions to least privilege.
2. Prevent workflow tokens from broad write scopes outside target repositories.
3. Avoid placing sensitive customer or security data in project custom fields.

## Reliability and Failure Modes

1. **Provisioning drift**: fields/views differ from baseline.
   - Mitigation: scheduled drift audit and remediation issue creation.
2. **Partial sync**: parent/child artifacts created but not mapped to projects.
   - Mitigation: explicit sync verification and retry-safe mapping operations.
3. **Template residue**: unresolved placeholder variables in generated issues.
   - Mitigation: required post-generation validation for unresolved template tokens.

## Performance and Capacity Considerations

1. Prefer GitHub-native project rules for simple field and status transitions.
2. Reserve workflow-based automation for cross-board synchronization and validation.
3. Batch board updates to reduce API round-trips and rate-limit pressure.

## Implementation Plan

1. Publish this guidance as the canonical `spec-2-prod` tracking specification.
2. Define board baseline manifests (fields, statuses, required views).
3. Add automation to guarantee Portfolio Intake and Sprint board provisioning.
4. Add conditional feature-board provisioning based on threshold criteria.
5. Enforce dependency-linking and evidence-state checks in ship-it progression.
6. Add drift and quality validation for board configuration and generated artifacts.

## Testing Strategy

1. Unit tests for board provisioning and threshold evaluation logic.
2. Integration tests for issue generation, project mapping, and idempotent retries.
3. Contract tests ensuring spec -> parent -> sprint -> PR links are present.
4. Negative tests for missing required fields and unresolved template variables.

## Rollout, Migration, and Rollback Plan

1. Phase 1: advisory mode with guidance and reporting.
2. Phase 2: auto-provision baseline boards for new feature initiatives.
3. Phase 3: enforce required fields and linking for release progression.
4. Rollback: disable blocking checks and return to advisory reporting mode.

## Observability and Operational Readiness

Track:

1. Time from approved spec to execution-ready tracking artifacts
2. Percentage of features with complete traceability links
3. Percentage of sprint issues with complete evidence state
4. Dependency-blocked item aging
5. Drift count for board field and view baselines

## Risks and Mitigations

1. **Risk**: board sprawl and duplicate workflows.
   - **Mitigation**: fixed baseline of two always-on boards; conditional feature boards only.
2. **Risk**: over-automation reduces team flexibility.
   - **Mitigation**: automate structure, keep prioritization and scope decisions human-owned.
3. **Risk**: inconsistent dependency tracking causes missed sequencing.
   - **Mitigation**: required dependency state field and linkage validation gates.

## Open Questions

1. What inactivity threshold should auto-archive dormant feature boards?
2. Should Feature-board provisioning support exceptions for urgent incident-driven work?
3. Should dependency state drive automatic `Blocked` status transitions by default?

## References

1. `docs/guides/prd-and-spec-guidance.md`
2. `docs/guides/ship-it-control-plane.md`
3. `.github/workflows/ship-it-intent-dispatch.yml`
4. `scripts/ship-it/dispatch-intent.ps1`
5. `docs/spec/aidl-portfolio-management.spec.md`
6. `skills/ship-it/SKILL.md`
