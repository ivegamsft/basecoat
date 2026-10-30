# Technical Specification: Roadmap Race-Safe Persistence and Plan Authority

## Context

Source: [#3616](internal source issue), child of
closed parent [#3400](internal source issue). Controlling documents: the parent
[roadmap synthesizer spec](synthesized/issue-3400-roadmap-synthesizer-auto-group-issuesprs-into-release-milest.spec.md)
and the [persistence decision](../design/roadmap-persistence-decision.md), in
which the owner selected option A (GitHub milestones remain canonical).

Already on `main` and not repeated here:

- `scripts/roadmap/plan.py`: inventory, SemVer baseline, digest, pin guards,
  storage steps, pure approval check and ordering modes (#3621, #3624).
- `scripts/roadmap/preview.py`: supplied mapper/advisor evidence validation,
  all/label/theme/issue-set selection, unambiguous PR linkage, residuals,
  deterministic Markdown preview, local immutable SQLite checkpoints and an
  unconditional live-write gate (#3648).
- `tests/roadmap-preview-tests.py`: mocked race and replay model (#3700).

This proposal covers the remaining #3616 acceptance, all needing live writes:
milestone/assignment persistence, one-time plan approval, remote checkpoints
and the artifact bot PR. Merging it approves nothing and enables no write.

## Verified capability evidence

Re-verified by read-only GraphQL introspection on 2026-10-12 against `main`
`97d7a1c4e7580c21b465909e91ef4aa31387f186`:

| Primitive | Conditional field | Consequence |
| --- | --- | --- |
| `UpdateIssueInput.milestoneId` | None (`clientMutationId` is correlation only) | Item assignment cannot reject a stale read. |
| `UpdateMilestoneInput` | Type absent; REST milestone PATCH documents no precondition | Marker/pin edits cannot reject a stale read. |
| `CreateCommitOnBranchInput.expectedHeadOid` | Expected branch head | Git commits on a bot branch can reject a stale head. |
| `UpdateRefInput` | `force: false` only (fast-forward) | Not a full compare-and-set; not used for authority. |

REST guidance excludes conditional unsafe methods unless an endpoint documents
them: Git branch commits support compare-and-set; milestone and issue writes do not.

## Scope

1. A sandbox-only live API contract probe for stale-write rejection.
2. A remote authority ledger on a dedicated bot branch for one-time plan
   approval consumption, run ownership and resumable checkpoints, using
   `expectedHeadOid` as the only concurrency primitive.
3. A roadmap artifact publisher that maintains `docs/reference/roadmap.md`
   on a stable bot branch and PR through existing admission gates.
4. A milestone/assignment adapter implementing the #3700 contract, compiled
   in but disabled by a gate that only probe evidence can satisfy.

## Out of Scope

- Workflow triggers, `roadmap:` routing and autopilot `roadmap_order`
  (#3617); release-set validation and tag/release creation (#3618).
- Canonical membership in Git (decision option B) or exclusive-writer
  conventions (option C). The ledger stores authority and progress only;
  GitHub milestones remain the membership source.
- Production milestone, assignment or Projects writes before the gate opens.
- Changing merge queue, release gate, `main` protection or approval policy.

## Architecture Overview

| Component | Location | Writes | Default |
| --- | --- | --- | --- |
| Contract probe | `scripts/roadmap/contract_probe.py` | Sandbox repository only | Refuses any non-allowlisted repository |
| Authority ledger | `scripts/roadmap/ledger.py` | Branch `bot/roadmap-state` via `createCommitOnBranch` | Dry-run; prints intended commit |
| Artifact publisher | `scripts/roadmap/artifact.py` | Branch `bot/roadmap-artifact` and one PR | Dry-run; prints rendered file and diff |
| Milestone adapter | `scripts/roadmap/persist.py` | Milestones and `milestoneId` | Gate raises `live-writes-disabled` |

All components consume the existing `plan.build_plan`/`preview.normalize`
result and digest; none re-derives grouping. The ledger and artifact branches
are never `main`, never force-updated and never merged directly.

## Data Model and Storage Changes

Ledger branch `bot/roadmap-state` holds one JSON file per run,
`runs/<repository-slug>/<run_id>.json`, schema 1:

- `repository`, `run_id`, `plan_digest`, `evidence_digest`, `scope`, `bounds`.
- `approval`: `null` until consumed; then actor login, actor database ID,
  permission observed at consumption, source comment ID and URL, and digest.
- `owner`: fencing `epoch`, holder (workflow run ID and attempt) and
  `lease_expires_at`, kept in one repository-wide `lease.json`, so at most one
  run holds it; consume and claim fail `repository-lease-held` otherwise.
- `steps`: ordered storage steps from `plan.storage_steps` with status
  `pending|claimed|done|conflict|failed`, the claiming `epoch`, observed
  pre-write state and response evidence (status code and sanitized error code
  only).
- `stop_reason` and `blockers`.

No issue or comment bodies, tokens or untrusted free text are stored. Run files
are never deleted; each consumed approval is a permanent tombstone.

`docs/reference/roadmap.md` is the existing `preview.render` output with the
lifecycle column driven by ledger state (`proposed`, `approved`,
`persisted`, `conflict`). Identical state produces identical bytes.

## API and Interface Contracts

### Contract probe

`contract_probe.py --repo <owner>/<sandbox> --confirm-sandbox <owner>/<sandbox>`
runs only when the repository equals the confirmation value and is listed in
`scripts/roadmap/probe-allowlist.json`, which must not contain this repository.
It creates probe milestones and an issue, reads them, applies an external
change, then replays the original write against the stale read for each case:

1. Milestone description edit (marker/pin) after an external description edit.
2. Issue `milestoneId` change after 2a an external milestone reassignment and
   2b an external `roadmap:pinned` label change; unrelated edits do not count.
3. Cross-resource subcases from the #3700 read set
   (`docs/design/roadmap-grouping-preview.md`): an issue `milestoneId` change
   after 3a the source or 3b the target milestone's pin or marker changed.
4. Concurrent create: two writers that both observed no managed marker create
   the same key.

Each case first runs a fresh (non-stale) control write that must succeed. A
case is `positive` only when the stale write fails with an attributable
stale-state or uniqueness conflict; 403, validation, rate-limit, 5xx and
transport failures are `inconclusive` and never enable the gate. It records
`positive|negative|inconclusive` per case with API surface and timestamps, and
deletes only probe resources it created (matched by a per-run marker).

### Authority ledger

- `ledger.py propose`: creates a new run file with `approval: null`; it fails
  `run-exists` if the path exists. Run files change only by validated forward
  transitions (proposed, approved, claimed, terminal) and are never reset.
- `ledger.py consume --comment-id <id>`: fetches the comment server-side,
  requires the exact body `roadmap: approve <run_id> <plan_sha256>`, fetches the
  author's current repository permission (`write|maintain|admin`), recomputes
  the plan from a fresh inventory, and requires an identical digest, scope and
  bounds. It then commits approval and owner in one commit with
  `expectedHeadOid`. A rejected head re-reads; an existing approval, or a run
  ID or comment ID in any tombstone, fails `approval-already-consumed`.
- Triggers other than a human issue comment (schedule, label, merge, bot
  actor, workflow dispatch without a comment) return `unauthorized-approval`.
- `ledger.py claim --step <n>`: before each mutation, commits the step as
  `claimed` with the holder's `epoch` and a renewed lease, binding
  `expectedHeadOid`. `ledger.py checkpoint` records the outcome the same way.
  A rejected head re-reads; if `epoch` changed, the holder has been fenced and
  makes no further claim. The epoch cannot fence a request already in flight.
- `ledger.py takeover`: a replacement run or attempt for the same `run_id`
  may become holder only after `lease_expires_at` has passed, by committing
  `epoch + 1` with `expectedHeadOid`. Exactly one takeover wins. If any step
  is `claimed` (outcome unknown), takeover sets `needs-reconciliation` and
  stops; only manual reconciliation by a repository writer can resolve it.
  Approval is not re-consumed on takeover.

Provenance prerequisite: a ruleset on `bot/roadmap-state` must block deletion
and non-fast-forward updates and restrict updates to the roadmap GitHub App.
Without it the ledger is not authority and consume fails
`ledger-provenance-unproven`. Consume, takeover and every gate check verify
the ruleset and that every commit in branch history is app-authored and
verified, scan that full history (not the current tree) for consumed run and
comment IDs, and re-verify source comment, author ID, permission and digest.

Ledger root bootstrap (operator provisioning, #3882): the ledger root is the
oldest commit of `bot/roadmap-state`, which must be parentless, app-authored
and verified; no other commit in its history may be parentless. A branch
created from `main` inherits human history and never passes provenance. To
provision, the owner first creates the ruleset above, then runs
`ledger.py bootstrap --repo <owner>/<repo> --apply` with the roadmap App's
installation token and `ROADMAP_APP_SLUG`/`ROADMAP_APP_ID` set. It refuses
an existing branch (`ledger-branch-exists`) and uses the Git data API
(tree, commit with no parents and no custom author, then ref) to commit
`ledger-root.json` (schema, repository, branch). It then re-runs the
provenance check; an unsigned root or a ruleset changed after it fails
`ledger-provenance-unproven` and must be re-provisioned by the owner.
Without `--apply` it creates no commit and only prints the proposed
`ledger-root.json` payload (`dry_run`, `create_root`, `files`).

### Artifact publisher

Before any branch or PR write it requires a consumed approval for the exact
run and digest, re-verified like the gate below; it then commits on change,
with `expectedHeadOid`. It opens or updates one PR to
`main` titled `docs(roadmap): refresh roadmap artifact` and never enables
admin bypass. A conflicting head re-reads and re-renders; a closed unmerged
PR is reported, not reopened automatically.

### Milestone adapter and enablement gate

`persist.py` executes `plan.storage_steps` in order, re-reading target
milestone and item immediately before each mutation and after it, and records
each step in the ledger before moving on. Upsert is by managed marker; a lost
create response re-lists by marker and accepts exactly one record. Re-listing
detects duplicates only after the fact, so it is recovery, not protection:
create steps are additionally gated on probe case 4.

The gate opens only when all are true: the ledger shows a consumed approval
for the exact digest held by the current run and epoch; the recorded source
comment, author and current permission re-verify as above; the flag
`roadmap_persistence_enabled` is `true`; and the committed probe evidence file
`docs/reference/roadmap-contract-probe.json`, recorded within 30 days, shows a
`positive` result for every case covering the step types in the plan. Assign
steps require 2a, 2b, 3a and 3b (atomic protection of the full read set:
item plus source and target milestone state); any missing subcase fails.
Create steps require case 4; marker or pin edits require case 1. The gate is
closed on current evidence; a flag, approval, label or mock never opens it.

## Security and Privacy Considerations

- Ledger and artifact jobs need `contents: write` and `pull-requests: write`
  on bot branches only; milestone writes need `issues: write` and stay in a
  separate job that is not scheduled while the gate is closed.
- Probe credentials are scoped to the sandbox repository; the production
  token is never passed to the probe.
- Approval identity is resolved from GitHub by comment ID; comment text is
  never executed. Permission is read at consumption time, not cached.
- Logs and ledger contain numbers, digests, login, IDs and error codes only.

## Reliability and Failure Modes

| Failure | Required behavior |
| --- | --- |
| Ledger head changed | Re-read; revalidate digest and approval state; never overwrite. |
| Lost response after ledger commit | Re-read branch; accept the commit if content matches, otherwise fail. |
| Duplicate or replayed approval | `approval-already-consumed`; no second owner. |
| Holder crash or lost lease | After lease expiry, one `takeover` wins with `epoch + 1`; a `claimed` step forces `needs-reconciliation` and manual review. |
| Fenced holder resumes | Its next claim or checkpoint fails on head/epoch; no further claim. |
| Forged or edited ledger approval | Source comment, author or permission fails re-verification; gate stays closed. |
| Digest, scope or bounds changed after approval | `stale-or-mismatched-approval`; new dry-run plan required. |
| Probe case missing, expired or negative | Gate stays closed; report `github-conditional-mutation-not-proven`. |
| Milestone pre-write read shows pin/ownership/assignment change | Mark step `conflict`; stop affected release; no write. |
| Artifact PR blocked by checks or queue | Keep ledger state; report; resume on next run. |
| Transient 5xx or rate limit | Existing autopilot backoff; bounded attempts recorded. |

## Performance and Capacity Considerations

One ledger commit per transition; one artifact commit per changed render.
Workflows also share one repository concurrency group without cancellation.

## Implementation Plan

Each unit is an independent PR of at most 15 files and 300 changed lines.

1. Ledger module with mocked `createCommitOnBranch` transport and tests.
2. Approval consumption, epoch-fenced claims and lease takeover, with tests.
3. Artifact publisher (dry-run default) with mocked transport and tests.
4. Contract probe and allowlist; owner runs it against a sandbox and commits
   evidence through a normal PR.
5. Milestone adapter behind the gate; tests prove the gate stays closed with
   negative or missing evidence and that #3700 scenarios pass on the adapter.

Units 1-3 do not depend on probe results. Unit 5 may merge with the gate
closed; enabling it requires positive evidence and a separate owner decision.

## Testing Strategy

- Ledger: stale head rejection, concurrent consumption (one winner), lost
  response replay, replayed or superseded approval, re-propose reset,
  tombstone reuse, rewritten history or missing ruleset (all rejected),
  non-human trigger, insufficient permission, changed digest/scope/bounds,
  forged ledger approval rejected at the gate, concurrent takeover (one
  winner), fenced stale holder, and claimed-step takeover reaching
  `needs-reconciliation`.
- Artifact: byte-stable render, no-op on identical state, stale head,
  closed PR, missing or stale approval (no write), never pushes to `main`.
- Lease: a second run cannot consume or claim while another holds it.
- Probe classifier, for every case and subcase: only an attributable
  stale-state or uniqueness conflict is `positive`; an applied stale write is
  `negative`; control-write failure, 403, validation, rate-limit, 5xx and
  transport errors are `inconclusive`. Unconfirmed repositories are refused
  and only the probe's own marked resources are cleaned up.
- Adapter: reuse #3700 race and replay scenarios; gate closed for missing,
  stale or negative evidence, for flag-only or approval-only input, for
  assign steps missing any of 2a, 2b, 3a or 3b, inconclusive results, and
  for create steps without the concurrent-create case.
- Existing `roadmap-plan-tests.py` and `roadmap-preview-tests.py` unchanged
  and passing; new suites wired into `tests/run-tests.ps1`.

## Rollout, Migration, and Rollback Plan

Operator setting locations, App identity, bot-branch prerequisites, sandbox
configuration and write gates are documented in the
[delivery automation settings guide](../operations/delivery-settings.md).

Ship units 1-3 in dry-run, then enable ledger and artifact writes on bot
branches only. Milestone writes remain disabled. No migration: existing
milestones are never adopted. Rollback disables the flag and stops new runs;
ledger receipts are retained; the artifact is reverted through a normal PR;
milestones and assignments are never bulk-deleted or cleared.

## Observability and Operational Readiness

Run summaries print run ID, digest, approval, ledger head, step counts, gate
state and reason, and artifact PR URL, using the failure-table error codes.

## Risks and Mitigations

- **Option A may never be enable-able**: GitHub currently offers no
  conditional milestone or assignment write. Mitigation: gate stays closed;
  #3616 can only close for its non-milestone acceptance if the owner splits
  or amends acceptance.
- **Ledger perceived as membership**: it stores authority and progress only;
  tests assert no membership is read from it.
- **Bot branch tampering by writers**: ruleset-enforced app-only, append-only
  history plus full-history scans; without the ruleset, consume fails closed
  and ledger content alone never authorizes.

## Open Questions

Owner decisions required before implementation:

1. Approve units 1-3 (bot-branch ledger and artifact) as an authority and
   checkpoint store that does not change option A membership semantics, and
   the app-only, no-deletion, no-force ruleset on `bot/roadmap-state`.
2. Approve running the contract probe against an owner-provided sandbox
   repository, and name that repository.
3. If the probe is negative (expected), choose between keeping #3616 open
   with milestone writes permanently gated, or splitting milestone
   persistence into a new blocked issue so #3617 and #3618 can proceed on
   dry-run ordering only.

## References

- [Persistence decision](../design/roadmap-persistence-decision.md) (#3694, #3695).
- [Grouping preview design](../design/roadmap-grouping-preview.md) (#3648, #3700).
