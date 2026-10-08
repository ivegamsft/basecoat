---
issue: 3594
title: "feat(release): establish governed automatic version-tag ownership after validated merge"
status: proposed
author: ibuyspy
created: 2026-10-06
labels: ["enhancement", "priority:high", "needs-triage", "needs-prd", "synthesize-spec"]
---

# Spec: Governed automatic version-tag ownership after validated merge

## Context

Issue #3594 requests a bounded release owner because the current release train
creates a candidate issue and tag-driven workflows publish only after an actor
creates a version tag. The paired PRD defines requirements R1-R9. This spec
defines the future workflow contract; it does not implement or authorize a
release.

## Scope

One serialized orchestration path over already-merged, explicitly delivery-
authorized work. It inventories and freezes a release window, prepares
version-aligned metadata through a normal protected PR/queue, then creates at
most one immutable tag for the exact merged metadata commit after revalidating
all inputs. Existing tag-triggered workflows build and publish. The owner
observes and verifies their results.

## Out of Scope

- No tag, release PR, version bump, production dispatch, or live release is
  performed by this specification.
- No release on every PR merge, moving-ref packaging, approval inferred from
  labels or workflow events, merge/check/production-gate bypass, or tag
  deletion/retargeting.
- No change to publisher behavior except the minimum separately reviewed
  changes required to make the authorized tag event and its evidence reliable.

## Architecture and State Contract

The owner is a single-flight state machine keyed by an immutable release-window
identity:

| State | Meaning | Permitted next step |
|---|---|---|
| `NO_RELEASE` | Complete inventory has no authorized, release-worthy changes under documented policy. | Persist report; no metadata PR or tag. |
| `BLOCKED` | Authorization, baseline, inventory, checks, version decision, or token preflight is missing/invalid. | Report exact blocker; retry only after the input changes. |
| `CANDIDATE` | Authorized window and proposed version are frozen with complete evidence. | Open/update one metadata PR. |
| `METADATA_MERGED` | Metadata PR is merged through required protections; its merge SHA is recorded. | Revalidate current evidence and preflight. |
| `TAGGED` | Exact version tag resolves to the recorded metadata merge SHA. | Observe existing tag-triggered publishers. |
| `PARTIAL` | Tag exists but any required source/mirror artifact or verification is incomplete. | Retry only the failed publisher/verification for the same tag. |
| `VERIFIED` | Tag, source release, mirror release, assets, and required checks agree. | Report production completion. |

Every transition records the release-window base tag/SHA, candidate SHA/tree,
included and excluded PRs with reasons, selected version, metadata PR/merge,
authorization reference, check evidence, preflight run, tag target, publisher
run IDs, and artifact verification. Credentials and credential-bearing
responses are never persisted in this record.

## Data Model, Storage, and Concurrency

The authoritative state store is a dedicated repository-owned `release-state`
ref with a ruleset that permits writes only from the trusted release-owner
workflow identity, rejects force updates and deletion, and retains its commit
history for the lifetime of the associated tag and release evidence. Provision
and verify this ref/ruleset before enabling metadata or tag writes. Actions
artifacts, caches, workflow outputs, issue comments, and workflow run history
are evidence or transport only; none is authoritative state.

Each canonical JSON window record has a schema version, repository ID, stable
window key, monotonically increasing revision, state, previous-record digest,
base tag and commit, candidate commit/tree, sorted included and excluded PR
numbers with merge SHAs and dispositions, sorted authorization identities and
source-body/approval-comment hashes, selected SemVer, metadata PR/merge SHA,
immutable intended tag/SHA, check and preflight run identities, publisher
workflow/run identities, artifact verification results, and timestamps. Store
only non-secret evidence; never store tokens, credentials, or
credential-bearing API responses. Preserve transition history in immutable
Git commits; do not rewrite or prune records while any referenced tag or
required audit evidence exists.

Compute `window_key` as SHA-256 over canonical JSON containing the repository
ID, verified baseline tag and peeled commit SHA, frozen candidate commit/tree,
sorted `(source issue, original approval-comment ID, issue-body hash,
approval-comment hash, approved-scope digest)` tuples, and sorted `(PR number,
merge SHA)` tuples. The record path is uniquely derived from that key. A retry
with the same key must load and resume that record; changed authorization,
inventory, candidate, or metadata creates a different key and cannot
overwrite the earlier target. The immutable tag/SHA target is persisted before
any tag-ref creation request.

All state-mutating owner phases use one repository-ID-scoped GitHub Actions
concurrency group with cancellation disabled. The state adapter also performs
optimistic compare-and-swap: construct the next commit from the observed
`release-state` head and update the ref without force. A non-fast-forward
rejection means another writer won; re-read and reconcile the latest record
before deciding whether to resume or block. Never retry a stale write, force
the ref, or treat a missing/inaccessible store as an empty store. API
permission, timeout, parse, or ref-update errors are `BLOCKED` until the
authoritative record is re-read.

The adapter exposes `readWindow(windowKey)` and
`compareAndSwapWindow(windowKey, expectedRefHead, expectedStateRevision,
expectedStateDigest, nextRecord)`. A missing key is distinct from inaccessible
state. The write must reject a ref-head/key/revision/digest mismatch, state
regression, illegal transition, or conflicting immutable tag target. Test two
independent writers starting from the same ref head: exactly one write may
advance it; the loser must re-read and must not overwrite. Git commit ancestry
provides the immutable audit trail; the per-window record is the current
snapshot, not a separate approval source.

## Authorization and Release-Window Inventory

1. Accept only the existing #3591/#3476 source-issue contract; do not introduce
   a new approval store or infer authority. Pass #3591 validation: same-repo
   open non-PR issue, valid type/priority metadata, no `duplicate`, `invalid`,
   or `wontfix` blocker, exactly one valid non-placeholder bare `- Spec:` URL,
   and all declared dependencies resolved. Also require the #3476
   `Intent Contract` section with exactly one nonempty `Intent`, `Goal`,
   `Scope`, `Repository`, `Risk band`, `Profile`, and commit-pinned
   same-repository `Spec reference`; the `Spec reference` must identify the
   same immutable spec as the sole `- Spec:` URL. `Goal` and `Scope` must
   match exactly and `Repository` must equal the target repository. The intent
   must be the existing canonical `ship-it` or `spec-2-prod` value. Require
   the live `approved` label and the original issue comment to be exactly
   `/approve` after trimming and case-folding, authored by a non-bot human with
   current `write`, `maintain`, or `admin` permission. Require the body’s last
   edit time not to be later than the effective approval time, using the later
   of comment creation and update time; the approval must also predate the
   initial authorization run start. Record that original run ID/cutoff, issue
   body hash, comment ID/URL/body hash, and creation/update times. Re-fetch the
   same issue, same original comment, spec blob, live permission and approval
   state before each irreversible boundary; edited/deleted/replaced evidence,
   changed hashes, or changed permission blocks rather than selecting a new
   approval. The source issue must be open at initial authorization. If it is
   later closed and the current #3476 contract would reject it, remain
   `BLOCKED` until that contract explicitly defines and validates a post-merge
   release use of the original receipt; a receipt alone cannot bypass the
   open-issue check. A label, merged PR, candidate issue, dry-run, bot receipt
   alone, or workflow event never substitutes for the original authority.
2. Bind the authorization to a canonical, machine-checkable release scope in
   both `Goal` and `Scope`, using exactly this grammar:

   ```text
   release-window:<40-lowercase-hex-baseline-commit>..<40-lowercase-hex-candidate-commit>;prs:<positive-decimal-pr>[,<positive-decimal-pr>...]
   ```

   PR numbers must be unique, in ascending numeric order, with no leading
   zeroes or whitespace; reject any extra characters. For example,
   `release-window:0123456789abcdef0123456789abcdef01234567..89abcdef0123456789abcdef0123456789abcdef;prs:123,456`.
   Resolve the baseline commit to the latest verified canonical SemVer tag and
   require candidate ancestry from it. The trusted resolver records the exact
   peeled baseline tag and the full candidate SHA/tree. Every included PR
   number must appear in the approved set and its live merge SHA must match the
   complete release-window inventory. Each listed PR must have validated
   provenance to that source issue through the existing source/handoff
   contract; titles, free-text references, and labels do not establish
   provenance. A PR outside the set is excluded with a reason, never silently
   added. Combining authorizations is allowed only when each original scope
   names the identical baseline, candidate, and complete PR set and each
   source issue has valid provenance for its listed PRs; otherwise split the
   release or remain `BLOCKED`. This canonical scope parser is an explicit
   #3476 integration requirement and must be implemented and tested before
   enabling any release writes. Labels such as `approved`,
   `release-candidate`, wave/sprint labels, a merged PR, or a workflow
   dispatch are not authorization. Dry-run output is observational only.
3. Resolve the latest verified canonical semver tag and its commit. Prove it is
   an ancestor of the candidate main commit. If no valid baseline or complete
   history is available, enter `BLOCKED`; do not fall back to an arbitrary
   recent date or partial page.
4. Enumerate all PRs merged after the baseline and through the candidate commit
   using complete pagination. Reconcile the API inventory against merge commits
   reachable in the candidate history. Persist each PR number, merge SHA, title,
   labels, authorization mapping, and inclusion/exclusion disposition. Any
   mismatch, ambiguous authorization, or unresolved item blocks the candidate.
5. Freeze the candidate to the full commit SHA and tree. A later merge is not
   silently included. Before tag creation, repeat the inventory through the
   frozen candidate and verify that authorization and required check evidence
   remain current. If the chosen policy requires a newer main head, discard the
   candidate and create a newly inventoried window.
6. Group only work within the authorized scope and documented release policy.
   Exclusions require explicit rationale and must not hide an open blocking
   issue, failed check, or omitted authorized item. Never infer a release batch
   from all merged PRs or from a wave label alone.

## Version and Batching Policy

Use canonical SemVer rules in `docs/operations/release-process.md`: breaking
consumer contract changes require major; compatible additions require minor;
fixes and documentation corrections require patch. Review every included item
and any release since the baseline. Do not use a preselected version or infer a
patch bump solely from the trigger issue.

- A complete inventory with no eligible authorized changes ends as `NO_RELEASE`
  and produces a report only.
- Docs-only changes are not silently dropped. If consumer-visible distributed
  content or canonical release documentation changes, classify and version them
  under the same documented SemVer rules. Internal-only notes/operations changes
  may be excluded only with a recorded rationale and no consumer payload change.
- If policy cannot decide whether a docs-only or mixed batch is releasable,
  remain `BLOCKED` pending an explicit policy change; do not create a tag.
- If more than one authorized scope is eligible, preserve scope boundaries.
  Combine scopes only when their delivery authorization explicitly covers the
  combined batch and the full inventory is reviewed. Otherwise serialize separate
  release candidates.

The implementation must not invent batch-size thresholds. If a future policy
adds one, it must be specified and tested independently of authorization.

## Metadata PR and Validation

The owner creates or updates one branch/PR for the frozen candidate containing
only the release metadata allowed by repository policy:

- `version.json` with the selected version and release date;
- `CHANGELOG.md` with complete, accurate release-window notes and PR references;
- `asset-manifest.json` if its library version or generated integrity data must
  change for the version.

The PR body binds the base tag/SHA, candidate SHA/tree, full included/excluded
inventory, version rationale, authorization reference, and required validation
evidence. No PR head is treated as merged release evidence. The PR goes through
normal review/required checks/native merge queue; no admin merge, bypass, or
synthetic approval is permitted. At merge, record the actual merge commit SHA.

Before tag creation:

1. Confirm metadata commit is reachable from canonical `main` and all required
   merge/check gates passed for the exact integrated commit.
2. Parse the version as a valid new SemVer value greater than the baseline.
   Confirm `version.json`, changelog heading, and `asset-manifest.json` version
   agree with `v<version>`.
3. Prove the frozen candidate and all included PR merge SHAs are ancestors of
   the metadata merge commit. Reconcile the interval inventory again and ensure
   no unauthorized or unresolved work has been silently added.
4. Confirm current authorization still applies to the frozen scope and required
   release evidence has not expired or been superseded.
5. Run `token-preflight.yml` and require successful production mirror readiness.
   Preflight is a readiness check, not authorization. Do not echo tokens or
   widen permissions to make the probe pass.
6. Require the #3595 release-label policy implementation to be merged and
   verified before tag creation. Evaluate its one shared classifier over the
   complete immutable release-window inventory, using the same per-PR result
   and existing aggregate threshold at PR validation, exact merge-group
   validation, and release-window validation. Persist the policy/runtime
   revision, complete inventory digest, counts and bounded diagnostics.
   Missing implementation, incomplete pagination, changed labels, unavailable
   evidence, or any stage disagreement blocks before tag creation. #3595's
   merged specification alone is not implementation evidence.

If metadata is stale, the release window changed, or any check fails, remain
`BLOCKED` and update through a new normal PR rather than editing the merged
commit.

## Tag Creation, Idempotency, and Concurrency

Use one repository-level concurrency lock for version selection, metadata PR
promotion, and tag creation. Recheck tag existence while holding the lock.

- Tag must be exactly `vMAJOR.MINOR.PATCH`, new relative to the verified
  baseline, and point to the full SHA of the metadata commit whose tree passed
  the checks above.
- Create the tag ref only if absent. If it already points to the exact intended
  SHA, treat the create step as complete and continue observing/recovering the
  same release. If it points anywhere else, enter `BLOCKED`; never force-update
  or delete it.
- Persist the intended tag/SHA before creation. A retry with the same
  window/version/SHA resumes idempotently. A different SHA or version creates a
  conflict requiring a new, reviewed metadata candidate; it cannot overwrite
  the persisted target.
- Tag creation must use a narrowly scoped, trusted credential path that can
  create the ref and trigger the existing tag workflows. Do not assume the
  default `GITHUB_TOKEN` event will trigger downstream workflows. Prove the
  event path in a controlled test. Do not reuse the production mirror token
  for source tag ownership.
- Grant only required permissions. Never run untrusted PR code with the tag
  credential. No script evaluates PR-controlled code during tag authorization.

## Publication and Verification

The tag starts the existing `release.yml`, `package-basecoat.yml`, and
`publish-to-production.yml` workflows. The owner correlates each actual
workflow run to the exact tag ref, commit and current release window; waits for
all required publishers; and verifies:

- tag resolves to the exact metadata SHA; source release is published and not a
  draft or prerelease unless explicitly supported by the authorized scope;
- expected source archive, sync assets, and package artifacts exist and their
  published checksums validate;
- production mirror tag resolves to the corresponding intended source commit
  under the documented transformation/provenance contract, and mirror release
  assets are present and verified;
- required release docs and consumer smoke evidence pass against the published
  artifacts, not just `main`, a workflow dispatch marker, or a dry-run report.

Report state as `PARTIAL` until every mandatory source/mirror check succeeds.
After tag creation, recover by retrying the failed publisher or verification
for that same immutable target. Do not create a second version merely to hide a
transient publish failure; do not report success based only on an internal
release.

## Failure Modes and Recovery

| Failure | Required behavior |
|---|---|
| Missing authorization or only an approval/release label exists | `BLOCKED`; request a valid existing delivery authorization. |
| Intent scope cannot be parsed into the exact included PR set | `BLOCKED`; add and verify the canonical scope parser before writes. |
| Tag baseline/history/inventory is incomplete or inconsistent | `BLOCKED`; preserve evidence and repair inventory source. |
| State ref is missing, inaccessible, malformed, stale, or compare-and-swap loses | `BLOCKED`; preserve the existing ref, re-read authoritative state, and reconcile without a stale overwrite. |
| #3595 policy is absent, incomplete, stale, or disagrees across stages | `BLOCKED` before tag creation; complete and verify the shared classifier. |
| Merge/check evidence or candidate tree is stale | Discard candidate and revalidate through the normal path. |
| Metadata version/changelog/manifest disagree | Do not tag; correct through a new protected metadata PR. |
| Token preflight is missing/failed | Do not tag; identify the missing permission/secret readiness without exposing credentials. |
| Concurrent duplicate attempts select same target | Serialize and resume the same state/tag; do not create a second tag. |
| Existing version tag resolves to a different SHA | `BLOCKED`; preserve the immutable tag and open an incident/remediation record. |
| Source release succeeds but mirror/assets/docs/smoke fail | `PARTIAL`; retry the failed same-tag stage and withhold production-complete claim. |
| No authorized release-worthy work exists | `NO_RELEASE`; report the complete inventory and do not create metadata or tag. |

## Security and Permissions

The workflow's default permissions are read-only. Separate the metadata PR
creation capability, source tag capability, and production mirror publisher.
Use repository-controlled workflow code on a trusted protected ref, least
privilege, environment protection where already required, and masked secrets.
The state writer may update only the dedicated protected `release-state` ref;
the tag writer may create only a new SemVer tag after revalidation. Neither
capability may force-update or delete refs, and untrusted PR code never runs
with either credential.
Tag-creation authority must be limited to source `contents: write` and any
minimum event-triggering permission supported by the selected credential. The
production mirror token remains scoped to the mirror and is only used by the
publisher. Do not create new routine human review gates through XL; preserve all
existing qualified authorization, protected merge, required check, and
production environment controls.

## Testing Strategy

Tests must use mocked GitHub APIs and disposable refs/repositories; they must
not create a production tag or publish a real release.

| PRD requirement | Required test / expected result |
|---|---|
| R1 | Reject approval labels/proxies, wrong-repository or edited scope, malformed/unpinned spec, bot or unqualified author, changed permission, revoked/mutated/deleted directive, and intent mismatch. |
| R2 | Test exact approved PR-set parsing and provenance mapping; paginate past API page boundaries; reconcile every PR merge SHA through the frozen candidate; missing pages, ambiguous mappings, or mismatches block. |
| R3/R7 | Test SemVer bump classes, intervening releases, complete no-op inventory, consumer-visible docs-only patch, and internal-only docs disposition. |
| R4 | Metadata mismatch, unmerged PR, stale base, and failed integrated check prevent tag creation; exact merged SHA succeeds. |
| R5 | Revoke/change authority, stale check/label evidence, absent #3595 implementation, cross-stage classifier disagreement, or failed/missing token preflight between candidate and tag; each blocks. |
| R6 | Restart after every state transition; run two independent writers from the same expected ref; exercise lost write responses, stale revision/digest, branch movement, and repeated retries. Exactly one CAS advances; same-SHA existing tag resumes; different-SHA target blocks without mutation. |
| R8/R9 | Missing source asset, checksum mismatch, absent mirror release, failed smoke, and partial publish remain `PARTIAL`; same-tag retry can complete. |
| Credential event path | Prove the chosen narrow credential triggers the actual downstream tag workflows without exposing token data or running untrusted code. |

Run repository workflow syntax validation, focused release-owner contract
tests, release/token/publish workflow tests, the `release-state` adapter/ref
ruleset tests, and Markdown lint. Record exact
commands and results. A test plan or mock result does not establish successful
production delivery.

## Rollout and Operational Readiness

Start in report-only mode over a complete bounded release window and compare
the inventory with the canonical merged PR list and tag ancestry. Enable metadata
PR preparation only after report correctness is demonstrated. Enable tag
creation only after exact-tree, authorization, preflight, event-chain,
concurrency, and partial-recovery tests pass. Monitor the complete state
transition record and alert on `BLOCKED`/`PARTIAL`; never turn missing telemetry
into a success default.

## References

- [PRD](../../prd/synthesized/issue-3594-featrelease-establish-governed-automatic-version-tag-ownership.prd.md)
- [Source #3594](https://github.com/IBuySpy-Shared/basecoat/issues/3594)
- [Shared approval contract #3591](../issue-3591-approval-contract.spec.md)
- [Auditable pre-approval contract #3476](issue-3476-support-auditable-pre-approval-for-unattended-ship-it-runs.spec.md)
- [Immutable package target #3578](https://github.com/IBuySpy-Shared/basecoat/issues/3578)
- [Unified release-label policy #3595](issue-3595-fixrelease-align-pr-label-exemptions-with-release-coverage-p.spec.md)
- [Release process](../../operations/release-process.md)
- [Governance contract](../../reference/governance-contract.md)
