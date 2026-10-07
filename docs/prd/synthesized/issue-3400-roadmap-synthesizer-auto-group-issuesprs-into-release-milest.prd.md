---
issue: 3400
title: "Roadmap Synthesizer: auto-group issues/PRs into release milestones and drive roadmap-ordered execution"
status: implementation-ready
author: ibuyspy
created: 2026-10-06
labels: ["enhancement", "priority:medium"]
---

# Product Requirements Document: Roadmap Synthesizer

## Problem Statement

BaseCoat has separate assets for dependency routing, issue/PR grouping, release
impact analysis, backlog execution, and release publication, but no durable
contract connects them. Grouping and milestone assignment are manual, and
`@backlog-autopilot` selects oldest-first rather than by release order. The
closed generated-spec PR #3401 contained placeholder PRD/spec sections; its
contents are superseded by this recovered specification, not treated as an
approved design.

## Goals

- Reconcile in-scope open issues and linked pull requests into deterministic,
  version-ordered GitHub release milestones and a committed roadmap artifact.
- Add the top-level `roadmap:` intent for bounded plan-through-ship runs,
  resumable by run ID and composed from existing BaseCoat assets.
- Preserve human-owned milestone assignments and never silently skip an
  earlier release or unresolved dependency.
- Keep existing `autopilot:` oldest-first behavior unchanged unless roadmap
  ordering is explicitly requested.

## Non-Goals

- Implement feature code, authorize production changes, close issue #3400, or
  change repository branch protection, merge-queue, or release policy.
- Replace the mapper, release advisor, dependency router, wave builder,
  ship-it control loop, release gate, or release manager.
- Automatically change issue scope, labels, owners, priorities, or dependency
  markers; infer approval from a dry-run or from a label.

## User Personas and Use Cases

- A maintainer runs `roadmap: <scope>` to preview a multi-release plan, then
  explicitly approves that exact plan once before execution.
- A maintainer uses the scheduled/event reconciliation to keep the proposed
  roadmap current without starting execution.
- A delivery operator resumes a bounded run by its run ID after a retryable
  failure or pause.

## User Experience Summary

`roadmap: all|label:<name>|theme:<text>|issue-set:#N,#M` computes a dry-run by
default. The result lists clusters, proposed SemVer milestones, assignments,
residual/unlinked work, execution order, and a plan digest. An authorized human
may approve that plan digest once. The run then processes the earliest approved
release milestone, using existing dependency waves and release gates, and
reconciles remaining in-scope work after each release. Scheduled reconciliation
updates proposals but never approves or executes them.

## Functional Requirements

1. Reuse `sprint-project-mapper` for normalized issue/PR evidence, related-item
   clusters, split/merge debate, significance, and residual reporting. Do not
   drop sub-threshold or unlinked work silently.
2. Reuse `release-impact-advisor` for impact and next-version SemVer
   recommendations. A recommendation is not a tag or a release authorization.
3. Persist eligible groups as deterministically keyed managed milestones and
   maintain `docs/reference/roadmap.md`. Never move a human-owned or pinned
   milestone or an item pinned to it.
4. Route `roadmap:` through the mapper, advisor, `sprint-planner`,
   `backlog-autopilot`, `ship-it-control-loop`, and existing release chain /
   `release-manager`; each asset retains its existing responsibility.
5. Require dry-run by default and one explicit, identity-checked approval bound
   to the run ID and plan digest before any milestone write, artifact PR, or
   execution. Add no per-item or per-release approval for XS-XL; retain all
   existing merge, release, and XXL policy gates without changing them.
6. Keep each invocation bounded by `max_releases`, `concurrency`, `pace`, and
   `stop_conditions`; default concurrency to the existing autopilot setting.
   Resume from persisted state without duplicate milestones, assignments,
   releases, or tags.
7. Reconcile on schedule and issue-labeled/closed and PR-closed events. New
   arrivals are considered only when they match the approved run's scope and
   remaining bounds; otherwise report them for a later plan.

## Non-Functional Requirements

- Repeated reconciliation of unchanged inputs produces the same plan digest
  and no duplicate writes.
- Writes are serialized per repository, re-read before mutation, and fail
  closed on a changed plan, conflicting assignment, ambiguous milestone,
  missing permission, or unverifiable release state.
- Dry-run is read-only. Logs and roadmap output contain no credentials or
  private token material.
- Existing autopilot ordering and merge-queue posture remain backward
  compatible when roadmap ordering is not requested.

## Success Metrics

- Tests prove repeat runs converge to one milestone per release key and never
  alter a human-pinned assignment.
- Tests prove each approved roadmap run selects the lowest unshipped SemVer
  milestone and never starts a later one while the earlier one is blocked.
- The roadmap artifact reports every in-scope item as assigned, pinned,
  blocked, or residual; no item disappears from reconciliation.
- Existing autopilot wave-builder tests remain green with the default mode.

## Constraints and Assumptions

- GitHub milestones and issue/PR milestone fields are the operational
  assignment store; `docs/reference/roadmap.md` is a generated, reviewable
  snapshot, not a competing source of truth.
- The current release manager selects merged PRs since the last tag. The
  implementation must add/verify milestone-scoped release input or stop when
  the tag would include work outside the approved milestone.
- Issue #3400 remains open for implementation. PR #3401 is closed as premature
  auto-synthesis; this PR replaces its placeholder content with reviewed
  requirements and an implementation-ready spec.

## Risks and Open Questions

The GitHub API does not provide a multi-resource transaction for milestone,
issue, and roadmap-artifact writes. The spec therefore requires a single-writer
reconciler, deterministic keys, pre-write revalidation, resumable upserts, and
explicit partial-progress reporting. Release scoping and human edits are
fail-closed conflicts, never reasons to overwrite assignments or cut a tag.

## Dependencies

- `agents/basecoat-10-core-sprint-project-mapper.agent.md` and
  `agents/references/sprint-project-mapper-detail.md`
- `agents/basecoat-60-workflow-release-impact-advisor.agent.md`
- `agents/basecoat-60-workflow-backlog-autopilot.agent.md`,
  `scripts/backlog-autopilot/build-waves.ps1`, and
  `scripts/backlog-autopilot/autopilot.config.json`
- `.github/workflows/dependency-relationship-routing.yml`,
  `.github/workflows/post-merge-release-chain.yml`, and the current release
  gate / release-manager policy
- `docs/guides/intent-prefixes.md` and
  `instructions/basecoat-10-core-intent-routing.instructions.md`

## Rollout and Adoption Plan

Implement the workflow behind an opt-in enable flag. Validate in fixture tests,
then run scheduled/event dry-runs and compare the proposed assignments with
human curation. Enable writes only after idempotency, pin-protection, and
milestone-scoped release tests pass. Enable execution separately through an
approved `roadmap:` run; retain the existing autopilot mode as the fallback.

## References

- Source issue and approved refinement: [#3400](https://github.com/IBuySpy-Shared/basecoat/issues/3400)
- Superseded placeholder draft: [#3401](https://github.com/IBuySpy-Shared/basecoat/pull/3401)
- Technical specification:
  `docs/spec/synthesized/issue-3400-roadmap-synthesizer-auto-group-issuesprs-into-release-milest.spec.md`
