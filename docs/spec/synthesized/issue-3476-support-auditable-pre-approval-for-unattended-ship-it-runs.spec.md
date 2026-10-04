---
issue: 3476
title: "Support auditable pre-approval for unattended ship-it runs"
status: draft
author: ibuyspy
created: 2026-10-04
labels: ["enhancement", "priority:high", "sprint:2026-W40"]
---

# Spec: Support auditable pre-approval for unattended ship-it runs

## Decision and Existing Mechanisms

Design-only; no dispatch, approval, assignment, or runtime changes in this PR.
Reuse the approval already understood by
`.github/workflows/pr-auto-merge-executor.yml`: an issue labeled `approved`
and a trimmed, case-insensitive exact `/approve` comment from a non-bot human
with current write, maintain, or admin permission. Its linked-issue evidence
router already reevaluates comment edits/deletions and approved-label mutations.
Reuse that provenance and revocation behavior rather than introduce another
approval label, database, signed token, or copied approval comment.

`.github/base-coat/workflows/ship-it-intent-dispatch.yml` authorizes comment
commands through collaborator permission. It resolves `source_issue_number`
and `requester`, but does not currently pass them to its dispatch script.
Manual dispatch has no source approval inputs. `scripts/ship-it/dispatch-intent.ps1`
creates/reuses parent and child issues and emits a summary, not a merge approval.
The packaged counterpart under `.github/base-coat/scripts/ship-it/` must remain
consistent through the existing distribution process.
`.github/base-coat/governance/policy-packs.json` separates solo-dev
`approved-issue`, spec evidence, required checks, XXL qualified PR approval,
and production environment approval. These boundaries remain separate.

## Design and Debate

Removing command permission or treating an approval label as sufficient would
let execution grant its own authority. Repeating a human command at each kickoff
prevents legitimate unattended operation. Choose explicit references to live
pre-existing human evidence, with separate authorization for the execution
principal. The run summary is an audit receipt, never an approval store.

This first implementation is same-repository only for pre-approval consumption.
Existing explicitly authorized cross-repository interactive dispatch remains
unchanged; a host approval must not authorize a different target.
The explicit `ship-it`/`spec-2-prod` directive must already be present in the
approved issue scope. A feature/spec approval alone does not request delivery.

## Input and Evidence Contract

Add optional manual-dispatch inputs `source_issue_number` and
`approval_comment_id` and corresponding script parameters. Supplying either
selects pre-approval mode and requires both positive integer IDs; supplying
neither preserves existing interactive behavior. Apply the same resolver for
local unattended dispatch via `skills/ship-it/SKILL.md`.
Do not accept a caller-supplied approver, permission, timestamp, or Boolean
`approved=true` as authority.

For pre-approval mode:

1. Validate the existing target-repository boundary, explicit internal write
   allowlist, active dependency workflows, credential scope, and execution
   principal permission. Pre-approval cannot upgrade the caller's repository
   access. A service principal may execute an authorized run but cannot approve.
2. Fetch the source issue and the specified comment from GitHub in the target
   repository; verify the comment belongs to that non-PR issue. Require the
   `approved` label. Do not search another repository or select a random comment
   from a different issue on failure.
3. Require `^/approve$` after trimming, case-insensitively, using the existing
   exact parser. Reject prose, fenced/quoted commands, arguments, and bot actors
   (`type: Bot` or login ending `[bot]`). Query the comment author's current
   collaborator permission/role and require write, maintain, or admin.
4. Read `created_at` and `updated_at` from GitHub. Effective evidence time is the
   later value; require it strictly before the API-observed initial run start
   (`workflow_runs.created_at` for Actions, GitHub server time captured at local
   run initialization). Equal timestamps fail closed. Reruns reuse the initial
   run's cutoff; evidence added during a run cannot rescue it.
5. Require the approved issue body to describe delivery intent, target repo,
   goal/scope, risk/profile, and spec reference. Validate supplied inputs against
   these fields, not the workflow's defaults or the first arbitrary URL.
   Spec references must resolve to immutable commit-pinned repository content.
   Do not silently follow a moving branch, external URL, or expanded goal.
6. Fetch the issue's body edit time (`lastEditedAt` via GitHub GraphQL, falling
   back to creation time only when the API confirms no body edits). Require
   last body edit <= effective approval time. Any later body edit requires a
   renewed qualified exact approval before a new run. Use body edit time, not
   `updated_at`, which also changes for labels and unrelated activity.
   Unknown edit history or inaccessible spec evidence blocks consumption.

Issue authors may be the human approver; the prohibition is executing automation
approving itself, not a new ban on maintainers approving issue scope.
Do not synthesize `/approve` under a human identity or substitute
`/acknowledge-critical`: that existing command has its own head/time semantics.

## Provenance and State Transitions

Add a receipt to the existing dispatch summary and generated issue provenance:
target/source repository and issue, comment ID/URL, human author, created/updated
times, evidence body hash, initial run ID/start, execution principal, intent,
scope/spec commit, selected policy, and decision/rejection reason.
Hash structured scope and receipt deterministically for comparison and audit,
not as a new source of permission. Preserve requester and approver separately.
Never copy `approved` onto generated issues or copy `/approve` comments.

The state sequence is `requested -> evidence-validated -> executing -> blocked`
or `completed`. A missing/mutated/revoked authority transitions to blocked.
Refetch the same source issue/comment and current permission immediately before
dispatch side effects, before each delivery phase, and before merge/release.
The comment version/body hash and immutable approved scope must match the
initial receipt. A new comment or edited approval requires a new authorized run;
do not silently switch evidence mid-run. API/permission failures block.

For generated PRs, retain the authoritative source issue reference and normal
closing links only when the PR genuinely resolves that issue. A child issue or
parent marker is not transitive approval. Extend eligibility to resolve the
explicit source receipt when normal closing links are insufficient, refetching
it rather than trusting generated metadata. Do not close a multi-phase parent
early just to satisfy the closing-link parser.

Reuse the executor's existing comment/label revocation routing for source-linked
PRs. Extend linkage detection narrowly for validated source receipts; route
removal/deletion even when the actor is now unqualified. On body-scope edits,
publish pending/blocked eligibility for affected PRs too. Loss of permission is
detected on every boundary even without a webhook. Already completed irreversible
actions are reported and reconciled; revocation is not retroactive undeployment.

## Independent Gates and Failure/Security Contract

Pre-approval satisfies only the configured approved-issue signal and the
pre-authorized delivery scope. It is not a PR review, change-size exception,
policy exception, production environment approval, or permission override.
XXL (>2000 lines) still requires the configured qualified current-head human PR
approval; every risk-tier and production boundary remains enforced by its owner.
No admin merge, self-review, cloud assignment, or new approval comment is a
fallback when a gate cannot be satisfied unattended.

Use trusted default-branch resolver/policy code; never run PR-head scripts with
privileged credentials. Pass free text through environment/structured parameters,
not executable interpolation. No credential values belong in receipts/logs.
Fail before side effects on ambiguous scope, malformed IDs, inaccessible API,
missing workflows, unauthorized target, or stale evidence. Dry-run validates
the same evidence but creates no issues/labels/PRs or deployments.
Duplicate dispatch reuses the existing intent marker/idempotency path without
inventing a second parent or re-granting authorization.

## Implementation Plan

1. Extract/reuse the exact approval, bot, permission, and evidence primitives
   from the existing executor in a small shared helper. Keep existing
   acknowledgement semantics unchanged outside explicit pre-approval mode.
2. Extend dispatch workflow inputs/outputs, script parameters, and summary with
   source evidence and requester propagation. Add authoritative scope/spec/time
   validation before side effects; update canonical and packaged surfaces through
   normal sync/package tooling.
3. Extend merge eligibility source linkage and existing revocation routing;
   retain risk/XXL/production policy unchanged. Add pre-phase revalidation to
   ship-it's governed execution guidance, not a new approval service.
4. Extend `tests/ship-it-dispatch-tests.ps1`,
   `tests/ship-it-target-repository-tests.ps1`,
   `tests/pr-auto-merge-executor-tests.ps1`, and
   `tests/ship-it-release-gate-enforcer-tests.ps1` with the fixtures below.
   Document inputs in ship-it guidance and enforced controls only on runtime
   landing; this spec does not assert enforcement exists.

## Acceptance and Exact Boundary Tests

Required future implementation tests, not runtime validation claimed by this PR:

| Case | Evidence/input | Expected |
|---|---|---|
| Valid prior evidence | same repo, human write, approved label, exact comment before start, pinned scope | Start without new human comment |
| Qualified levels | write / maintain / admin | Accept each; role-name fallback matches existing resolver |
| Exact syntax | whitespace + `/APPROVE` | Accept after trimming |
| Non-exact syntax | `/approve now`, quoted/fenced command, prose mention | Deny |
| Label only | approved label, no exact comment | Deny |
| Bot/self-approval | executing bot/app posts exact comment, even with write | Deny |
| Insufficient permission | read/triage/unknown/error | Deny |
| Time boundary | effective time start minus 1ms / equal / plus 1ms | Accept / deny / deny |
| Scope boundary | body edit equal to approval / approval plus 1ms | Accept / deny |
| Edited into approval | created earlier, updated at/after start | Deny |
| Rerun | original cutoff with approval added after initial run | Deny |
| Wrong IDs/repo | comment from another issue, PR, or repository | Deny |
| Scope drift | changed intent, target, spec commit, risk/profile, or goal | Deny; new approval/run |
| Revocation | delete/edit comment or remove label after dispatch | Block next phase and invalidate eligibility |
| Permission revocation | author loses write after dispatch | Block next boundary |
| API failure | truncated evidence, 403/404/timeout | Block; no side effects |
| Generated child | copied label or receipt text without live source authority | Deny |
| Individual PR gates | valid issue evidence, missing CI or risk review | No merge |
| Size boundary | 2000 / 2001 changed lines | XL / XXL; XXL still needs human PR review |
| Production gate | valid issue evidence, missing environment approval | No production cutover |
| Dry-run | valid evidence, dry_run=true | Receipt only; no delivery writes |
| Duplicate | same valid intent marker on repeated dispatch | Reuse parent; no implicit reapproval |

Integration coverage must mutate live/mock GitHub evidence between validation
and the next side effect, proving the receipt alone cannot authorize execution.

## Rollout and Rollback

Enable only when both source IDs are explicitly provided. First compare dry-run
decisions against interactive behavior in same-repository fixtures; then canary
an authorized unattended run with scoped prior evidence and revocation drills.
Observe rejection reason, evidence URL, run ID, and head eligibility status.
No migration of old labels/comments or second approval store is needed.
Existing unpinned/ambiguous scope remains interactive until explicitly prepared.
Rollback disables new consumption/resolution and provenance integration while
retaining all existing exact-approval, revocation, human-review, and environment
checks. Block in-flight pre-approval runs rather than downgrade them to an
unvalidated interactive mode. No merge or deploy is authorized by this design.

## References

- PRD: `docs/prd/synthesized/issue-3476-support-auditable-pre-approval-for-unattended-ship-it-runs.prd.md`
- Governance: `docs/reference/governance-contract.md`
- Refs #3476
- Issue: <https://github.com/IBuySpy-Shared/basecoat/issues/3476>
