# Protected-Main Eligibility Barrier Proposal

## Status and sources

Proposal only, related to [source #3672](https://github.com/IBuySpy-Shared/basecoat/issues/3672).
This is a reviewable enforcement contract, not a production configuration choice,
approval, admission authority, ruleset mutation, or proof of exploit/live acceptance.
Merging this proposal does not satisfy source runtime acceptance.
No new alias, bypass actor, broad token permission or routine XL review is introduced.

[Governance](../reference/governance-contract.md),
[hybrid branching](../operations/hybrid-branching-policy-contract.md), and
[stack guidance](../guides/stacked-pr-integration.md) remain controlling contracts.
Inputs depend on the proposed
[readiness identity proposal #3718](https://github.com/IBuySpy-Shared/basecoat/pull/3718),
[ordered holds proposal #3720](https://github.com/IBuySpy-Shared/basecoat/pull/3720)
and, for stack finalization only,
[stack manifest proposal #3719](https://github.com/IBuySpy-Shared/basecoat/pull/3719).
These are proposal prerequisites, not already-implemented capabilities.

## Current mechanism evidence

Inspected baseline: `b2cb3c03003dc40f0eb4a67c32dfa69a2e4aae11`.
`.github/governance/rulesets/main-merge-queue.json` requires eight validation/guardrail
contexts with producer integration ID `15368`, squash queue groups of one, and no
bypass actors. It does not require `BaseCoat merge eligibility`.
This repository declaration is not a fresh live-rules snapshot.

`pr-auto-merge-executor.yml` produces that eligibility status, uses default-branch
helpers, checks draft/decomposition/approval/holds, rechecks head, and uses
`BASECOAT_MERGE_QUEUE_TOKEN` for event-generating admission.
`merge-eligibility-policy.cjs`, `pr-decomposition-evaluator.cjs` and
`ship-it/preapproval-evidence.cjs` already own policy/decomposition/authority evidence.
Existing CI and guardrail workflows handle `merge_group`; the executor's per-PR
status alone does not establish a trusted constituent-aware group barrier.
The source records a configuration gap, not a demonstrated unauthorized merge.

## Non-goals and owners

No ad-hoc branch/ruleset/settings mutation, queue disablement, admin merge bypass,
assignment, issue approval, workflow dispatch or source closure.
Eligibility is distinct from completeness, scheduling and admission.
Preserve solo-dev zero routine human PR reviews through XL; XXL requires qualified
current-head approval under existing policy. Source/spec authorization is not PR review.

Existing workflow maintainers own trusted evaluation using canonical helpers.
Repository governance/protection owners decide declarative enforcement and installed
producer identity after fixtures. The delivery writer consumes eligibility but must
not be its sole enforcement boundary.

## Requirements traceability

| Source requirement | Proposed enforcement / evidence |
|---|---|
| Direct admission cannot bypass eligibility | Required trusted pre-admission PR barrier on every path |
| Exact head/base/constituents | Identity and invalidation below |
| Qualified scope, holds, XXL | Same canonical predicates at PR and group stages |
| No deadlock/stale green | Separate evaluation from enqueue; group-specific recomputation |
| Producer identity | Installed app binding, trusted default-branch evaluator |
| Authorized XL / blocked XXL / stack finalization | Actual-effects fixture matrix |

## Input and output identity

Per-PR input binds repository ID, PR ID, head repository/ref/SHA, base ref/SHA,
diff/tree digest, readiness identity, approved source/spec/task and current permission,
policy revision, decomposition/classification, hold revision and validation producers.
Output is eligibility decision, exact identity, reason/evidence references,
producer app ID, run ID and evaluated revision/time. Unknown or missing evidence blocks.
A success is an observation for that identity, not a reusable bearer authorization.

Group input additionally binds native group ID/ref/head SHA, protected base SHA,
ordered complete constituent PR IDs and exact heads, integration tree/digest and
each constituent's current authority/hold/eligibility identity.
Group output is a fresh group-scoped decision on the synthetic head, never a copied
PR-head green status. The group membership API and complete enumeration must be proven;
branch naming or commit-message parsing alone is insufficient.

## Proposed declarative barrier

1. Trusted default-branch evaluation publishes per-PR eligibility before enqueue.
   It checks completeness, destination, complete decomposition, current authority,
   active holds, dependencies, size and configured policy boundaries.
   Do not check out or execute PR/fork code with status/write credentials.
2. Declarative protected-main enforcement must require the trusted eligibility producer
   on all direct/manual/API/auto admission paths, alongside current required contexts.
   Match the installed app identity, not just status text or an actor login.
   Existing integration ID `15368` is evidence of other checks, not an automatic choice
   for this barrier. Shared-app context spoofing remains a trust-boundary decision.
3. The initial PR decision must not depend on queue membership or an eligibility group
   check that can exist only after admission. CI and group checks must not wait for a
   successful enqueue action to generate the pre-admission status.
4. On `merge_group` creation/rebuild, evaluate every exact constituent with trusted
   helpers and fetch current scope/hold/approval evidence; bind resulting decisions to
   the current protected base and synthetic group tree. Then emit group eligibility.
   Do not enqueue from this group evaluator or create recursive executor dependencies.
5. A new head, base/tree, constituent set, policy, approval or hold revision invalidates
   prior success. Missing/revoked evidence, missing member, failed query or cancelled run
   must not yield a green barrier. An active hold after admission must block fresh group
   eligibility; separately authorized reconciliation owns queue cleanup, not this proposal.
   Revocation after an already-green group must not wait for a `merge_group` rebuild:
   require a trusted default-branch event consumer for hold, approval/permission, policy
   and candidate-index changes plus a poller that covers missed events and API outages.
   Track every active group affected by changed constituent evidence. Advance its durable
   evidence revision, fence superseded evaluators, and publish non-success on the exact
   group head or use separately authorized queue removal before final merge.
   Verify the observed blocking/removal effect; issuing an API request is not proof.
6. Finalization of a protected stack uses the aggregate manifest and exact final tree.
   Prior layer approval/checks cannot substitute for current main-bound eligibility.
   Keep existing native queue exact-tree validation; no unprotected finalization shortcut.

## Configuration alternatives and unresolved boundary

Option A: extend the existing status context with declarative producer binding and
independent PR/group producers. Accept only if GitHub actually enforces pre-admission
blocking, trusted app provenance, invalidation and group behavior in fixtures.
Option B: dedicated installed check producer/admission integration if shared-app or
status lifecycle cannot meet that guarantee. Reuse policy helpers; do not create a
second authority engine or broad token. App choice is not made by this proposal.
Executor-only checks are rejected because alternate authenticated paths remain outside
that executor. Requiring a group-only status on the PR is rejected as circular.

If native protection permits blocked PRs into the queue but blocks only final merge,
that does not satisfy the requested admission boundary. Report the limitation and
require an owner-selected enforceable entry control before implementation approval.
No unsupported admission hook, status CAS or synchronous invalidation is presumed.

## Concurrency, idempotency, and bounded failure/resume

Use repository + stage (PR/group) + exact identity + policy/evidence revision as
operation key. Duplicate events recompute current evidence; stale workers must not
overwrite current decisions with success. Final re-fetch and observed post-publication
verification narrow races but do not prove atomic mutation.
Durable decision storage, writer fencing and platform status ordering remain prerequisites.
The admission writer's serialization does not itself fence independent status writers.

Plain events, polling and status/removal APIs cannot atomically order revocation against
native final merge. An old green may be consumed before failure/removal becomes effective;
post-merge detection cannot satisfy "holds remain effective." Before activation, owners
must choose an actually supported primitive that fences finalization against the evidence
revision, or a verified platform timing/control bound with explicit accepted residual
limitations that still satisfies the source contract. Prove worker fencing, event/poller
coverage, detection/publication latency and effective blocking before final merge.
No current API primitive, CAS, guaranteed grace period or atomic revocation is asserted.
If the required before-final-merge guarantee cannot be demonstrated, enforcement activation
remains blocked/default-off; a fast poller or measured average latency is not sufficient.

Proposed retry budget: three evaluations per unchanged identity with backoff; exhausting
that budget stops retries without redefining the controlling hybrid escalation policy:

- 2 consecutive lane CI failures on same signature: open remediation issue.
- 3 consecutive failures or >24h unresolved blocker: pause lane and escalate.
- Cross-lane repeated failure signatures: raise global coordination issue.

After timeout/unavailable evidence, remain non-successful; resume requires fresh exact
evidence, not a prior green run, expired hold or task/workflow execution approval.
Owners must select a proven mechanism for prompt revocation and measure its race window.

## Actual-behavior fixture plan

Future disposable-repository fixtures must exercise actual protection/admission APIs,
trusted installed producer identity, native group rebuilds and persisted effects.
Static ruleset/YAML assertions alone cannot prove the boundary.

| Fixture | Required behavior |
|---|---|
| Direct authenticated admission with blocked/missing eligibility | Rejected before entry; not merely blocked at final merge |
| Authorized solo-dev XL, exact scope/tree, no holds | Admission and exact-group checks succeed with zero routine reviews |
| XXL without qualified current-head approval | Blocked; stale approval does not pass |
| Same context from wrong app / untrusted fork | Rejected; no privileged PR-code execution |
| Old green plus new head/base/policy | Re-evaluate; no stale green reuse |
| Hold/revocation after admission / API failure | Group cannot succeed on stale constituent evidence |
| Hold/approval revoked after group green without rebuild | Trusted event/poller fences stale workers and blocks/removes before final merge, or activation stays blocked |
| Delayed event / outage / stale worker green races failure | Proven primitive/bound prevents stale finalization; unsupported guarantee blocks activation |
| Rebuilt group / changed member / multiple-member test | Exact complete membership recomputed despite current group-of-one setting |
| Protected stack finalization | Aggregate manifest authorized; current exact-tree group succeeds |
| PR barrier then group barrier | No circular wait or recursive queue request |
| Duplicate event / out-of-order status completion | No stale worker success replacing current failure |

## Default-off rollout, rollback, and missing prerequisites

Stage 0 is documentation only; new enforcement runtime remains default off.
Stage 1 evaluates shadow decisions without production writes; stage 2 proves disposable
protected-main admission and group behavior. Stage 3 requires separate approved IaC/runtime
PRs and explicit owner go/no-go after producer, race and no-deadlock evidence.
Do not enable a required status before its trusted producers and group triggers work.

Missing: finalized approved contract, required intake artifacts, implemented readiness/hold
identities, stack manifest where applicable, complete group lookup, installed producer
choice, effective live-policy inventory, revocation/fencing proof and hosted fixtures.
After-green revocation coverage and a supported verified before-final-merge primitive/bound
are still missing activation prerequisites, not capabilities implemented by this proposal.
Stop on stale green, bypass admission, untrusted producer, deadlock or missing constituent.
Rollback through separately authorized declarative governance changes; preserve existing
queue/checks and fail closed by pausing new admissions rather than silently removing
authority enforcement. Keep evidence for recovery; documentation rollback is a PR revert.
