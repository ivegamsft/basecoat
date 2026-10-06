---
issue: 3578
title: "perf(release): avoid redundant packaging validation and fail early on known errors"
status: ready-for-review
author: copilot
created: 2026-10-06
labels: ["enhancement", "priority:medium"]
---

# Spec: perf(release): avoid redundant packaging validation and fail early on known errors

## Problem Statement

`post-merge-release-chain.yml` dispatched packaging against `main`; the current
workflow then validated and checked out the dispatch ref, not necessarily the
merge whose release decision initiated the run. Its ref-based concurrency
group cancelled in-flight work across different merges. Separately,
`validate-basecoat.yml` already provides the syntax-first dependency merged in
issue #3603, but source identity was not part of the reusable workflow contract.

## Description

Use the merged commit as the single immutable source identity. Carry its full
SHA through release-gate context, package workflow input, validation
checkouts, and artifact checkout. Resolve its Git tree once before expensive
validation and compare the validation and packaging SHA/tree outputs before
building. Keep full validation fresh whenever there is no matching active
package request.

## Intake Contract

### Why This Matters

The issue audit found 43 package runs in the review window, including failures
and cancellations, and a run where syntax failed while the Windows job kept
running. These observations motivate a cheap syntax gate and immutable targets;
they do not prove every run was redundant or that different merges have
equivalent trees.

### Scope

1. `post-merge-release-chain.yml` must require `pulls.get().merge_commit_sha`
   to be a full SHA. It fails closed if unavailable and uses the same value
   for the release-gate `source_sha` and package dispatch `target_sha`.
2. `package-basecoat.yml` accepts an optional SHA for manual/chain dispatch,
   falling back to the event SHA for existing tag pushes. A short target
   resolution job validates SHA syntax, checks out that commit, and records
   commit/tree outputs.
3. `validate-basecoat.yml` accepts `target_sha`; every checkout uses it.
   Workflow-call outputs expose the commit and tree from the
   `validate-workflow-syntax` checkout. Existing `validate-unix` and
   `validate-windows` jobs remain gated by syntax, so a failed syntax job
   blocks expensive validation and the package dependency.
4. The package job depends on target resolution and successful validation,
   checks out the same SHA, and fails explicitly if either commit or tree
   differs from the target and validator outputs.
5. Package run identity and concurrency use the full target SHA.
   Post-merge chaining coalesces only exact-target runs in queued or
   in-progress states whose workflow head matches the current `main` controller
   commit. An older controller revision cannot coalesce a new request, even
   when its target name matches. Non-cancelling SHA-scoped concurrency is the race
   backstop; another SHA is never replaced or cancelled. A completed request
   is not considered evidence for a later request.

### Evidence and Authorization

The post-merge `ship-it-release-gate.yml` dispatch remains `dry_run=true`.
Its status comment records dispatch, not a production promotion or a
validated package. It therefore cannot satisfy release authorization or be
reused as validation evidence. This change intentionally keeps full validation
for every newly started package run: it does not implement a cache or reuse
PR-head, workflow-run, or artifact evidence. Fresh validation avoids needing
to prove source-workflow identity, workflow revision, trust, required-result
completeness, policy compatibility, or evidence freshness. If fresh validation
fails, the package job is skipped and the failure remains visible.

No tag is created or claimed. Tag ownership/authorization is tracked separately
by #3594; existing explicit production authorization remains unchanged.

### Alternatives Considered

- **Reuse prior validation results:** rejected for this increment. The current
  dry-run dispatch marker does not prove production authorization, and no
  artifact proves exact-tree, source-workflow, trust, policy, and complete
  required-check equivalence. A future cache must fail closed on absent, stale,
  or untrusted evidence.
- **Dispatch on `main` without a SHA input:** rejected because a later merge
  can move the ref between decision and checkout.
- **Cancel the previous run for a new request:** rejected because different
  merges may have distinct trees and required artifacts.
- **Create a release tag from post-merge packaging:** out of scope; #3594 owns
  tag lifecycle and authorization.

## Acceptance Criteria

- [ ] A concurrent ref-move fixture proves the package target remains the
  original merge commit.
- [ ] Equivalent SHA requests share a run identity and can coalesce while
  queued/in progress; distinct SHA requests use different identities.
- [ ] Package resolution rejects malformed SHA values; unavailable merge SHA
  fails before dispatch.
- [ ] All validator and package checkouts pin the same full SHA; output checks
  verify both commit and tree.
- [ ] A failed syntax gate blocks Unix/Windows validation and packaging.
- [ ] Release-gate dispatch remains dry-run evidence only; no tag is created.
- [ ] No validation-evidence cache or unsupported reuse path is introduced.
- [ ] Targeted workflow contract tests, repository validation, and markdown
  lint pass.

## References

- PRD: `docs/prd/synthesized/issue-3578-perfrelease-avoid-redundant-packaging-validation-and-fail-ea.prd.md`
- Source issue: <https://github.com/IBuySpy-Shared/basecoat/issues/3578>
- Syntax gate: <https://github.com/IBuySpy-Shared/basecoat/pull/3603>
- Tag ownership remains separate: <https://github.com/IBuySpy-Shared/basecoat/issues/3594>
