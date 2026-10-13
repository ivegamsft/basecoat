# Dependent Stack Validation and Handoff Proposal

## Status and prerequisites

Proposal only, related to [source #3670](https://github.com/IBuySpy-Shared/basecoat/issues/3670).
This document does not implement a stack, approve a source, or select production rules.
Merging a proposal is not runtime acceptance or authority to merge any layer.
No new command or label alias is supported.

The prerequisite readiness identity is proposed in
[completion readiness proposal #3718](https://github.com/IBuySpy-Shared/basecoat/pull/3718)
for source #3669; publication is not proof that its runtime exists.
[Stack integration](../guides/stacked-pr-integration.md),
[hybrid branching](../operations/hybrid-branching-policy-contract.md), and
[governance](../reference/governance-contract.md) define the existing policy.

## Current versus future behavior

Inspected repository baseline: `b2cb3c03003dc40f0eb4a67c32dfa69a2e4aae11`.
Existing guidance calls for protected dependent layers and one `feature/* -> main`
finalization, not stacks of independent chores. `pr-auto-merge-executor.yml`
targets main and does not provide a non-main layer merge executor.
Its current-head/decomposition helpers are useful evidence, not layer protection.
The source's audit of 13 main-targeting PRs is historical, not a current stack inventory.

Future behavior must prove branch ancestry, protect integration layers, and revalidate
each rewritten descendant before bottom-up advancement. Native main queue setup alone
does not supply these mechanisms. No live stack or exact-tree acceptance is claimed.

## Non-goals, owners, and authority

No independent work artificially stacked for order; no label graph treated as Git ancestry;
no direct unprotected merge, admin bypass, release routing, assignment or automatic approval.
Keep solo-dev zero routine human reviews through XL and explicit qualified XXL boundary.
Do not interpret the hybrid table's "auto-merge when green" as bypass permission.

The existing feature/lane owner records the approved dependency decomposition;
workflow maintainers own protection/validation; `ship-it-control-loop` and `lane-closeout`
retain bounded orchestration and cleanup ownership. Approval/decomposition helpers remain
canonical. Only separately authorized protected integration operations may advance layers.

## Requirements traceability

| Source requirement | Proposed evidence / behavior |
|---|---|
| Actual dependency chain | Explicit stack record plus observed Git ancestry |
| Protected layers | Effective protection and exact-tree checks before each advancement |
| Bottom-up and squash-aware | Mapping original parent commits to protected integrated result |
| Retarget and revalidate | New descendant head/base invalidates all former validation |
| One main finalization | Aggregate scope/decomposition and protected native queue |
| Edits, close, conflict, duplicate | Bounded reconciliation and fixture effects below |

## Identity and durable output

Stack input: repository ID, stack ID/revision, integration `feature/*` ref and tip,
approved source/spec/task identities, ordered layer PR IDs, each head repository/ref/SHA
and immediate base ref/SHA, dependency edges, policy revision, effective protections,
and required check/producer evidence.
Each child must demonstrably include the approved parent's actual head as its ancestor
at creation or have a recorded approved post-squash reconstruction. A matching label,
issue edge, branch name, or PR base string is insufficient.

Output: stack revision, observed ancestry graph, layer disposition, exact before/after
head/base pairs, protection evidence, original-to-integrated commit mapping,
validation references, owner, failure reason and resume cursor. Record values are not labels.
An integration manifest binds final tree, included tasks/layers and exclusion reasons.
Missing provenance blocks; do not infer success from a closed-but-unmerged parent.

## Proposed bottom-up state transitions

1. Discover only declared dependencies. Compare actual refs and ancestry to the
   approved layer scope; independent items remain separate. Reject cycles, foreign
   heads without trusted provenance, missing parents and unauthorized branch classes.
2. Verify each layer destination has effective protected checks and intended authority.
   Missing feature protection is a prerequisite failure, not permission to merge.
   Keep PR checks scoped to its immediate parent and final checks scoped to main.
3. Advance only the lowest incomplete layer into its protected destination after
   current readiness, decomposition, scope and exact-tree validation pass.
   Finalization cannot run while any included layer is incomplete or unresolved.
4. On parent edit, invalidate descendants transitively. On protected parent merge,
   persist the actual integrated commit/tree and original ancestry boundary.
   For squash, do not assume the old parent SHA is an ancestor of the squash commit.
5. Reconstruct a child's unique delta onto the new protected parent tip using the
   recorded old boundary; compare scope/tree and retain provenance. If Git cannot
   identify that delta without ambiguity, stop for lane-owner reconciliation.
   Authorized synchronization must not force-reset shared refs or overwrite author work.
6. Retarget to the surviving protected parent/integration ref, then obtain fresh head/base
   validation. Old green results cannot authorize rewritten ancestry.
   Repeat bottom-up until the integration manifest is complete.
7. Open one `feature/* -> main` finalization PR. Re-evaluate aggregate decomposition,
   approval and policy boundaries; layer size labels cannot evade an aggregate XXL boundary.
   Admit only through protected main eligibility and native exact-tree queue checks.
   Delete branches/worktrees only after verified finalization and mapping checks.

## Concurrency, idempotency, and failure/resume

One existing lane owner writes each stack revision; logical operation key is repository +
stack revision + layer + original head/base + target tip + policy revision.
Duplicate events fetch actual PR/ref state and return an already-applied record.
Persist a synchronization intent before mutation, then observed result afterward.
After a crash, distinguish not-started, applied and ambiguous effects by re-fetch;
never blindly repeat a merge, retarget or reconstruction.

Current workflow concurrency does not establish transactional stack state. Durable
storage, writer fencing and revision-conflict behavior must be chosen and demonstrated
before implementation; no CAS guarantee is asserted here.
Concurrent edits, parent close without merge, deleted ref, scope drift, failed protection
query or merge conflict freeze that layer and descendants with an explicit blocker.
Do not skip them silently or use a fresh unrelated green run.

Proposed bound: three reconciliation attempts per unchanged revision; two identical
failures produce remediation, three or 24 hours pause/escalate per hybrid policy.
Resume only with resolved blocker, recorded owner decision where scope changes, fresh
ancestry and validations. A retry never grants layer or finalization authority.

## Actual-behavior fixture plan

Future disposable-repository tests must inspect refs, trees, retarget API effects,
protection results, receipts and queue outcome, not just dependency labels.

| Fixture | Required result |
|---|---|
| Protected three-layer dependency chain | Bottom-up effects; one main finalization |
| Label dependency with unrelated branch history | Rejected, no stack mutation |
| Parent edited while child validation green | Descendants invalidated and rechecked |
| Squash parent merge | Unique child delta retained, old parent SHA not assumed ancestor |
| Parent closed unmerged / deleted / conflict | Freeze descendants with resumable blocker |
| Duplicate merge/retarget event after worker crash | Read actual state; no repeated effects |
| Unprotected integration branch / unauthorized scope | Fail closed, no bypass merge |
| Fresh finalization group vs stale PR green | Only exact final tree/constituent evidence accepted |
| Aggregate XXL without qualified approval | Finalization blocked despite small layer approvals |

## Alternatives, rollout, and unresolved decisions

Independent direct-main PRs remain preferred when no true dependency exists.
Reject label-only stacks and unchecked layer merges. Rebase versus protected merge-style
synchronization depends on author ownership and proven provenance; neither licenses
unapproved history rewriting. If required layer protection cannot be implemented safely,
keep manual protected integration and declare automation blocked.

Missing prerequisites: approved finalized contract/required PRD, #3669 readiness identity
implementation, chosen protected-layer validation surface, proven durable state/writer
behavior, squash fixtures, and separately authorized runtime work.
Main admission enforcement tracked by #3672 is a separate finalization boundary, not
something satisfied by this proposal or by #3499 queue setup.
Stage 0 leaves runtime default off; stage 1 observes ancestry/protection read-only;
stage 2 validates disposable stacks. A separately approved bounded pilot follows only
after all layer and finalization controls are proven. Stop on lost child delta, stale
validation, unauthorized mutation or missing protection.
Rollback disables new stack automation, preserves refs/manifest and delegates remaining
work to existing protected manual integration. Integrated changes require protected
PR-based reverts; do not reset main or destroy evidence during rollback.

## Implementation status

Stage 1 read-only logic in `.github/base-coat/scripts/stack-handoff.cjs` (tests: `tests/stack-handoff-tests.cjs`)
validates ancestry and protection, selects bottom-up advancement, invalidates descendants, plans
squash-aware sync and evaluates finalization through the protected-main barrier. No ref mutations.
