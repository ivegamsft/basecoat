---
issue: 3119
title: "Governance enhancement: explicit human-review gates / autonomy tiers on tracker-bound mutations"
status: draft
author: ibuyspy
created: 2026-09-07
labels: ["enhancement", "governance", "priority:low", "needs-triage", "needs-prd", "synthesize-spec"]
---

# PRD: Governance enhancement: explicit human-review gates / autonomy tiers on tracker-bound mutations

## Problem Statement

**Gap (vs HVE):** HVE `backlog-guardrails` defines a three-tier autonomy model + human-review checkboxes that must be satisfied before any tracker-bound create/update/transition. basecoat has escalation criteria but no per-operation autonomy-tier + review-checkbox contract on backlog mutations.

**Proposal:** Add an autonomy-tier + human-review-gate contract for tracker-bound mutations (issues/PRs/project writes), with a stop-when-unavailable rule.

**Existing partial coverage:** `escalation-criteria`, `high-stakes-workflow` instructions.

Parent: #3113

## Why This Matters

BaseCoat automation already creates and updates issues, pull requests, labels,
comments, and project metadata. Those writes are useful, but tracker state is
also the coordination record for downstream users and autonomous agents. Without
an explicit autonomy tier per operation, agents can treat a low-risk label or
comment update the same as a high-risk close, transition, assignment, or merge
intent update.

A shared autonomy-tier contract makes backlog mutations predictable. It tells
agents which writes can proceed automatically, which writes require a human
acknowledgement, and which writes must stop when the approval signal or reviewer
context is unavailable.

## Scope

In scope:

- Define autonomy tiers for tracker-bound writes to issues, pull requests,
  labels, milestones, assignees, comments, project fields, and status
  transitions.
- Add human-review gate requirements for high-impact writes, including closing
  issues, marking blockers resolved, changing priority/risk labels, altering
  project state, or recording approval-sensitive decisions.
- Require agents and workflows to declare the tier before they mutate tracker
  state and to record the source signal that satisfied any required review gate.
- Add a stop-when-unavailable rule: if the required human signal, project
  context, or permission check cannot be verified, the agent must not perform
  the write and must surface the blocker instead.
- Update authoring guidance and validation fixtures so new tracker-writing
  agents/skills include positive and negative coverage for the gate contract.

Out of scope:

- Replacing GitHub branch protection, CODEOWNERS, rulesets, or required review
  policies.
- Preventing all accidental tracker changes without corresponding platform
  controls.
- Blocking read-only backlog analysis, draft planning, or local notes that do
  not write to the tracker.

## Success Criteria

- [ ] BaseCoat has a documented autonomy-tier model for tracker-bound writes.
- [ ] Tracker-writing agents and workflows can identify whether a proposed
  mutation is automatic, acknowledgement-gated, or human-review-gated.
- [ ] High-impact mutations fail closed when the required review signal or
  tracker context is missing.
- [ ] Tests or fixtures cover at least one allowed low-risk write, one
  human-gated write, and one denied write where the required gate is missing.

## References

- Refs #3119
- Issue: <https://github.com/IBuySpy-Shared/basecoat/issues/3119>
