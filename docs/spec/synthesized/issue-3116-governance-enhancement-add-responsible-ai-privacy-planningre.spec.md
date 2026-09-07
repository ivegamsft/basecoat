---
issue: 3116
title: "Governance enhancement: add Responsible-AI + privacy planning/review agents"
status: draft
author: ibuyspy
created: 2026-09-07
labels: ["enhancement", "governance", "priority:low", "needs-triage", "needs-prd", "synthesize-spec"]
---

# Spec: Governance enhancement: add Responsible-AI + privacy planning/review agents

## Problem Statement

**Gap (vs HVE):** HVE has dedicated RAI and privacy planner/reviewer agents producing plan/review artifacts. basecoat governance is operational and does not produce RAI/privacy artifacts.

**Proposal:** Add optional RAI + privacy planning/review agents (or skills) that emit a plan and a gating review, activated for user-facing or data-handling work.

**Existing partial coverage:** `security` instructions + audit skills (security only, not RAI/privacy).

Parent: #3113

## Why This Matters

Security review alone does not answer whether an AI-assisted workflow uses data
appropriately, explains its limitations, preserves human oversight, or avoids
harmful automation outcomes. BaseCoat needs optional but explicit RAI and
privacy review surfaces for user-facing and data-handling work.

## Scope

Implement optional Responsible AI and privacy planner/reviewer assets.

1. Add either agents or skills for:
   - RAI planning,
   - privacy planning,
   - RAI/privacy review of an implementation or design artifact.
2. Define activation triggers:
   - user-facing workflow or generated recommendation,
   - personal, sensitive, confidential, or customer data handling,
   - model-assisted decision support,
   - autonomous mutation that affects human work tracking or approvals,
   - telemetry collection, retention, export, or sharing.
3. Define non-trigger examples so routine internal docs, formatting-only
   changes, and read-only repository hygiene do not require heavyweight review.
4. Planning artifacts must include:
   - intended use and user impact,
   - data classes and data flow summary,
   - model/agent/automation role,
   - transparency and user-control expectations,
   - privacy mitigations such as minimization, retention, access control, and
     redaction,
   - RAI mitigations such as human oversight, evaluation, feedback, and
     escalation,
   - review owner and status.
5. Review artifacts must emit one of `allow`, `revise`, `block`, or `defer`
   with findings, severity, owner, and evidence path.
6. Update authoring guidance so high-risk agents/skills link to their
   RAI/privacy plan or explain why the trigger does not apply.

## Artifact Contracts

Planning output:

```text
artifact_type: rai-privacy-plan
target: <issue|pr|design-path>
triggers: <list>
data_classes: <list>
affected_users: <list>
automation_role: <assistive|decision-support|autonomous>
risks: <list>
mitigations: <list>
review_owner: <person-or-role>
status: <draft|ready-for-review|approved|deferred>
```

Review output:

```text
artifact_type: rai-privacy-review
target: <issue|pr|design-path>
decision: <allow|revise|block|defer>
findings: <list>
required_changes: <list>
deferred_risks: <list>
reviewer: <person-or-role>
```

## Failure Handling

- Missing data classification for a triggered workflow: decision must be
  `revise` or `block`.
- Unknown affected-user scope: require clarification before approval.
- Missing mitigation for high-severity privacy or RAI risk: block or defer with
  explicit owner and follow-up issue.
- Claimed non-trigger path: require a short rationale so reviewers can audit why
  RAI/privacy review was skipped.

## Testing and Rollout

Add evals or tests for:

- low-risk internal documentation change returns no-review-needed with
  rationale,
- user-facing recommendation workflow requires RAI planning,
- personal-data workflow requires privacy planning,
- missing data classification blocks review,
- plan with mitigations produces an allow or revise decision with evidence.

Roll out as optional planners first, then add PRD/spec gate integration for
risky paths once the artifact contracts are stable.

## Acceptance Criteria

- [ ] RAI/privacy planning and review assets exist or are specified with clear
  activation triggers.
- [ ] Trigger and non-trigger examples are documented.
- [ ] Planning artifacts capture intended use, data classes, affected users,
  automation role, mitigations, and owner.
- [ ] Review artifacts emit allow/revise/block/defer decisions with findings and
  evidence.
- [ ] High-risk agents/skills are expected to link a plan or document why the
  trigger does not apply.
- [ ] Evals or tests cover low-risk skip, high-risk trigger, missing data
  classification denial, and mitigated approval/revision paths.
- [ ] Validation commands pass with no errors.
- [ ] PR references this spec.

## References

- PRD: `docs/prd/synthesized/issue-3116-governance-enhancement-add-responsible-ai-privacy-planningre.prd.md`
- Refs #3116
- Issue: <https://github.com/IBuySpy-Shared/basecoat/issues/3116>
