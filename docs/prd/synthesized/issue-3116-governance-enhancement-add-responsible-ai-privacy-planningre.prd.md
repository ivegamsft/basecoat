---
issue: 3116
title: "Governance enhancement: add Responsible-AI + privacy planning/review agents"
status: draft
author: ibuyspy
created: 2026-09-07
labels: ["enhancement", "governance", "priority:low", "needs-triage", "needs-prd", "synthesize-spec"]
---

# PRD: Governance enhancement: add Responsible-AI + privacy planning/review agents

## Problem Statement

**Gap (vs HVE):** HVE has dedicated RAI and privacy planner/reviewer agents producing plan/review artifacts. basecoat governance is operational and does not produce RAI/privacy artifacts.

**Proposal:** Add optional RAI + privacy planning/review agents (or skills) that emit a plan and a gating review, activated for user-facing or data-handling work.

**Existing partial coverage:** `security` instructions + audit skills (security only, not RAI/privacy).

Parent: #3113

## Why This Matters

BaseCoat has strong operational and security guidance, but user-facing,
data-handling, and AI-assisted workflows also need Responsible AI and privacy
review. Without explicit planning and review artifacts, teams can miss data
minimization, consent, retention, transparency, safety, fairness, or human
oversight concerns until late in implementation.

Optional RAI and privacy planners give downstream teams a lightweight way to
identify those concerns before they ship automation that affects users or
processes sensitive data.

## Scope

In scope:

- Add optional Responsible AI and privacy planning/review agents or skills.
- Trigger the planners for user-facing workflows, personal/sensitive data
  handling, model-assisted decisions, generated recommendations, or automated
  tracker/workflow mutations that affect humans.
- Produce planning artifacts that record intended use, users affected, data
  classes, model or automation role, risks, mitigations, and review owner.
- Produce review artifacts that can gate high-risk implementation PRs until
  required privacy and RAI concerns are addressed or explicitly deferred.
- Reuse existing security and audit guidance where relevant without claiming it
  covers privacy or RAI by itself.

Out of scope:

- Creating legal, regulatory, or compliance attestations.
- Replacing enterprise privacy, legal, security, or Responsible AI review
  processes.
- Blocking low-risk internal documentation work that does not affect users or
  process data.

## Success Criteria

- [ ] BaseCoat has a clear trigger model for when RAI/privacy planning is
  recommended or required.
- [ ] Planning artifacts capture data classes, affected users, intended use,
  automation role, risks, mitigations, and review ownership.
- [ ] Review artifacts can produce allow, revise, block, or defer decisions for
  high-risk work.
- [ ] Tests or evals cover both a low-risk no-review path and a high-risk
  user/data-handling path that requires review.

## References

- Refs #3116
- Issue: <https://github.com/IBuySpy-Shared/basecoat/issues/3116>
