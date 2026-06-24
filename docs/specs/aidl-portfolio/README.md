# AIDL Portfolio Management and Audit Specs

## Purpose

This directory contains the canonical Sprint 40 specification set for AIDL portfolio management, PR lifecycle policy, and portfolio audit governance.

## Scope Confirmation

The Sprint 40 execution backlog is covered by the following specification work items.

| Issue | Scope | Planned deliverable |
|---|---|---|
| #1742 | Canonical portfolio management architecture and guardrail contract | `management-architecture.md` |
| #1756 | Full PR lifecycle execution policy contract | `../pr-lifecycle-policy.md` |
| #1757 | Feature intent modifier parsing for `pr-lifecycle=<none\|standard\|full>` | `../pr-lifecycle-policy.md` and intent-routing instruction update |
| #1749 | Audit suite framework, cadence, and scoring rubric | `audit-framework.md` |
| #1750 | Governance policy enforcement and exception hygiene | `audit-governance.md` |
| #1751 | Reliability and SRE feedback-loop audit quality | `audit-reliability.md` |
| #1752 | Learning and memory pattern promotion quality | `audit-learning-memory.md` |
| #1753 | Delivery-flow economics baseline, waste-driver mapping, and sprint trend tracking | `../../reference/aidl-delivery-flow-economics-baseline.md`, `../../reference/aidl-delivery-flow-economics-optimization-backlog.md`, `../../templates/aidl-delivery-flow-economics-before-after-metrics-template.md` |
| #1883 | Sprint 1 planning and scope confirmation | This README |
| #1992 | Sprint 1 planning/scoping for governance backlog carry-forward | `sprint-1992-scope-plan.md` |
| #1884 | Sprint 2 implementation closeout evidence | README update in Sprint 2 close PR |
| #1885 | Sprint 3 closeout evidence | README update in Sprint 3 close PR |
| #1759 | Feature tracker for portfolio management and governance | Tracker close after Sprint 3 merge |
| #1774 | Feature tracker for architecture and reliability audit | Tracker close after Sprint 3 merge |

## Sprint Sequence

1. Sprint 1 establishes scope and deliverable boundaries.
2. Sprint 2 delivers management architecture and PR lifecycle policy behavior.
3. Sprint 3 delivers audit specifications and closes the execution loop.

## Guardrail and Governance States

Guardrail semantics across these specs use a shared contract.

| State | Meaning | Required operator action |
|---|---|---|
| Pass | Control is satisfied with sufficient evidence | Continue workflow |
| Warn | Non-blocking control drift or incomplete evidence | Remediate in-sprint and track |
| Block | Control failure with release or merge risk | Stop progression until resolved |
| Waived | Time-bound exception approved by owner | Record waiver, reason, owner, and expiry |

## Current Evidence Status

- Sprint 1 scope: completed by this README.
- Sprint 1 scope refresh for #1992: captured in `sprint-1992-scope-plan.md`.
- Sprint 2 implementation evidence: completed.
- Sprint 3 closeout evidence: completed.

## Sprint 2 Evidence

| Item | Evidence |
|---|---|
| Portfolio management architecture spec (#1742) | PR #1963 (`management-architecture.md`) |
| PR lifecycle policy and parsing contract (#1756, #1757) | PR #1969 (`pr-lifecycle-policy.md` and intent-routing update) |
| Sprint 2 closeout issue | #1884 |

## Sprint 3 Evidence

| Item | Evidence |
|---|---|
| Audit framework spec (#1749) | PR #1974 (`audit-framework.md`) |
| Governance audit spec (#1750) | PR #1974 (`audit-governance.md`) |
| Reliability audit spec (#1751) | PR #1974 (`audit-reliability.md`) |
| Learning and memory audit spec (#1752) | PR #1974 (`audit-learning-memory.md`) |
| Sprint 3 closeout issue | #1885 |

## Sprint 40 Completion

Sprint 40 portfolio feature execution is complete for sprints 1 through 3, with implementation artifacts merged and tracker closeout queued.
