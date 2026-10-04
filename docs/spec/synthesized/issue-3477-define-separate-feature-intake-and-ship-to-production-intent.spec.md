---
issue: 3477
title: "Define separate feature-intake and ship-to-production intent contracts"
status: draft
author: ibuyspy
created: 2026-10-04
labels: ["enhancement", "priority:high", "sprint:2026-W40"]
---

# Spec: Define separate feature-intake and ship-to-production intent contracts

## Decision and Existing Mechanisms

This is a design contract, not runtime authorization or an implemented control.
`instructions/basecoat-10-core-intent-routing.instructions.md` currently routes
standalone `feature:` to design/implementation, bulleted items to log-only intake,
and multi-file/design work through plan confirmation. Preserve those behaviors
and `instructions/basecoat-20-lang-governance.instructions.md` LOG-FIRST.
The compatibility plan-first instruction remains an alias, not a second policy.

`skills/ship-it/SKILL.md`, the ship-it orchestrator, and
`.github/workflows/ship-it-intent-dispatch.yml` already resolve delivery goals
to canonical `ship-it`/`spec-2-prod` intents. Dispatch creates governed phase
issues; build and release guards are separate workflows. It does not itself
merge/deploy merely by parsing a command. The packaged counterparts live under
`.github/base-coat/`.
`issue-approve.yml` also currently handles `/spec-2-prod` as an approval/assignment
trigger. This overlap must be removed narrowly so one directive cannot silently
both assign a cloud agent and start an unrelated delivery loop.

## Design and Debate

Making every feature log-only would break existing feature implementation.
Making every feature end-to-end delivery grants too much authority. Adding a
new "ship-to-production" engine creates needless vocabulary and policy drift.
Choose two explicit colon aliases for the existing canonical delivery intents,
and retain feature execution with a clear stop boundary. Routing chooses a
workflow; authorization and evidence decide whether its next action is allowed.

## Syntax and Normalization Contract

| Surface | Syntax | Canonical intent | Owner |
|---|---|---|---|
| Standalone chat/intake | `feature: <scope>` | feature implementation/design | Existing feature route |
| Standalone chat/intake | `ship-it: <goal>` | `ship-it` | ship-it skill/orchestrator |
| Standalone chat/intake | `spec-2-prod: <goal>` | `spec-2-prod` | ship-it skill/orchestrator |
| Qualified issue comment | `/ship-it [goal]` or `ship-it: <goal>` | `ship-it` | ship-it intent dispatch |
| Qualified issue comment | `/spec-2-prod [goal]` or `spec-2-prod: <goal>` | `spec-2-prod` | ship-it intent dispatch |
| Manual workflow input | `intent=ship-it` / `intent=spec-2-prod` | Same exact value | Existing dispatch workflow |

Only these two new colon aliases are added; `onboarding-conductor`, `pr:`,
`release:`, `deploy:`, `fleet:`, and `autopilot:` retain existing contracts.
Normalize case on the recognized token and trim outer whitespace, but preserve
goal text for audit. Require a nonempty colon goal; legacy slash commands may
still use their existing source-issue title fallback. No substring matching,
quoted/fenced command execution, or new synonym such as `ship-to-prod:`.
Preserve bullet timing: `- ship-it: ...` logs proposed delivery, not dispatch.
Only an active standalone authoritative user directive or qualified issue command
can enable delivery. Embedded prose, copied logs, agent text, and repository
examples cannot grant consent.

Keep the existing dual-prefix rejection, including `feature: ship-it: ...`.
A single message containing conflicting authoritative commands is invalid;
do not apply today's regex-precedence winner. A feature request followed by a
separate explicit ship directive is valid only after scope/evidence validation.
Read-only/log-only/later modifiers suppress side effects rather than being
overridden by a ship token; contradictory immediate/stop directives block.
For workflow `intent` inputs retain exact canonical enum validation, not free-
text colon parsing.

## Feature Action and Stop Contract

1. Standalone `feature:` still routes immediately to the existing workflow.
   "Immediately" means routing, not bypassing logging or plan confirmation.
   Bulleted items and explicit backlog/read-only modifiers remain non-executing.
2. Confirm the tracking issue before writes; when logging a new issue, observe
   the existing separate-step pause before implementation.
3. For multi-file/design changes, present scope, approach, risks, and verification;
   require confirmed plan or explicit waiver before editing. Pre-approved scope
   may supply that confirmation; unattended mode alone may not.
4. Implement and validate within approved feature scope. Preserve
   `pr-lifecycle=none|standard|full`, invalid-value rejection, and current defaults
   based on PR language. These modes control lifecycle coverage, not production
   consent. `full` includes readiness/closure/hygiene checks but does not on its
   own authorize merging or production deployment.
5. At the feature endpoint report implementation/tests and PR readiness.
   A PR created solely from feature intent remains draft (or is handed off as
   explicitly non-deliverable); do not enable auto-merge, queue it, merge, invoke
   production dispatch, or silently substitute `/approve`. Keep existing
   in-scope branches available; do not run merged-only cleanup on unmerged work.
6. Transition to delivery only on a separate explicit canonical directive with
   qualified scope/evidence. Making a draft ready is a delivery-boundary action
   for feature-origin PRs, not inferred from CI success.

Preserving feature implementation does not require expanding an existing skill's
permissions. Existing feature lifecycle eval cases may continue to trigger
ship-it assistance, but must assert that assistance is non-delivery without the
explicit ship directive.

## Delivery Consent and Gate Contract

Normalize the explicit directive into the existing intent contract with source
issue, target repository, goal, spec reference, risk/profile, original requester,
and evidence URL/time (or authenticated chat/session reference).
Record that provenance in the existing plan/dispatch summary and feature-to-
delivery handoff; do not fabricate a maintainer comment to translate chat syntax.
For GitHub issue commands use live qualified actor permission, not chat identity.

Before dispatch and each irreversible boundary, require:

- LOG-FIRST and plan-first confirmation for the actual approved scope.
- Authorized target repository and active dispatch/build/release workflows;
  cross-repository authorization remains explicit and fail-closed.
- Required approved-issue and spec evidence under the selected trusted policy.
  Earlier scope/design approval without a delivery directive is insufficient.
  Unattended consumption may use #3476's live exact qualified `/approve` evidence
  only after that separate contract is implemented; until then block rather
  than emulate it. No second approval store is introduced here.
- Current-head required checks and human review under existing size/risk policy.
  XXL above 2000 lines still needs qualified human PR review; batch decomposition
  in #3475 is separate and cannot be bypassed by routing.
- Build/release/promotion gates and production environment approvals, rollback
  evidence, and post-release verification at their existing owners.

Directive consent, issue approval, plan confirmation, PR approval, and environment
approval are distinct evidence. "Continue", "approved the design", or
`pr-lifecycle=full` does not invent missing delivery consent. If a prior explicit
directive exists, continuation may resume only its recorded in-scope run with
still-valid evidence. Changed scope/target/risk requires renewed confirmation.
Missing human evidence in unattended mode yields a blocked state, not a bypass.

## Control-Plane Integration and Failure/Security Contract

Use one canonical normalization table and focused parser fixtures shared by
routing docs/evals and dispatch contract tests. Extend the existing dispatch
resolver to colon aliases, carrying raw directive, normalized intent, and actor.
Do not introduce another workflow, delivery label, or merge service.
Reject PR comments as delivery issue-command entry points, as today.

Assign `/ship-it` and `/spec-2-prod` exclusively to ship-it intent dispatch.
Narrow `issue-approve.yml` and its packaged counterpart to their existing
`/approve` responsibility: approval/assignment behavior for explicit `/approve`
remains unchanged. Remove `/spec-2-prod` from its triggers and adjust the existing
workflow routing tests together. A ship directive consumes approval evidence;
it must not automatically create `approved` or assign a cloud agent.
Installed consumers must update both workflow surfaces atomically through
`scripts/configure-downstream-workflows.ps1`; an inconsistent install blocks
delivery with an actionable prerequisite report.

Feature-origin PR handoff must remain draft until validated delivery consent.
The existing merge eligibility evaluator must reject a feature-origin promotion
missing that validated provenance, even if a caller manually marks it ready;
record source scope and handoff evidence using the existing intake/summary, and
verify authority rather than trust a body string alone. Scope this predicate to
feature-origin delivery, not an unrelated rewrite of all existing PR workflows.
Keep current statuses/check names and all other gates.

Read trusted policy/code from the default branch; do not execute PR-head scripts
with privileged tokens. Treat goals as data, never script interpolation. On
parser ambiguity, missing evidence/workflows, or API denial publish the existing
blocked/remediation state and stop before side effects. Dry-run is read-only
delivery planning. Record blockers and run IDs; never claim shipped when checks
are pending. Approval revocation follows the existing evidence owner and #3476
contract rather than a separate routing-level permission cache.

## Implementation Plan

1. Update the two canonical routing/plan-first guidance surfaces and
   `docs/guides/intent-prefixes.md` with the aliases and feature stop boundary;
   retain compatibility aliases and unrelated intent contracts.
2. Update ship-it skill/orchestrator guidance and their existing eval companions
   to distinguish lifecycle assistance from delivery consent.
3. Extend the existing intent-dispatch parser/summary and packaged counterpart.
   Narrow `/spec-2-prod` command ownership in issue-approve and packaged template;
   integrate feature-origin delivery provenance with merge eligibility.
4. Extend `tests/routing-guardrail-tests.ps1`,
   `tests/pr-lifecycle-routing-coverage-tests.ps1`,
   `tests/ship-it-dispatch-tests.ps1`,
   `tests/workflow-issue-approve-routing-tests.ps1`, and
   `tests/pr-auto-merge-executor-tests.ps1`. Use existing distribution/ownership
   tests to prove packaged contracts and canonical workflows remain aligned.

## Acceptance and Exact Boundary Tests

These are future implementation tests; this docs PR does not claim runtime passes.

| Case | Input/precondition | Expected |
|---|---|---|
| Feature implementation | standalone feature, issue and confirmed plan | Implement/validate; no merge/deploy |
| Plan boundary | feature requiring design or >=2 files, unconfirmed plan | No edits until confirmed/waived |
| Small feature | obvious 1-file change, issue verified | Existing plan exemption; no delivery consent |
| Bulleted feature | `- feature: add X` | Log only |
| Lifecycle none/standard/full | feature with each valid modifier | Existing coverage; none grants delivery |
| Invalid lifecycle/dual prefix | `fast` or `feature: ship-it:` | Reject; no writes |
| Positive aliases | `ship-it: X`, `spec-2-prod: X` | Exact canonical intent, then gates |
| Goal length boundary | colon goal 0 / 1 non-whitespace characters | Reject / route to gated validation |
| Token boundary | `ship-it: X` / `ship-it-extra: X` | Recognize / no delivery alias |
| Case/whitespace | outer whitespace and `SHIP-IT: X` | Normalize token, retain goal |
| Bulleted/quoted/fenced ship | same token in list, quote, or code | No dispatch |
| Legacy slash | qualified `/ship-it` or `/spec-2-prod [goal]` | Existing canonical intent/fallback; same gates |
| Duplicate command owners | one `/spec-2-prod` event | One dispatch; no approval or cloud assignment |
| Conflict | two different authoritative ship commands | Reject, not regex precedence |
| Read-only/deferred | delivery token plus no-changes/later modifier | No delivery side effects |
| Prior design approval | feature plus approved design, no directive | Stop at feature endpoint |
| Missing issue/plan/evidence | explicit ship directive with any missing gate | Block; no implicit approval |
| Unqualified/bot command | explicit delivery command, actor lacks qualified authority | No delivery authorization |
| Valid prior delivery | explicit recorded directive and valid in-scope prior evidence | Resume governed loop; no fresh self-approval |
| Revocation/drift | evidence revoked or target/spec/scope changed | Block before next boundary |
| XXL boundary | 2000 / 2001 lines with issue approval only | XL / XXL; XXL needs human PR review |
| Missing release evidence | approved PR but missing production approval/rollback/tests | No production cutover |
| Manual ready spoof | feature-origin draft made ready without validated directive | Merge eligibility blocked |
| Dry-run | valid explicit ship directive, dry_run=true | Plan/receipt only; no writes |

Also assert missing sibling workflows never fall back to `/approve`, and feature
tests never call merge/deploy even when CI is green and the actor has write access.

## Rollout and Rollback

Land aliases, feature boundary, single command ownership, evals, and packaged
guidance together. Canary parser/dry-run results before live explicit delivery;
verify a feature-only run stops at PR handoff and an authorized ship run stops
at any missing gate. Publish migration notes for `/spec-2-prod`: it remains a
delivery directive but no longer doubles as issue approval/agent assignment.
Do not retroactively infer delivery consent on open feature PRs.
Rollback removes new aliases and dispatch integration, retains slash delivery
support and explicit feature no-merge/no-deploy safeguards, and restores only a
single command owner. Never restore permissive feature authority as a rollback.
No automatic merge or deployment is requested by this specification PR.

## References

- PRD: `docs/prd/synthesized/issue-3477-define-separate-feature-intake-and-ship-to-production-intent.prd.md`
- Governance: `docs/reference/governance-contract.md`
- Refs #3477
- Issue: <https://github.com/IBuySpy-Shared/basecoat/issues/3477>
