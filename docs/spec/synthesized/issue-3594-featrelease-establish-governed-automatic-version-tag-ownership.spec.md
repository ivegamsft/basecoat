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
| `PARTIAL` | Tag exists but any required source/mirror artifact or verification is incomplete. | Retry only the failed publisher/verification for the same tag, within the retry budget. |
| `FAILED` | Tag exists and the `PARTIAL` retry budget is exhausted, or a non-retryable publication fault occurred. | Hold all later windows; resume the same tag (`FAILED -> PARTIAL`) only from a recorded `/release-retry` remediation receipt, or retire it (`FAILED -> RETIRED`) via `/release-retire` (see Failure Modes). |
| `RETIRED` | Terminal. A qualified human retired a `FAILED` tag; the tag is preserved, never deleted or moved, and is never reported as production-complete. | None. Releases the later-window hold; the next window must select a higher version. |
| `VERIFIED` | Tag, source release, mirror release, assets, and required checks agree. | Report production completion. |

Every transition records the release-window base tag/SHA, candidate SHA/tree,
included and excluded PRs with reasons, selected version, metadata PR/merge,
authorization reference, check evidence, preflight run, tag target, publisher
run IDs, and artifact verification. Credentials and credential-bearing
responses are never persisted in this record.

## Data Model, Storage, and Concurrency

Rulesets authorize updates per ref, not per path or field, so authoritative
state is split across three dedicated repository-owned branches
(`refs/heads/...`, so branch rulesets apply), each with exactly one
permitted writer:

- `release-state`: window records and the `current-window` pointer; written
  only by the release owner.
- `release-receipts`: delivery receipts (Authorization step 2); written only
  by merge eligibility via `appendReceipt`.
- `release-publication`: publisher results at
  `<window_key>/<stage>/<run-id>` (staged `mirror_target`, `mirror_main_tip`
  after a successful branch push, attempt outcome, and run conclusion);
  written only by the publisher via `appendPublication`.

Each branch is governed by two layered rulesets, because a bypass actor
bypasses every rule in the ruleset that lists it. A writer-admission
ruleset restricts creation and updates and lists only that writer's GitHub
App as a bypass actor. A separate immutable-history ruleset blocks
non-fast-forward updates and deletion and has no bypass actors, so the
writer's admission bypass never exempts it from history protection. No App private
key is stored as an Actions or environment secret, because environments
restrict deployment refs, not workflow files. Instead, a credential broker
mints a short-lived, single-repository installation token only after
validating the job's GitHub Actions OIDC token: `repository_id`, the exact
`job_workflow_ref` path for that writer's workflow, and the expected
`event_name` and `ref` (`refs/heads/main` for the owner, merge eligibility,
and publisher `workflow_dispatch` retries; a SemVer tag whose peeled commit
is reachable from `main` for publisher tag pushes). Reachability alone is not
sufficient: the broker reads the writer's `workflow_bindings` entry in
`.github/governance/policy-packs.json` at the current protected `main` head
and requires the SHA-256 of the workflow file at `job_workflow_sha` to equal
its `expected_workflow_sha256`. A stale-but-reachable revision, such as a
dispatch at an older tag or a superseded publisher, is refused; approving a
new revision means updating that binding through a protected PR. Any other
workflow, ref, event, or digest is refused. `GITHUB_TOKEN` and other identities are
not permitted writers or bypass actors on these branches.
`release-receipts` and `release-publication` writes are append-only with
absent-or-exact semantics per path. The owner reads publisher results and
folds them into the window record (`mirror_target`, `mirror_main_tip`,
attempts, accepted run IDs, `PARTIAL`/`FAILED`) by CAS; results keyed to any
window other than `current-window` are ignored. The immutable-history
rulesets reject force updates and deletion by every identity, including the
writer, and history is retained for the lifetime of the
associated tag and release evidence. Provision and verify all three
branches, rulesets, and the broker before enabling metadata or tag writes. Actions
artifacts, caches, workflow outputs, issue comments, and workflow run history
are evidence or transport only; none is authoritative state.

Each canonical JSON window record has a schema version, repository ID, stable
window key, monotonically increasing revision, state, previous-record digest,
base tag and commit, candidate commit/tree, sorted included and excluded PR
numbers with merge SHAs and dispositions, sorted authorization identities and
source-body/approval-comment hashes, selected SemVer, metadata PR/merge SHA,
immutable intended tag/SHA, immutable `mirror_target` commit/tree SHA,
`mirror_main_tip` after any successful mirror-branch update, per-stage
retry attempts and error classes, remediation receipts, check and preflight
run identities, publisher
workflow/run identities, artifact verification results, and timestamps. Store
only non-secret evidence; never store tokens, credentials, or
credential-bearing API responses. Preserve transition history in immutable
Git commits; do not rewrite or prune records while any referenced tag or
required audit evidence exists.

Compute `window_key` as SHA-256 over canonical JSON containing the repository
ID, verified baseline tag and peeled commit SHA, frozen candidate commit/tree,
sorted `(source issue, original approval-comment ID, delivery-receipt digest)`
tuples, sorted `(PR number, merge SHA, disposition)` tuples where
disposition is `included` or the excluded reason code, and a `generation`
integer. The record path is
uniquely derived from that key. `generation` starts at 1 and is one more than
the highest superseded generation with otherwise identical key material, so a
version or metadata correction over the same inventory creates a distinct
key. A retry with the same inputs resolves to the `current-window` record and
resumes it; changed authorization, inventory, disposition (including a
revocation), or candidate creates a different key and cannot overwrite the
earlier target.

Release metadata is deliberately not part of `window_key`, because the record
exists in `CANDIDATE` before any metadata PR. Metadata is state under the
stable key, advanced only by compare-and-swap revisions:

- The selected version is frozen when the record first enters `CANDIDATE` and
  never changes under that key. A different version requires superseding the
  window (`BLOCKED` with reason `superseded`) and creating the next
  `generation`.
- While in `CANDIDATE`, metadata PR number and head SHA may advance as normal
  CAS revisions (for example, a rebase of the metadata PR).
- Metadata freezes at the `METADATA_MERGED` transition, which records the
  merge commit SHA. After that point no metadata field may change under the
  key; corrections require a new protected metadata PR and the next
  `generation`.

The immutable tag/SHA target is persisted before any tag-ref creation request,
and the immutable mirror target is persisted before any mirror push (see
Publication and Verification).

All state-mutating owner phases use one repository-ID-scoped GitHub Actions
concurrency group with cancellation disabled. The state adapter also performs
optimistic compare-and-swap: construct the next commit from the observed
`release-state` head and update the ref without force. A non-fast-forward
rejection means another writer won; re-read and reconcile the latest record
before deciding whether to resume or block. Never retry a stale write, force
the ref, or treat a missing/inaccessible store as an empty store. API
permission, timeout, parse, or ref-update errors are `BLOCKED` until the
authoritative record is re-read.

The adapter exposes `readWindow(windowKey)`, `readCurrentWindow()`,
`appendReceipt(expectedRefHead, pr, head, receipt)` and `readReceipts(pr,
head)` on `release-receipts` (see Authorization step 2),
`appendPublication(expectedRefHead, windowKey, stage, runId, result)` and
`readPublication(windowKey)` on `release-publication`,
`compareAndSwapWindow(windowKey, expectedRefHead, expectedStateRevision,
expectedStateDigest, nextRecord)`, and
`activateWindow(expectedRefHead, expectedCurrentKey, expectedCurrentRevision,
expectedCurrentDigest, supersededRecord, newRecord)`. `activateWindow` writes
one `release-state` commit that transitions the current record (if any) to
its terminal or `BLOCKED`/`superseded` successor, creates the new record, and
moves `current-window` to it; it rejects a pointer, ref-head, revision, or
digest mismatch, an absent-required or present-unexpected record, or a current
record in `TAGGED`, `PARTIAL`, or `FAILED`. `compareAndSwapWindow` rejects
writes to any record other than the one named by `current-window`. A missing
key is distinct from inaccessible
state. The write must reject a ref-head/key/revision/digest mismatch, state
regression, illegal transition, or conflicting immutable tag target. Test two
independent writers starting from the same ref head, for both operations:
exactly one write may advance it; the loser must re-read and must not
overwrite; two concurrent `activateWindow` calls never leave two active
records or a pointer to a missing record. Git commit ancestry
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
   body hash, comment ID/URL/body hash, and creation/update times in the
   delivery receipt. These checks run while the issue is open, at receipt
   time. Edited/deleted/replaced evidence or changed hashes found at any later
   irreversible boundary exclude the affected PR rather than selecting a new
   approval. The source issue must be open at initial authorization. Because
   implementation PRs close their source issue (`Closes #N`), the owner never
   requires the issue to be open, edited, or re-approved after merge; it
   consumes the pre-merge delivery receipt defined in step 2 instead. A label,
   merged PR, candidate issue, dry-run, bot comment, or workflow event never
   substitutes for the original authority.
2. Bind authorization before merge, not to a post-merge window. The release
   window cannot be named at approval time, so the scope binding is a
   per-PR delivery receipt that the existing merge-eligibility path records
   while the source issue is still open and its `/approve` evidence is live:

   ```text
   delivery-receipt:v1;issue:<n>;comment:<approval-comment-id>;comment-created:<utc-iso>;comment-updated:<utc-iso>;body-sha256:<64-hex>;body-edited:<utc-iso|none>;comment-sha256:<64-hex>;approver:<login>;permission:<write|maintain|admin>;auth-run:<run-id>;auth-cutoff:<utc-iso>;spec-blob:<40-hex>;pr:<n>;head:<40-hex>;size:<XS|S|M|L|XL|XXL>;xxl-review:<review-id|none>;release:<eligible|excluded>
   ```

   All fields are immutable and covered by the receipt digest; the comment
   URL is derived from the repository and comment ID. Receipts live in
   `receipts/<pr>/<head-sha>/<receipt-digest>` paths on the dedicated
   `release-receipts` ref, independent of window records and `current-window`.
   The trusted merge-eligibility identity writes them at PR admission, before
   merge, through `appendReceipt`, which has absent-or-exact semantics per
   digest path: it creates the path if absent and succeeds without change if
   the identical receipt exists. A renewed pre-merge authorization (for
   example a new `/approve` after a body edit) appends a new digest for the
   same head; earlier receipts are retained as history. `appendReceipt`
   rejects any append once the PR is merged, so the receipt set is frozen at
   merge. The current receipt for a merged PR head is the one with the
   greatest `auth-cutoff`; a tie between different digests excludes the PR
   as ambiguous. Appends are allowed in any window state, including
   before the first window and while a tag is `TAGGED`, `PARTIAL`, or
   `FAILED`; a non-fast-forward rejection re-reads and retries the append.
   The receipt digest is bound to the exact PR head that the native queue
   merges. `release:eligible`
   is permitted only when the source issue's approved `Scope` does not opt out
   of release (for example `release: none`). For XS through XL, `xxl-review`
   is `none`. For XXL, the receipt consumes the existing XXL boundary: it is
   `release:eligible` only when merge eligibility has already verified a
   qualified human `APPROVED` review on the exact merged head, and records that
   review ID in `xxl-review`. Without that review the PR cannot merge, so no
   XXL receipt is ever written as eligible without it. Scopes that opt out
   record `release:excluded`.

   At release time the owner derives the window deterministically: the
   baseline is the latest verified canonical SemVer tag, the candidate is the
   frozen `main` commit, and the included set is every PR merged in that
   interval that has a valid `release:eligible` receipt whose `head` equals
   the PR's final head and whose merge SHA is reachable from the candidate.
   PRs without a receipt, with `release:excluded`, or with a receipt whose
   digest no longer matches the stored record are excluded with a recorded
   reason, never silently added. No human edits or re-approves anything after
   merge for XS through XL.

   Revocation remains live: before each irreversible boundary (metadata PR
   creation, `METADATA_MERGED`, and tag creation), re-run the complete step 1
   #3591/#3476 validation against live data, except the open-state check:
   required `type:*`/`priority:*` metadata, blocker labels (`blocked`,
   `needs-info`, `invalid`, `duplicate`, `wontfix`) regardless of open or
   closed state, every declared dependency still resolved, the Intent Contract
   and spec reference, the exact approval comment by ID with its hash and live
   `created_at`/`updated_at` equal to the receipt's `comment-created` and
   `comment-updated` (so an edit-and-restore is detected even when the body
   hash is unchanged), the issue body hash against the receipt `body-sha256`,
   live `lastEditedAt` equal to the receipt's `body-edited`, the effective
   approval time recomputed only from the recorded receipt timestamps, the
   live `approved` label, and the approver's current
   `write`, `maintain`, or `admin` permission (and, for XXL, the recorded
   review not dismissed). Any failure excludes that PR and re-derives the
   window. Closed state from `Closes #N` is expected and is not revocation.
   Exclusion withholds release only; it never reverts merged code.

   A single `current-window` pointer on the `release-state` ref names the one
   active window record; every new record is created in the same commit that
   advances the pointer. A re-derived window has a new `window_key`: in one
   CAS commit (`activateWindow`) the owner transitions the superseded record to `BLOCKED` with
   reason `superseded`, creates the new record, and advances the pointer.
   Publishers (step 0 of the mirror contract) accept only the record named by
   the pointer, so a stale `METADATA_MERGED` record with persisted intent can
   never publish. Supersession happens only before tag creation. While the
   active record is `TAGGED`, `PARTIAL`, or `FAILED`, the pointer never moves
   and no new window record is created, so retries of that tag stay
   publishable.

   Receipt emission is an explicit #3476 integration requirement; it must be
   implemented and tested before any release writes are enabled. Labels such
   as `approved`, `release-candidate`, or wave/sprint labels, a merged PR, or a
   workflow dispatch are not authorization. Dry-run output is observational
   only.
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
- Releases are linear on `main`, so one window includes every PR in the
  interval that holds a valid `release:eligible` receipt; per-issue scopes
  are not serialized into overlapping windows. A source scope that opts out
  (`release: none`, `release:excluded`) or an XXL PR without a qualified
  current-head approving review is excluded with a
  recorded reason. If an excluded change is consumer-visible and cannot ship
  unreleased-but-merged under policy, remain `BLOCKED`.

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

### Immutable mirror tag target

The current mirror publisher recreates the transformed tag with `git tag -f`,
force-pushes both the tag and mirror `main` on every run, and accepts
`workflow_dispatch` with an arbitrary or latest tag
(`publish-to-production.yml`). That behavior
is incompatible with R9 and must change, in a separately reviewed publisher PR,
before tag writes are enabled:

0. Every publisher trigger, including tag push and `workflow_dispatch`, first
   loads the owner window record for the requested tag and proceeds only if
   the tag and peeled SHA equal the persisted intended tag/SHA, the record is
   the one named by the `release-state` `current-window` pointer, and the record
   is `METADATA_MERGED` with that intended tag/SHA already persisted, `TAGGED`,
   or `PARTIAL`. Accepting the persisted pre-tag intent closes the race where
   a tag-push-triggered run reads the record before the owner's post-push
   `TAGGED` CAS. Otherwise it exits without any staging, mirror
   tag, mirror branch, or release write. After the `TAGGED` CAS, the owner
   verifies each required publisher run for the tag exists and dispatches any
   that exited early. A dispatch that defaults to "latest
   tag" resolves through the owner record, never through tag listing alone.
   The same gate applies to every downstream production writer, including
   `docs-production.yml` (both its `workflow_run` trigger and its manual
   dispatch, whose `force` option is removed). A `workflow_run` proceeds only
   when the upstream run concluded `success` and its run ID is recorded on
   `release-publication` under the `current-window` key as a successful
   publisher run for that tag; an
   upstream run that exited through this no-op path records nothing and so
   cannot activate downstream writes.
1. On the first publish attempt for a tag, the publisher builds the
   transformed mirror commit and pushes it to a durable source-repository
   staging branch `refs/heads/release-mirror/<tag>`. A creation-admission
   ruleset lists only the publisher App as a bypass actor, and a separate
   no-bypass ruleset restricts updates and deletion, so the branch is
   immutable once created (absent-or-exact) even for the publisher. It then
   appends the commit SHA and tree SHA to `release-publication` as
   `mirror_target` before any mirror push; the owner folds it into the
   window record.
2. Push the mirror tag only with absent-or-exact semantics: if the mirror tag
   is absent, create it at `mirror_target`; if it already resolves to
   `mirror_target`, treat the push as complete; if it resolves anywhere else,
   enter `FAILED` as a non-retryable fault and open an incident. Never use
   `-f`, `--force`, or
   delete-and-recreate for mirror tags.
3. On retry, fetch `mirror_target` from the staging ref instead of rebuilding
   it, because commit SHAs include parents, identities, and timestamps and are
   not reproducible. If the staging ref is missing or does not resolve to
   `mirror_target`, enter `FAILED`; never persist a new target under the same
   tag. If the staging push succeeded but the publication append was lost,
   the next attempt adopts the existing staging branch value as `mirror_target`.
4. Mirror `refs/heads/main` is updated only for the current owner window,
   with a lease: the expected prior tip is `mirror_main_tip`, the most recent
   successful mirror-branch update recorded by any earlier window regardless
   of its later state (`VERIFIED`, `RETIRED`, or otherwise), or the recorded
   initial mirror tip. After a successful branch push the publisher appends
      it to `release-publication` as the new `mirror_main_tip`. The push uses
   `--force-with-lease=refs/heads/main:<expected>` rather than an unconditional
   force. If the tip already equals this window's `mirror_target`, the step
   is complete. Any other tip, or a requested tag whose version is not higher
   than the latest `VERIFIED` or `RETIRED` version, enters `FAILED` without a
   write, so an older tag can never rewind production.
5. Mirror branch protection and rulesets remain enabled for the entire
   publish. The publisher must not disable, delete, or temporarily relax
   them; the only permitted bypass is a writer-admission bypass actor scoped
   to the trusted publisher identity. Deletion of mirror `main`, and update
   or deletion of mirror tags, is blocked by a separate no-bypass ruleset. A
   publish path that requires removing protection is `FAILED`.

`PARTIAL` is bounded. Each publisher or verification stage has an automatic
retry budget of three attempts per tag, with exponential backoff starting at
15 minutes. Attempt count, last error class, and run IDs are recorded in the
window record.

- A non-retryable fault enters `FAILED` immediately without consuming retries.
  Examples are a conflicting mirror tag target, an asset checksum mismatch
  against the persisted manifest, or a revoked production credential.
- An exhausted retry budget enters `FAILED` and opens or updates one incident
  issue linking the tag, window record, and failed run IDs.
- While the active tag is `TAGGED`, `PARTIAL`, or `FAILED`, no later window
  record is created. Releases are linear, so a newer tag cannot leapfrog an
  unverified one. `VERIFIED` and `RETIRED` release the hold.
- A `FAILED` window resumes the same tag (`FAILED -> PARTIAL`) only after a
  `/release-retry` remediation receipt, or is retired
  (`FAILED -> RETIRED`) by a `/release-retire` receipt. This is an
  incident-response control, not a routine review gate.
- Remediation command grammar: the entire comment body, after trimming
  surrounding whitespace, must be exactly one line matching
  `^/release-(retry|retire) v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$`.
  Quoted, fenced, prefixed, suffixed, or multi-line text never matches. The
  comment must be on the incident issue recorded in the `FAILED` window
  record, its version must equal that window's tag, its author must be a
  non-bot human with current `write`, `maintain`, or `admin` permission, and
  it must not have been edited. Each comment ID is consumed at most once and
  recorded in the window record; replaying it is a no-op.
- `/release-retry` resets the retry budget once per window.
- `/release-retire` performs the terminal `FAILED -> RETIRED` CAS transition
  and marks the source release as retired. The tag is preserved, never
  deleted or moved. `RETIRED` is accepted only from `FAILED`; the next window
  must select a higher version.

## Failure Modes and Recovery

| Failure | Required behavior |
|---|---|
| Missing authorization or only an approval/release label exists | `BLOCKED`; request a valid existing delivery authorization. |
| Merged PR lacks a valid delivery receipt, or its receipt digest/head no longer matches | Exclude with a recorded reason; never re-approve after merge or infer authority. If no eligible PRs remain, `NO_RELEASE`. |
| Receipt emission is not implemented in the merge-eligibility path | `BLOCKED`; implement and verify #3476 receipt emission before writes. |
| Tag baseline/history/inventory is incomplete or inconsistent | `BLOCKED`; preserve evidence and repair inventory source. |
| State ref is missing, inaccessible, malformed, stale, or compare-and-swap loses | `BLOCKED`; preserve the existing ref, re-read authoritative state, and reconcile without a stale overwrite. |
| #3595 policy is absent, incomplete, stale, or disagrees across stages | `BLOCKED` before tag creation; complete and verify the shared classifier. |
| Merge/check evidence or candidate tree is stale | Discard candidate and revalidate through the normal path. |
| Metadata version/changelog/manifest disagree | Do not tag; correct through a new protected metadata PR. |
| Token preflight is missing/failed | Do not tag; identify the missing permission/secret readiness without exposing credentials. |
| Concurrent duplicate attempts select same target | Serialize and resume the same state/tag; do not create a second tag. |
| Existing version tag resolves to a different SHA | `BLOCKED`; preserve the immutable tag and open an incident/remediation record. |
| Source release succeeds but mirror/assets/docs/smoke fail | `PARTIAL`; retry the failed same-tag stage within the retry budget and withhold the production-complete claim. |
| Mirror tag exists at a target other than the persisted `mirror_target` | `FAILED`; never force-update; open an incident. |
| Mirror staging ref is missing or differs from the persisted `mirror_target` | `FAILED`; never rebuild or persist a new target under the same tag. |
| Publisher triggered (push or dispatch) for a tag with no matching owner record (`METADATA_MERGED` with persisted intent, `TAGGED`, or `PARTIAL`) | Exit without any staging, mirror, or release write. |
| Mirror `main` tip differs from the leased expected tip, or the requested tag is not newer than the latest verified/retired version | `FAILED`; no branch write; production is never rewound. |
| `PARTIAL` retry budget exhausted or a non-retryable publish fault occurs | `FAILED`; hold later windows; resume only via `/release-retry` or retire via `/release-retire` from a qualified human. |
| No authorized release-worthy work exists | `NO_RELEASE`; report the complete inventory and do not create metadata or tag. |

## Security and Permissions

The workflow's default permissions are read-only. Separate the metadata PR
creation capability, source tag capability, and production mirror publisher.
Use repository-controlled workflow code on a trusted protected ref, least
privilege, environment protection where already required, and masked secrets.
Each state writer may update only its own dedicated protected ref
(`release-state`, `release-receipts`, or `release-publication`);
the tag writer may create only a new SemVer tag after revalidation. Neither
capability may force-update or delete refs; for the state and staging
branches this is enforced by the no-bypass immutable-history rulesets, not
by caller discipline. Untrusted PR code never runs
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
| R2 | Test receipt grammar, emission before merge, head binding, `appendReceipt` absent-or-exact behavior per digest (identical replay succeeds, a renewed authorization for the same head appends a new digest and the greatest `auth-cutoff` wins, equal cutoffs exclude as ambiguous, appends after merge are rejected, appends succeed before any window and while a tag is `TAGGED`/`PARTIAL`/`FAILED`), and `Closes #N` source-issue closure (window still derives with no post-merge edit); opt-out scopes are excluded; XXL is eligible only with a recorded qualified current-head approving review; deleted/edited approval comments, removed `approved` label, downgraded approver permission, edited source issue body (hash or `lastEditedAt` differing from the receipt), an approval comment edited and restored (same hash, changed `updated_at`), removed `type:*`/`priority:*` metadata, a blocker label added to the closed source issue, a reopened dependency, or dismissed XXL review exclude the PR and change `window_key`, mark the superseded record `BLOCKED`, and advance the `current-window` pointer so a stale record with persisted intent cannot publish; paginate past API page boundaries; reconcile every PR merge SHA through the frozen candidate; missing pages or mismatches block. |
| R3/R7 | Test SemVer bump classes, intervening releases, complete no-op inventory, consumer-visible docs-only patch, and internal-only docs disposition. |
| R4 | Metadata mismatch, unmerged PR, stale base, and failed integrated check prevent tag creation; exact merged SHA succeeds. |
| R5 | Revoke/change authority, stale check/label evidence, absent #3595 implementation, cross-stage classifier disagreement, or failed/missing token preflight between candidate and tag; each blocks. |
| R6 | Restart after every state transition; run two independent writers from the same expected ref; exercise lost write responses, stale revision/digest, branch movement, and repeated retries. Exactly one CAS advances; same-SHA existing tag resumes; different-SHA target blocks without mutation. Metadata PR head updates advance revisions under the same `window_key` while in `CANDIDATE`; a version change or post-`METADATA_MERGED` metadata change is rejected under that key, and a correction over the same inventory activates `generation` N+1 while generation N becomes `BLOCKED`/`superseded`. Each of `release-state`, `release-receipts`, and `release-publication` accepts updates only from its single writer identity; a direct Git/API update by any other identity (including the other two writers and `GITHUB_TOKEN`), a force update, or a deletion is rejected by the ruleset. Each writer App, despite its admission bypass, is rejected when it force-updates or deletes its own branch, and the publisher cannot update an existing `release-mirror/<tag>` branch. The broker refuses tokens to any workflow path, ref, event, or `job_workflow_sha` outside the writer's binding (including a different workflow requesting the same environment, and a reachable but stale workflow revision whose SHA-256 differs from the current `policy-packs.json` binding, such as a dispatch at an older tag). The `release-mirror/<tag>` staging branch rejects a second creation or any update. Publisher results for a non-current window are ignored when the owner folds them. |
| R8/R9 | Missing source asset, checksum mismatch, absent mirror release, failed smoke, and partial publish remain `PARTIAL`; same-tag retry can complete. Mirror tag absent creates at `mirror_target`; exact match resumes; different target fails without a push; no `-f`/`--force` on tag refs; retry after runner-local object loss fetches `mirror_target` from the staging ref; lost publication append after staging push adopts the staged value. Dispatch with an arbitrary, older, or "latest" tag lacking a matching `METADATA_MERGED`-with-intent/`TAGGED`/`PARTIAL` record performs no write; `docs-production.yml` via `workflow_run` from a no-op or unrecorded upstream run, or via manual dispatch without a matching record, performs no write; a tag-push run that reads the record before the `TAGGED` CAS proceeds on persisted intent, and the owner re-dispatches any publisher that exited early; mirror `main` leases on the last recorded `mirror_main_tip`, including one advanced by a later-retired window, and an older tag or unexpected tip fails without rewinding. Exhausting three retries enters `FAILED` and holds later windows; `/release-retry` (`FAILED -> PARTIAL`) resets once; `/release-retire` (`FAILED -> RETIRED`) preserves the tag, releases the hold, and permits only a higher version; `RETIRED` from any other state is an illegal transition; remediation commands that are quoted, fenced, prefixed, suffixed, multi-line, edited, on another issue, for another version, or by an unqualified or bot author are rejected, and a replayed comment ID is a no-op; mirror protection stays enabled throughout and a path that would disable it fails. |
| Credential event path | Prove the chosen narrow credential triggers the actual downstream tag workflows without exposing token data or running untrusted code. |

Run repository workflow syntax validation, focused release-owner contract
tests, release/token/publish workflow tests, the state adapter and per-ref
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
