---
issue: 3400
title: "Roadmap Synthesizer: auto-group issues/PRs into release milestones and drive roadmap-ordered execution"
status: implementation-ready
author: ibuyspy
created: 2026-10-06
labels: ["enhancement", "priority:medium"]
---

# Technical Specification: Roadmap Synthesizer

## Context

Issue #3400 closes the gap between manual release grouping and the existing
oldest-first backlog loop. The generated PR #3401 was closed because its
auto-synthesized files omitted the approved design. This document replaces
those placeholders, incorporating the issue description and its
human-kickoff `roadmap:` refinement. This PR delivers specification only; it
does not authorize production writes, implement the feature, or close #3400.

## Scope

- A thin `roadmap-synthesizer` orchestrator, a new `roadmap:` intent/routing
  entry, and a scheduled/event-driven reconciliation workflow.
- Deterministic release grouping, milestone assignment, roadmap artifact,
  approval/resume contract, and roadmap-ordered autopilot mode.
- SemVer release completion through existing merge/release gates, extended
  only where necessary to scope a cut to one approved milestone.

## Out of Scope

- Reimplementing clustering, dependency parsing, wave building, CI/merge
  eligibility, release-gate policy, or release publication.
- Automatically closing issues/milestones, changing issue content or
  dependencies, changing branch protection, or cutting tags from the
  synthesizer workflow.
- Making scheduled reconciliation an execution authorization.

## Architecture Overview

| Concern | Existing/new component | Contract |
| --- | --- | --- |
| Intent and run lifecycle | New `roadmap-synthesizer` orchestrator; `ship-it-control-loop` | Owns scope, bounds, run ID, phase order, checkpoint, stop/resume only. |
| Cluster evidence | `sprint-project-mapper` | Supplies normalized groups, split/merge rationale, significance, and residuals; it does not write milestones. |
| Release classification | `release-impact-advisor` | Recommends ordered SemVer impact and risks; it does not publish or authorize a tag. |
| Dependency readiness | `dependency-relationship-routing.yml`; `issue-triage` | Existing blocker labels and live issue/PR state are read, not rewritten by roadmap logic. |
| Within-release ordering | `sprint-planner`; `build-waves.ps1`; `backlog-autopilot` | Pass only the earliest eligible milestone's issue set to the existing dependency-topological wave builder. Linked PRs travel with their issue; unlinked PRs are residual and block silent execution. |
| Durable state | GitHub milestones and issue/PR milestone fields | Canonical assignment and lifecycle state; deterministic marker/key described below. |
| Reviewable snapshot | `docs/reference/roadmap.md` | Stable sorted rendering of current state, maintained by an idempotent bot PR through existing checks/merge queue. Never commit directly to `main`. |
| Release completion | `post-merge-release-chain`; existing release gate; milestone-scoped `release-manager` | Existing checks remain authoritative. A milestone is shipped only after the scoped tag/release is verified. |

The new reconciliation workflow uses the dependency router's event surface
(issue `labeled`/`closed`, pull request `closed`, scheduled, and manual
dispatch), plus a shared repository-scoped concurrency group with
`cancel-in-progress: false`. It reads live blocker state and relationship
markers; it does not assume workflow ordering or consume stale labels as the
only dependency evidence. Use the same scheduled cadence as dependency routing
(`0 9 * * 1` UTC). Do not run untrusted pull-request code in a privileged
`pull_request_target` job.

## Data Model and Storage Changes

1. A managed milestone has a stable description marker
   `<!-- basecoat-roadmap:v1 key=vX.Y.Z -->` and title `Release vX.Y.Z`.
   The key is the normalized SemVer release, not a model-generated title or
   run ID. There is at most one open managed milestone per key. The marker is
   preserved when human-readable description text is updated.
2. `<!-- basecoat-roadmap-pin:v1 -->` in a milestone description pins that
   milestone's membership and relative release position. A milestone without a
   valid managed marker is human-owned and is never renamed, closed, reordered,
   or adopted. An item with label `roadmap:pinned`, or assigned to a human-owned
   or pinned milestone, is never reassigned. Existing managed assignments may
   move only when the item is not pinned and the approved reconciliation
   explicitly changes its release.
3. Run state is keyed by repository and stable `run_id`; each persisted
   checkpoint records scope selector, parameters, phase, plan digest,
   milestone numbers, completed release/tag, and unresolved blockers. The
   canonical plan digest is SHA-256 over canonical JSON with sorted issue/PR
   numbers, normalized scope, ordered SemVer keys, assignments, and bounds.
   Exclude timestamps and display-only text from the digest.
4. `roadmap.md` renders release milestones in SemVer order, items numerically,
   and residuals/pins/blockers in separate sections. It includes plan digest,
   lifecycle state, and verified tag URL. The run ID remains in the checkpoint,
   not in the generated page. Identical state produces identical content;
   volatile timestamps are omitted.

## API and Interface Contracts

### Intent and parameters

```text
roadmap: <all|label:<name>|theme:<text>|issue-set:#N,#M>
  [max_releases=1] [concurrency=1] [dry_run=true]
  [pace=<autopilot-config>] [stop_conditions=<existing-control-loop-values>]
roadmap: approve <run_id> <plan_sha256>
roadmap: resume <run_id>
```

- `dry_run` defaults to `true`; dry-run performs reads and emits the proposal
  only. It must not create/update milestones, assign items, open a roadmap PR,
  dispatch execution, or publish a tag.
- `max_releases` is a positive bound and defaults to `1`; `concurrency` defaults
  to the existing autopilot value (`1`); merge serialization remains one PR in
  flight. `pace` and `stop_conditions` use existing control-loop/config
  semantics. Reject malformed, non-positive, or over-policy values explicitly.
- Approval is a one-time authorization for the exact repository, run ID,
  digest, scope, and bounds. Accept it only from an authenticated repository
  writer/maintainer; consume it atomically before the first write. Recompute
  the digest immediately before application; mismatch invalidates approval.
  Scheduled reconciliation can never create or consume approval.
- No per-item/per-release approval is added for XS-XL. Existing merge-queue,
  check, release-gate, and XXL policy remain unchanged.

### Selection and grouping

- Scope selects open issues. Include an open PR only when it has an unambiguous
  linked issue in scope; assign it to that issue's release. An unlinked or
  ambiguously linked PR is reported as residual and is not executed.
- Run mapper normalization and split/merge debate on the selected issue/PR set.
  Apply the mapper's significance rules. Sub-threshold items must remain
  visible as residuals; merge into another group only when the mapper's
  documented similarity threshold is met. Do not invent a release category for
  residual work.
- Ask the release advisor to recommend the ordered SemVer releases from the
  current version/tag and evidence. Reject duplicate, invalid, non-monotonic,
  or already-existing tag versions. A changed classification is a new plan,
  not an in-place rename of a human-owned milestone.
- `sprint-planner` maps dependencies and milestone scope; the dependency
  workflow remains the source for blocked labels. `build-waves.ps1` remains
  the source for issue dependency topology, including its native sub-issue and
  body-reference fallbacks.

### Persistence and idempotency

- Use one repository-wide workflow concurrency key for all synthesizer writes;
  never cancel an in-progress writer. Before every mutation, re-read the target
  milestone/item and plan digest. If a human-owned milestone, pin, or changed
  assignment is observed, preserve it and report a conflict.
- Upsert by managed marker/key, not by title alone. After a create timeout or
  conflict, list and re-read the marker before retrying. Reuse one matching
  record; if zero or multiple authoritative records remain, stop with an
  actionable error instead of creating a duplicate.
- Reassign only an unpinned item whose current assignment is empty or is a
  valid managed milestone. Never move an item out of a human-owned or pinned
  milestone. Re-read after a write; on divergence, do not overwrite again.
- GitHub has no transaction spanning milestone, item, and roadmap PR writes.
  Apply a deterministic plan as resumable idempotent steps, record each
  completed step, and report partial progress. Retry only transient
  rate-limit/5xx failures with existing autopilot backoff. Permission,
  validation, plan-digest, pin, and ownership conflicts fail closed.

### Roadmap-order mode and fallback

- Add `roadmap_order=required|prefer|off` to autopilot. Default `off` preserves
  all current behavior and existing `build-waves.ps1` ordering.
- `required` selects the earliest open, approved managed milestone by SemVer,
  filters the issue input to that milestone, then invokes the existing wave
  builder. A blocked/cyclic earliest milestone pauses the roadmap; it cannot
  be skipped in favor of a later release.
- An open human-owned or pinned milestone whose position cannot be established
  relative to the approved managed sequence is a barrier: pause rather than
  reorder it or advance past it.
- `prefer` uses the same ordering when a unique, valid approved roadmap exists.
  If no active approved roadmap exists, fall back to today's oldest-first,
  dependency-topological build and emit `ordering=fallback-oldest-first` plus
  the reason in the checkpoint. Invalid, conflicting, pinned, or stale
  roadmap state is not treated as absence: stop and report it.
- `off` does not read or mutate roadmap state. `roadmap:` execution always uses
  `required`; it never silently falls back.
- Within a release, open dependencies outside the milestone remain blockers.
  `build-waves.ps1` must retain its fail-closed behavior on dependency lookup
  failure and its documented body-reference fallback when native sub-issues
  are unsupported.

## Release Semantics

1. A planned milestone is not a shipped release. Do not close it or advance the
   roadmap because all issues are closed alone: every linked PR must be merged,
   required checks and the existing release gate must pass, and the exact
   release tag/GitHub release must exist.
2. Execute milestones strictly in planned SemVer order, one release cut at a
   time. Serialize merges through the native merge queue and preserve existing
   `pace`, freeze, stop, and retry gates. After a cut, verify tag/version and
   release URL before recording `shipped`; then regroup remaining approved
   scope, including matching arrivals within the original selector/bounds.
3. `release-manager` currently selects all merged PRs since the previous tag.
   Add a milestone-scoped input containing milestone number, exact merged PR
   IDs, prior tag, planned version, and approved plan digest. Before cutting,
   compare the complete merged-PR set since the prior tag with the selected
   release set. If any out-of-scope or unaccounted PR exists, stop and report
   it; do not produce a misleading tag. The computed version must equal the
   approved planned version, and the tag must not already exist.
4. The synthesizer never pushes a tag or bypasses the existing
   `post-merge-release-chain`/release gate. A release failure leaves the
   milestone open with `release-blocked` state, preserves completed work, and
   resumes only after the gate or scope conflict is resolved.

## Security and Privacy Considerations

- Grant read-only permissions to planning; isolate write jobs and grant only
  `issues: write` for milestone/assignment updates and `contents: write` plus
  `pull-requests: write` for the roadmap artifact PR. Do not store PATs or
  expose tokens to agents, PR code, logs, or roadmap content.
- Execute trusted workflow code from the base branch only. Treat issue,
  comment, label, PR title/body, and model output as untrusted data; validate
  numbers, repository ownership, SemVer, URLs, scope, bounds, and every API
  response. Never evaluate user text as shell/code.
- Only an authenticated repository writer/maintainer may approve a matching
  plan digest. Do not infer approval from a label, issue closure, PR merge,
  dry-run, or previous run.
- Do not mutate any human-owned/pinned milestone. On any ambiguity in marker,
  ownership, approval identity, or release contents, stop before the next
  write/cut and emit a sanitized diagnostic.

## Reliability and Failure Modes

| Failure | Required behavior |
| --- | --- |
| API throttling or transient 5xx | Back off using autopilot policy; resume idempotently; expose attempts and final status. |
| Create response lost / duplicate marker found | Re-read by marker; accept exactly one canonical record; otherwise fail without a second create. |
| Approval digest or scope changed | Invalidate approval; emit a new dry-run plan; perform no writes or execution. |
| Human pin/assignment or managed-state conflict | Preserve live state, mark conflict/residual, and stop affected release; never auto-correct it. |
| Dependency lookup failure, cycle, or earlier milestone blocked | Fail closed and pause; do not advance to later milestones. |
| Roadmap PR, merge queue, or release gate unavailable | Keep durable state, report partial progress, and resume; no direct-main commit or tag bypass. |
| Release set/version/tag mismatch | Do not tag or close milestone; report exact extra/missing PRs or version mismatch. |

## Performance and Capacity Considerations

Bound each run by `max_releases`, existing `concurrency`, wave size, API
burst pacing, and retry limits. Reuse paginated/cached read results within one
run; do not fan out concurrent writes. Exceeding a bound checkpoints and stops
cleanly for resume.

## Implementation Plan

1. Add deterministic pure planning/hash/pin tests and a mocked GitHub
   persistence adapter; prove conflicting and repeated requests before enabling
   writes.
2. Add the thin orchestrator, issue/PR linkage and managed-milestone
   persistence, workflow triggers/permissions, and roadmap artifact PR.
3. Add `roadmap:` intent routing and autopilot `roadmap_order` modes. Keep
   default mode `off`; run existing wave-builder tests unchanged.
4. Add milestone-scoped `release-manager` input and release-set checks; wire
   only through current merge/release gates.
5. Validate with unit, API-contract, workflow, failure-injection, and
   end-to-end tests, then shadow with dry-run before opt-in write/execution.

## Testing Strategy

- Golden tests: same normalized input in different API orders yields identical
  digest, milestone keys, roadmap rendering, and SemVer sort.
- Idempotency/replay: run twice; simulate timeout after create/assignment and
  resume; assert exactly one managed milestone, no duplicate assignment/tag,
  and identical result.
- Pin/ownership: label-pinned item, pinned milestone, unmarked milestone,
  concurrent human assignment, duplicate marker, changed plan digest; assert
  zero destructive writes and explicit conflict.
- Scope/grouping: significant and sub-threshold mapper groups, similarity
  boundary, residual/unlinked PR, issue-set/label/theme/all selectors, matching
  arrivals, and out-of-scope arrivals.
- Ordering: SemVer order differs from title/creation order; blocked earlier
  release; dependency cycles; unmet cross-milestone dependency; native
  sub-issue unsupported fallback and total lookup failure.
- Release contract: exact milestone PR set, unrelated merged PR, wrong/duplicate
  version, no merged PR, failed checks/release gate, lost tag response, and
  successful verified tag. Assert no premature milestone close or later
  milestone start.
- Compatibility/security: existing autopilot tests and default oldest-first
  output unchanged; `prefer` reports its fallback; `required` fails closed;
  dry-run makes zero writes; unauthorized/malformed approval is rejected;
  untrusted PR data is never executed.

## Rollout, Migration, and Rollback Plan

- No migration is required; unmanaged milestones are never adopted. Additive
  managed markers and assignments are created only after exact plan approval.
- Initially keep `roadmap_synthesizer_enabled=false`; exercise schedule and
  event triggers in dry-run and compare output with curated milestones.
- Enable writes only after replay, pin-protection, artifact-PR, and
  milestone-scoped release tests pass. Enable execution only for an approved,
  bounded run. Existing `autopilot:` callers remain in `off` mode.
- Roll back by disabling the workflow/intent. Do not bulk-delete milestones or
  clear assignments; retain audit records and revert the roadmap artifact via
  a normal PR. Completed tags/releases are immutable and require the existing
  release rollback procedure.

## Observability and Operational Readiness

Each run summary and `ship-it-control-loop` checkpoint records run ID, plan
digest, trigger, scope, ordering mode/fallback reason, release and milestone
keys, item counts (assigned/pinned/residual/blocked), API retries, completed
steps, tag/release URLs, and stop reason. Emit structured error codes for
permission, conflict, stale-plan, dependency, queue, and release failures.
Alert only on failed execution or unreconciled partial writes; dry-run
residuals remain visible in the roadmap. Never log token values or full
untrusted issue/comment bodies.

## Risks and Mitigations

- **Partial GitHub writes:** no cross-resource transaction; mitigate with
  repository serialization, stable keys, pre-write reads, checkpoints, and
  replay tests.
- **Pin race:** GitHub event writers can be external to the workflow lock; use
  conditional updates against the fetched resource version where supported,
  re-read immediately before each update, never move an item from an unmanaged
  milestone, preserve explicit pins, and stop on observed divergence. The live
  API contract test must prove a stale update is rejected; if it cannot, keep
  writes disabled until an equivalent compare-and-set mechanism is available.
- **Release manager's broad PR query:** exact milestone/tag scope is a release
  blocker until the scoped input and out-of-scope PR test are implemented.
- **Model classification drift:** require deterministic validation, digest
  approval, stable SemVer keys, and no release action from advisor output
  alone.
- **Unlinked work:** retain it visibly as residual; never silently omit it or
  execute it outside the approved milestone.

## Open Questions

None for the specified behavior. If GitHub's live API cannot safely distinguish
or revalidate a concurrent milestone edit, the persistence adapter must fail
closed rather than weaken pin protection.

## References

- PRD:
  `docs/prd/synthesized/issue-3400-roadmap-synthesizer-auto-group-issuesprs-into-release-milest.prd.md`
- Source issue and approved refinement: [#3400](https://github.com/IBuySpy-Shared/basecoat/issues/3400)
- Closed premature placeholder PR: [#3401](https://github.com/IBuySpy-Shared/basecoat/pull/3401)
- Mapper, release advisor, autopilot, dependency routing, and release chain
  paths are listed in the linked PRD.
