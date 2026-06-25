# AIDL Portfolio Management Architecture and Guardrail Contract

## Objective

Define the canonical architecture, lifecycle controls, and governance contract for portfolio management across BaseCoat and GitHub Projects.

## Lifecycle Layers and Control Points

The lifecycle model standardizes ownership, evidence, and control transitions from intake through learning.

| Layer | Primary objective | Required control points |
|---|---|---|
| Intake | Capture demand with minimum quality metadata | Issue type, ownership, priority, risk |
| Planning | Convert demand into executable sprint or wave scope | Estimation, dependency mapping, acceptance criteria |
| Build | Produce implementation increments | Linked commits, implementation notes, test intent |
| Review | Validate change quality and policy conformance | Required checks, reviewer outcomes, guardrail state |
| Release | Promote only ready changes | Release label gate, changelog linkage, rollback notes |
| Operate | Monitor production outcomes | Incident linkage, SLO signal capture, remediation trigger |
| Maintenance | Manage drift, debt, and carryover | Backlog recategorization, stale-state detection |
| Learning | Convert outcomes into reusable patterns | Retrospective evidence, promotion candidate review |
| Memory | Persist approved patterns and runbook updates | Canonical storage update, reference provenance |
| Governance | Enforce policy contract and exception hygiene | Gate outcomes, waiver lifecycle, audit traceability |

## Responsibility Model

| Concern | BaseCoat | GitHub Project |
|---|---|---|
| Policy and guardrail evaluation | Owns rule interpretation and pass/warn/block/waived outcomes | Consumes guardrail state in workflow fields |
| Work item lifecycle state | Advises target states and controls | Stores authoritative issue and PR progression |
| Audit evidence and remediation | Generates findings and remediation contracts | Hosts linked artifacts, owners, and closure evidence |

## GitHub Project Blueprint

The canonical project baseline for this portfolio feature set includes the following fields.

| Field | Type | Allowed values |
|---|---|---|
| Status | Single select | Backlog, Ready, In Progress, In Review, Release Ready, Done, Blocked |
| Type | Single select | Feature, Bug, Security, Tech Debt, Incident, Maintenance, Docs, Chore |
| Priority | Single select | Critical, High, Medium, Low |
| Iteration | Iteration | Sprint cadence configured per team |
| Area | Single select | Repository domain/component taxonomy |
| Effort | Number | Team estimation unit |
| Risk | Single select | Critical, High, Medium, Low |
| Guardrail State | Single select | Pass, Warn, Block, Waived |
| SRE Impact | Single select | None, Latency, Availability, Error Rate, Capacity |
| Evidence Link | Text | URL to primary validation artifact |
| Waiver Expiry | Date | Required when Guardrail State is Waived |

Recommended project views:

1. Delivery board by Status and Iteration.
2. PR review queue filtered to In Review and Release Ready.
3. Risk and exceptions view filtered to Risk Critical/High and Guardrail Warn/Block/Waived.
4. Reliability view filtered to Type Incident and non-None SRE Impact.
5. Learning queue filtered to completed work with pattern-candidate evidence.

## Guardrail State Contract

| State | Exit criteria | Mandatory metadata | Downstream behavior |
|---|---|---|---|
| Pass | Control satisfied and evidence linked | Evidence Link, owner | Workflow may proceed |
| Warn | Non-blocking drift with remediation path | Evidence Link, remediation owner, due date | Progress allowed with tracking |
| Block | Blocking policy failure | Failure reason, owner, remediation issue | Progress halted until resolved |
| Waived | Approved, time-bound exception | Waiver owner, reason, expiry date, linked approval | Progress allowed until waiver expiry |

## Rules vs Actions Decision Matrix

Use project-native rules when behavior is deterministic and local to one repository/project artifact. Use GitHub Actions when behavior requires cross-entity joins, external systems, or richer branching logic.

| Decision point | Use project rules | Use GitHub Actions |
|---|---|---|
| Auto-add and baseline field mapping | Yes | No |
| Label to status/risk synchronization | Yes | No |
| Required check and gate evaluation | No | Yes |
| Cross-repo rollup or portfolio reporting | No | Yes |
| Incident to backlog route creation | No | Yes |
| Waiver expiry sweeps and escalations | No | Yes |
| Learning promotion candidate extraction | No | Yes |

## Operational Constraints

1. Branch hygiene and cleanup actions run only for merged or explicitly closed PRs.
2. Waived controls require explicit expiry dates and auditable owner approval.
3. Portfolio scoring and audit views must be reproducible from GitHub-native artifacts.
