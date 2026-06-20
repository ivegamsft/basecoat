# AIDL Portfolio Operator Playbook

This playbook describes day-to-day operation of portfolio management under AIDL framing.

## Operating Model

1. BaseCoat defines guardrails and evaluates policy conformance.
2. GitHub Projects tracks state, ownership, risk, and execution evidence.
3. Operators run with rules-first automation and actions for complex integration.

## Role Responsibilities

| Role | Primary concerns | Core artifacts |
| --- | --- | --- |
| Product/Portfolio | prioritization, roadmap, backlog quality | Roadmap view, Backlog view |
| Engineering | build/review/release flow | Sprint view, PR queue |
| SRE | reliability and incident closure loop | Incident view, Maintenance view |
| Security/Governance | policy and control conformance | Security view, Audit reports |

## Core Daily Workflow

1. Review blocked/high-risk items.
2. Triage new issues and incidents.
3. Validate guardrail state transitions.
4. Ensure PRs are linked to tracked work.
5. Route incidents to remediation work when needed.

## Sprint Ceremonies

## Planning

- [ ] Confirm backlog hygiene and priorities
- [ ] Confirm sprint capacity and commitment
- [ ] Confirm high-risk controls are represented in sprint scope

## Mid-sprint checks

- [ ] Review flow bottlenecks
- [ ] Review incident-to-backlog latency
- [ ] Review waiver usage and expiry risk

## Closeout

- [ ] Verify done criteria and release readiness
- [ ] Verify unresolved spillover and carry-forward owners
- [ ] Capture learning candidates and memory promotions

## Rules vs Actions Policy

Use Project Rules for:

1. Auto-add and basic routing
2. Label-to-field mapping
3. Common status transitions

Use Actions for:

1. Cross-repo aggregation
2. External monitoring and incident ingestion
3. Memory promotion pipelines
4. Complex conditional workflows

## Required Project Baseline

## Required fields

`Status`, `Type`, `Priority`, `Iteration`, `Area`, `Effort`, `Risk`, `Guardrail State`, `SRE Impact`, `Runbook Link`, `Learning Capture`

## Required views

1. Sprint Delivery
2. Backlog
3. PR and Review Queue
4. Security and High Risk
5. Incidents and Reliability
6. Maintenance and Audit
7. Learning and Memory
8. Roadmap

## Incident-to-Backlog Routing

When an incident is opened:

1. Create or link remediation issue.
2. Set `Type` and `Priority` by severity policy.
3. Set `Risk`, `SRE Impact`, and `Guardrail State`.
4. Link runbook and verification criteria.
5. Track closure and recurrence.

## Learning and Memory Workflow

1. Mark candidate with `Learning Capture=Candidate`.
2. At closeout, review candidate quality and recurrence.
3. Promote accepted candidates to memory artifacts.
4. Track adoption impact and adjust guidance.

## Escalation Triggers

1. `Guardrail State=Block` on release-critical item.
2. High-severity incident without remediation owner.
3. Expired waiver still in active use.
4. Conformance score in red state.

## References

1. `docs/spec/aidl-portfolio-management.spec.md`
2. `docs/operations/aidl-portfolio-audit-suite.md`
3. `docs/operations/branch-protection-enforcement.md`
4. `docs/operations/merge-queue-enforcement.md`
