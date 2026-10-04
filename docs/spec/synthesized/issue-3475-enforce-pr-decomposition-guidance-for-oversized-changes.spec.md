---
issue: 3475
title: "Enforce PR decomposition guidance for oversized changes"
status: draft
author: ibuyspy
created: 2026-10-04
labels: ["enhancement", "priority:medium", "sprint:2026-W40"]
---

# Spec: Enforce PR decomposition guidance for oversized changes

## Decision and Existing Mechanisms

Design-only contract; implementation remains a separate PR referencing #3475.
`instructions/basecoat-20-lang-governance.instructions.md` limits batches, not
every individual feature, to 15 files and 300 additions plus deletions.
`.github/workflows/pr-size-labeler.yml` computes deterministic line labels:
XS <=20, S <=100, M <=300, L <=800, XL <=2000, XXL >2000.
Neither a manual label nor these size bands determine decomposition eligibility.

`.github/workflows/pr-auto-merge-executor.yml` already fetches PR metadata,
reviews, permission evidence, and trusted policy, aggregates blockers, and
publishes `BaseCoat merge eligibility`. Add a decomposition predicate there,
not a competing merge service or an advisory-only label. Keep required checks,
risk-tier approvals, author/bot exclusions, and current-head review validation.
The existing size/human-review policy must still require a qualified human for
XXL even when the decomposition exception is satisfied.

## Design and Debate

Warning-only automation cannot prevent oversized automated delivery. A universal
15/300 hard cap misreads the batch guideline and can fragment a cohesive feature.
Choose explicit scope classification plus enforcement only for batches.
An unrestricted "generated" exemption is unsafe; choose an evidence-bound
human-reviewed exception. Reuse existing reviews rather than create a label
that silently authorizes merging.

## Classification and Planner Contract

1. After LOG-FIRST, record scope in the existing plan and PR intake Design section:
   `Change scope: individual` or `Change scope: batch`, source issue numbers,
   independently deliverable units, expected files/lines, and the classification
   rationale. These are proposed intake fields, not existing automation.
2. A batch combines independently deliverable work units, even if they share one
   tracking issue. One cohesive feature can span many files. Multiple issue
   references are a signal to inspect units, not proof that a feature is a batch.
   Do not reclassify independent work as individual merely to pass this gate.
3. Before editing, split a batch whose estimated files >15 OR changed lines >300
   into dependency-ordered, independently validated PRs. If estimates are unknown,
   obtain a bounded inventory before proceeding; do not assume zero.
4. A mechanical batch may instead propose the exception below. A proposal is not
   authorization: remain blocked at PR time until qualified review exists.
5. PR-time missing, duplicate, malformed, or contradictory scope metadata blocks
   delivery with a correction message. For example, `individual` plus an inventory
   explicitly listing unrelated deliverables is contradictory. Explain corrected
   classifications in the plan and PR body; never infer an exemption from labels.

## Actual Counts and Gate Contract

Fetch the current PR through `pulls.get`: `changed_files`, `additions`, `deletions`,
base SHA, and head SHA. Count every changed file, including generated files,
binaries, renames, and deletions; use GitHub's totals, not extension filters.
Lines = additions + deletions. Require finite, nonnegative integer counts; missing
fields, truncated file inventories, API errors, or unknown scope are blockers.
Paginate `pulls.listFiles` when verifying the exception inventory; its cardinality
must agree with `changed_files`. If the API cannot enumerate all files, split.

The predicate is:

- Valid individual scope: no batch-threshold blocker; other gates still apply.
- Valid batch AND files <=15 AND lines <=300: no decomposition blocker.
- Valid batch AND (files >15 OR lines >300): split required unless the mechanical
  exception is validated. Include observed counts, limits, and remediation in the
  existing eligibility summary/status.

Read trusted evaluator code/policy from the base/default branch. Never execute PR
head code in `pull_request_target`. Reevaluate on existing opened, synchronize,
edited, label, reopened, review-dismissal, and manual events. Add submitted/edited
review events for exception additions/mutations. Publishing success and merging
must use the same head/base and metadata snapshot; refetch immediately before
merge and restart evaluation on any change. A changed head must never inherit a
successful old-head status.

## Narrow Mechanical Exception

Eligible work is a deterministic regeneration or uniform mechanical
transformation of a declared file inventory, with no hand-edited behavioral,
auth, permission, workflow-policy, secret, or deployment changes mixed into it.
Mixed changes must be split. "Large feature", urgency, and "agent generated" are
not mechanical reasons. Exception evidence in the PR Design section must contain:

- Exact transformation command/tool version and input source revision.
- Complete file inventory and why smaller batches are not viable.
- Reproduction/diff evidence, validation command/results, and rollback procedure.
- Source issues, current head SHA, and current base SHA.

The evaluator canonicalizes these structured fields using sorted-key UTF-8 JSON
and computes SHA-256; report the digest so the reviewer can bind their decision.
A qualifying existing `APPROVED` review must be the reviewer's latest review,
on the current head, from a non-author, non-bot human with current write,
maintain, or admin permission. Require one exact standalone line in that review:
`Batch exception: <40-hex-head-sha> <64-hex-evidence-digest>`.
This is a proposed review annotation, not a new approval store. It binds the
mechanical reason as well as the code. Editing evidence, changing base/head,
dismissing/replacing the review, or losing permission invalidates the exception.
Reuse the executor's permission and review resolution; API failures deny.
The same review may satisfy existing human review requirements, but the
exception must never reduce their required count or waive XXL/risk gates.

## Failure and Security Contract

On uncertainty publish a blocker/pending failure, never green-by-default.
The planner records estimates; only authoritative PR counts decide actual scope.
Do not let body commands, labels, bot comments, or untrusted status publishers
grant approval. Escape untrusted text in summaries and do not interpolate
transformation commands into shell execution. Reproduction is reviewed evidence,
not executable input to the privileged merge workflow.
Body-only evidence edits and review mutations must revoke eligibility immediately,
including edits without a push; retain review IDs, digest, counts, and head/base
in the normal eligibility audit summary, not a second authorization database.

## Implementation Plan

1. Add the classification and estimate/split contract to governance and existing
   planner/batch delivery guidance. Extend the PR intake template without changing
   its headings. Document exception fields and reviewer annotation.
2. Implement a pure evaluator under `scripts/` for scope, counts, inventory,
   evidence digest, and exception decision; invoke from the existing executor.
   Leave `pr-size-labeler.yml` thresholds and ownership unchanged.
3. Extend `tests/pr-auto-merge-executor-tests.ps1` with predicate fixtures and
   event-routing/revocation assertions. Cover privileged default-branch execution
   and pre-merge refetch rather than testing labels alone.
4. Update `docs/reference/governance/enforced-controls.md` only when runtime
   enforcement lands; do not call this design an implemented control.

## Acceptance and Exact Boundary Tests

All tests below are required implementation fixtures, not claimed runtime results.

| Case | Inputs | Expected decomposition decision |
|---|---|---|
| Inclusive limits | batch, 15 files, 150 additions + 150 deletions | Pass |
| Below limits | batch, 14 files, 299 lines | Pass |
| File overflow | batch, 16 files, 300 lines | Block; split |
| Line overflow | batch, 15 files, 150 additions + 151 deletions | Block; split |
| Both overflow | batch, 16 files, 301 lines | Block; split |
| Individual feature | cohesive individual, 16 files, 301 lines | No batch cap; other gates apply |
| Oversized example | batch, 73 files, 6169 lines, no exception | Block; XXL still needs human |
| Valid exception | mechanical batch, 16 files, 301 lines, bound qualified review | Pass decomposition only |
| Mixed behavior | same counts, mechanical plus auth change | Block even with annotation |
| Missing scope/counts | absent scope or undefined/negative counts | Block; not zero |
| Inventory incomplete | declared 16, API enumerates 15 | Block exception |
| Evidence mutation | same head, changed command/inventory/base | Digest invalid; block |
| Unqualified evidence | author/bot/read-only review or permission failure | Block exception |
| Revoked review | dismissed, edited annotation, or latest CHANGES_REQUESTED | Block exception |
| XXL boundary | 2000 versus 2001 lines | XL versus XXL; existing human gate unchanged |
| Size boundaries | 20/21, 100/101, 300/301, 800/801 | Existing label bands unchanged |
| Race | push or body edit after success before merge | No merge; recompute |

Also prove that a valid exception with missing required CI/risk approval never
merges, and label spoofing cannot change the count-based decision.

## Rollout and Rollback

Start with report-only decisions on representative batch, feature, and mechanical
PRs; compare classifications/counts with reviewers. Then enable the blocker in
the existing executor and planner together, announcing the intake-field migration
and requiring existing open PRs to classify scope before delivery.
Do not add a separate required-check name that can strand older PRs.
Rollback by reverting the new predicate/integration and guidance together;
leave size labeling, trusted policy, required checks, and human gates untouched.
Record rollout/rollback in the tracking issue. No auto-merge or deployment is
authorized by this specification PR.

## References

- PRD: `docs/prd/synthesized/issue-3475-enforce-pr-decomposition-guidance-for-oversized-changes.prd.md`
- Governance: `docs/reference/governance-contract.md`
- Refs #3475
- Issue: <https://github.com/IBuySpy-Shared/basecoat/issues/3475>
