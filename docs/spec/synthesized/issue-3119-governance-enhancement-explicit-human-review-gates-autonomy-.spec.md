---
issue: 3119
title: "Governance enhancement: explicit human-review gates / autonomy tiers on tracker-bound mutations"
status: draft
author: ibuyspy
created: 2026-09-07
labels: ["enhancement", "governance", "priority:low", "needs-triage", "needs-prd", "synthesize-spec"]
---

# Spec: Governance enhancement: explicit human-review gates / autonomy tiers on tracker-bound mutations

## Problem Statement

**Gap (vs HVE):** HVE `backlog-guardrails` defines a three-tier autonomy model + human-review checkboxes that must be satisfied before any tracker-bound create/update/transition. basecoat has escalation criteria but no per-operation autonomy-tier + review-checkbox contract on backlog mutations.

**Proposal:** Add an autonomy-tier + human-review-gate contract for tracker-bound mutations (issues/PRs/project writes), with a stop-when-unavailable rule.

**Existing partial coverage:** `escalation-criteria`, `high-stakes-workflow` instructions.

Parent: #3113

## Why This Matters

Tracker-bound writes are durable coordination signals. Labels, comments,
project fields, issue state, and pull request state can change what humans or
automation do next. BaseCoat needs one contract that every tracker-writing
agent, workflow, and skill can apply before mutating that shared record.

## Scope

Implement the first wave as a policy and validation layer for tracker-bound
mutations.

1. Define an autonomy-tier model:
   - `read-only`: may inspect and summarize tracker state, but performs no
     writes.
   - `routine-write`: may perform reversible, low-risk writes such as adding a
     generated progress comment or deterministic label when the triggering
     signal is current and attributable.
   - `acknowledgement-gated`: may write only after an explicit maintainer or
     issue-owner acknowledgement is present in the issue, pull request, or run
     input.
   - `human-review-gated`: may not write until a human reviewer has approved
     the specific mutation class or the repository policy explicitly authorizes
     that class.
2. Classify tracker-bound mutation classes:
   - issue or PR comments,
   - label, milestone, assignee, and project-field edits,
   - issue close/reopen and blocker-state transitions,
   - PR ready/draft transitions and merge-intent changes,
   - project item creation, movement, or archival.
3. Require each tracker-writing agent/workflow to declare:
   - mutation class,
   - autonomy tier,
   - required gate,
   - source signal used to satisfy the gate,
   - failure behavior when the gate cannot be verified.
4. Add the stop-when-unavailable rule. Missing permissions, missing reviewer
   context, stale issue/PR state, or ambiguous user intent must result in a
   blocked status or draft recommendation, not a tracker write.
5. Update authoring guidance so agents/skills that write to GitHub or project
   trackers include the tier declaration in their prompt, README, or workflow
   contract.
6. Add validation fixtures for allowed, gated, and denied tracker writes.

## Mutation Gate Matrix

| Mutation class | Default tier | Required gate |
|---|---|---|
| Add deterministic progress/commentary comment | `routine-write` | Current run/issue/PR signal |
| Add deterministic labels from validated policy | `routine-write` | Current policy and matching evidence |
| Remove blocker, risk, or `needs-*` labels | `acknowledgement-gated` | Maintainer acknowledgement or workflow-owned resolution evidence |
| Close or reopen an issue | `human-review-gated` | Human confirmation or explicit workflow policy for that close reason |
| Change priority, severity, risk, or owner | `human-review-gated` | Human owner/reviewer confirmation |
| Move project status to done/blocked/deferred | `human-review-gated` | Human confirmation or checked-in project automation policy |
| Mark PR ready, approve, merge, or alter merge intent | `human-review-gated` | Repository merge policy and required review signal |

The matrix defines defaults. Implementations may require stricter gates for a
specific repository or workflow, but they must not silently downgrade a mutation
to a less restrictive tier.

## Contracts

Tracker-writing tools should emit or document a decision record before the
write:

```text
mutation_class: <comment|label|state|project|merge-intent>
target: <issue-or-pr-url>
autonomy_tier: <read-only|routine-write|acknowledgement-gated|human-review-gated>
gate_required: <none|maintainer-ack|human-review|repo-policy>
gate_source: <comment-url|review-url|workflow-input|policy-path>
decision: <write|block|draft-only>
reason: <short explanation>
```

If `gate_source` cannot be resolved for a gated mutation, `decision` must be
`block` or `draft-only`.

## Failure Handling

- Missing GitHub permission: report the intended mutation and required
  permission; do not retry with a broader token automatically.
- Missing acknowledgement or review: block all tracker writes for gated
  mutation classes, including explanatory comments on the target issue or PR.
  Emit only a non-mutating local summary or draft artifact unless a separate
  routine-write policy explicitly permits a status comment for that exact
  failure mode.
- Stale issue or PR state: refresh state once, then block if the target changed
  in a way that could alter the decision.
- Ambiguous mutation class: use the stricter tier until the policy is clarified.

## Testing and Rollout

Add fixture or script coverage for:

- `routine-write`: deterministic label/comment write is allowed with current
  evidence.
- `acknowledgement-gated`: blocker-label removal is denied without an
  acknowledgement and allowed with one.
- `human-review-gated`: issue close or project done transition is denied
  without human confirmation.
- `stop-when-unavailable`: missing permission or stale target state produces a
  blocked status instead of a write.

Roll out first through documentation, agent/skill authoring guidance, and
workflow validation. Existing workflows can then adopt the matrix one mutation
class at a time.

## Acceptance Criteria

- [ ] Autonomy tiers and mutation classes are documented in a reusable
  tracker-bound mutation contract.
- [ ] Tracker-writing agents/workflows declare mutation class, tier, gate, and
  failure behavior before writing.
- [ ] High-impact writes default to acknowledgement-gated or
  human-review-gated, never routine-write.
- [ ] Stop-when-unavailable behavior fails closed when permission, review,
  acknowledgement, or fresh tracker state cannot be verified.
- [ ] Fixtures or tests cover allowed routine write, missing-gate denial,
  satisfied-gate write, and stale/permission-unavailable denial.
- [ ] The guidance explicitly preserves read-only analysis and draft planning.
- [ ] PR references this spec.

## References

- PRD: `docs/prd/synthesized/issue-3119-governance-enhancement-explicit-human-review-gates-autonomy-.prd.md`
- Refs #3119
- Issue: <https://github.com/IBuySpy-Shared/basecoat/issues/3119>
