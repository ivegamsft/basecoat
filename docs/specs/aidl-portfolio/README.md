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
| #1883 | Sprint 1 planning and scope confirmation | This README |
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
- Sprint 2 implementation evidence: pending.
- Sprint 3 closeout evidence: pending.
