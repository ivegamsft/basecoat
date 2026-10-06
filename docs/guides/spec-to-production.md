# Spec-to-Production Pipeline

This trace separates the intended [solo-dev policy](solo-dev-profile.md) from
the transitions actually implemented by repository workflows. Zero human PR
reviews through XL does not mean zero intake authorization, zero required
checks, or automatic release-tag creation.

Source baseline: `2dde3774281e75b083984ea970d5d08723cc7179`, audited
2026-10-06. Live observations below are dated snapshots, not consumer defaults.
Workflow filenames refer to the source repository; downstream installers may
rename them or omit source-only release jobs.

## State transitions and owners

| Stage | Trigger and owner | Output and next transition | Blocking conditions |
| --- | --- | --- | --- |
| Intake | Issue opened; `issue-triage.lock.yml` executes `issue-triage.md` | Type/priority labels and one triage comment; incomplete PRD/spec evidence requests synthesis | Poor quality adds `needs-info`; duplicate/type conflicts need normalization |
| Field sync | Open/reopen/label changes; `issue-field-sync.yml` | Mirrors labels into native Type/Priority fields | Token/org-field API access; field sync is not implementation authorization |
| Dependency routing | Issue/PR/comment changes; `dependency-relationship-routing.yml` | Parses body/comments; issues get `blocked`, PRs `dependency-blocked` | Open issue dependencies or unmerged PR dependencies |
| Spec fallback | `synthesize-spec` label, successful Issue Triage Agent completion, or manual dispatch; `issue-to-spec-synthesis.yml` | Creates draft PRD/spec on `spec/issue-N-slug`, adds `documentation`/`spec`, copies a sprint label if present, clears intake labels | Draft remains draft; synthesis does not approve the issue, assign implementation, or mark the PR ready |
| Approve supplied spec | Qualified `/approve` issue comment; `issue-approve.yml` | Checks metadata/dependencies/spec, adds `approved`/`copilot-agent`, attempts assignment, then reevaluates linked PRs | Missing type/priority/spec, blocker labels, unresolved dependencies, permission or agent availability |
| Implement | Assigned Copilot coding agent or explicitly authorized local delivery execution | Ready implementation PR with `Closes #N`, valid intake contract, spec and validation evidence | Assignment failure can leave approval labels present without an active agent |
| Label/readiness | PR open/sync/reopen/ready; `pr-size-labeler.yml`; metadata changes also drive `pr-flow-hygiene.yml` | Deterministic size and same-repo sprint labeling; hygiene reports readiness/ownership issues | Hygiene does not turn draft spec PRs into ready implementation PRs |
| Validate | PR head checks; CI, Validate BaseCoat, PR Validation, Agent Merge and spec/harness gates | Current-head results; required-workflow completion routes executor reevaluation | Failed/missing checks, execution approval holds, stale head, invalid intake |
| Eligibility | PR events, explicit dispatch, required-workflow completion; `pr-auto-merge-executor.yml` | Reads trusted policy, checks issue/spec/check evidence, publishes eligibility and revalidates snapshot | Draft, delivery hold, unresolved dependency, missing authorization, XXL approval, stale snapshot |
| Merge queue | Eligible enqueue request; native GitHub queue | Serialized exact integration-tree validation, then squash merge | Queue checks failing or missing; queue command incompatibility; new base/head |
| Post-merge | Merged PR event or hourly backfill; `post-merge-release-chain.yml` | Dispatches evidence-only release gate and source-only packaging; writes marker comment | Dispatch/API failure; comment proves dispatch, not completed production deployment |
| Release preparation | Authorized release execution; optional `release-train.yml` report | Merge committed version/changelog preparation and create intended `vX.Y.Z` tag | No automatic tag creation in release train or post-merge chain; tag must match committed version |
| Tag fan-out | Tag push; `release.yml`, `package-basecoat.yml`, `publish-to-production.yml` | Internal release/assets, validated packages, sanitized public mirror | Version mismatch, label coverage, validation, token preflight, protected environment |
| Production verification | Successful publish plus `docs-production.yml` | Public tag/payload and documentation dispatch evidence | Internal release alone is not proof of mirror/docs delivery |
| Closeout | Implementation PR merge with closing keywords; explicit delivery verification | GitHub closes linked issue at merge; operator records release/tag/production evidence | Issue closure does not imply production completion; public cleanup workflow is separate manual maintenance |

## Labels, directives and tags

| Signal | Meaning and authority |
| --- | --- |
| `bug`, `enhancement`, `documentation`, `chore`, `security`, `question` | Canonical type; triage and approval metadata |
| `priority:critical/high/medium/low` | Planning priority, not approval or bypass |
| `needs-triage`, `needs-info`, `needs-prd`, `synthesize-spec` | Intake states; synthesis clears the latter three after producing or finding a spec PR |
| `duplicate`, `invalid`, `wontfix` | Block issue approval; classification is not authorization |
| `blocked`, `dependency-blocked` | Dependency routing state; authoritative dependency checks also read relationships |
| `approved`, `copilot-agent` | Accepted issue directive and assignment intent; verify persisted assignee separately |
| `documentation`, `spec` on a synthesis PR | Draft artifact classification, not implementation approval |
| `size:XS/S/M/L/XL/XXL` | Changed-line boundaries: 20/100/300/800/2000/greater than 2000; generated lockfile churn excluded; XXL requires qualified approval |
| `wave:*`, `sprint:*`, `wave-*`, `sprint-*`, `wave/sprint` | Release grouping; labeler supplies `sprint:YYYY-Www` to same-repo PRs lacking coverage |
| `skip-release-label-gate`, `dependencies` | Supported PR release-label exemptions, not exemptions from every release workflow |
| `delivery-hold` | Explicit pause; executor disables/refuses auto-merge until removed |
| `skip-prd-spec-check` | Spec-gate exception only; does not satisfy executor authorization |
| `remediation`, `escalated`, `automation` | Watchdog escalation tracking; does not repair or approve automatically |
| `watchdog:ignore`, `sla:exempt` | Suppress watchdog alerts, not required delivery checks |
| `intent-control-plane`, `ship-it`, `spec-2-prod`, `risk-*` | Governed intent artifacts; not substitutes for source approval |
| `vX.Y.Z` | Release version tag; must identify a commit already carrying the matching `version.json` |

Post exact `/approve` on the source issue with a real `- Spec:` reference.
The issue approval workflow checks write/admin permission and uses a substring
command match; the delivery dispatcher is stricter: it requires a current
qualified exact `/approve` comment and an HTTP(S) Spec URL. Avoid extra text in
the approval command and use a real URL to satisfy both surfaces.

`/spec-2-prod` is handled by `ship-it-intent-dispatch.yml`, not by
`issue-approve.yml`. It requires an already approved open source issue, matching
spec, and qualified approval evidence. It does not apply `approved` by itself.
Governed intent generation and a delivery control loop are distinct from the
issue-assignment workflow; generating phase issues is not proof they executed.

PR-side `/approve` forwarding resolves closing keywords and validates
type/priority/dependencies, but does not repeat the issue-side spec-reference
check. Prefer issue-side approval; this asymmetry needs implementation review.

The PR release-label gate accepts the two exemptions above. Separately,
`release.yml` counts merged PRs missing actual wave/sprint coverage and fails
when more than 10% lack it; those exemptions are not included in its calculation.

## Required checks versus policy intent

Solo-dev policy lists six main checks: `lint-and-validate`, `test`,
`validate-commit-messages`, `validate-unix`, `validate-windows`, and
`release-label-gate`. Cloud-agent policy adds `Agent merge guardrails`.
The executor emits `BaseCoat merge eligibility`; intended onboarding also
requires that context with Actions integration ID `15368`.

Live source rules at audit time require the seven validation/guardrail contexts
but omit both `BaseCoat merge eligibility` and `validate-workflow-syntax`.
Thus a green native ruleset is not equivalent to the full documented policy.
The source queue is enabled, serialized with one build/merge, `ALLGREEN`, a
one-minute minimum wait and 60-minute check timeout. The policy pack's
`merge_queue_posture: deferred` describes a default, not this live installation.

Copilot feedback is advisory under solo-dev. Reviewer routing and review requests
are not proof of a required human review. GitHub `action_required` instead means
execution approval: trusted same-repo/current-head sweeps may approve those runs;
fork runs stay held. Production currently has branch protection but no reviewer
approval rule.

## Cadence and recovery

| Job | Configured cadence / trigger | What recovery actually does |
| --- | --- | --- |
| Issue triage | Opened issue, manual dispatch | Labels/comments; no automatic implementation approval |
| Spec synthesis | Label, triage completion, manual | Selects explicit issue or oldest open unapproved `needs-prd` issue; completion is not necessarily one-to-one with intake |
| Dependency routing | Events; Monday 09:00 UTC | Recomputes blockers; shared-ref cancellation can supersede evaluations |
| Issue metadata hygiene | Monday 07:00 UTC, manual | Metadata remediation, not agent execution |
| Auto-approval sweep | Same-repo PR events, selected producer completions, manual; every 15 minutes | Rechecks held run membership/head and approves execution; scheduled timing is not guaranteed |
| Merge eligibility | Required-check completion, PR metadata/head changes, dispatch | One-shot evaluation, no old 15-minute polling loop |
| Scheduled eligibility reconciliation | Auto-approver schedule | Disabled by solo-dev `reconcile_merge_eligibility: false`; its review-driven algorithm is not a universal green-PR recovery loop |
| Human-review reconciliation | Review submission; every 10 minutes | Relevant human approval/exception evidence; not recovery for every zero-review PR |
| PR hygiene | Readiness/metadata events; Monday 13:00 UTC | Reports draft drift at 14 days and ready inactivity at 7 days |
| Post-merge backfill | Hourly at minute 05, manual | Finds missing release-chain marker; an existing dispatch marker is not deployment completion evidence |
| Stuck-state watchdog | Hourly at minute 15, manual | Escalates at configured 24h issue progress, 12h ready-to-merge, 2h merge-to-release evidence thresholds |
| Release train | Monday 06:00 UTC, manual | Scheduled dry-run summary; live dispatch creates a candidate issue, never a release tag |

Watchdog thresholds come from `automation-stage-slas.json`; they override input
fallbacks. Issue progress uses `updated_at`, so comments/label churn can reset
the apparent clock. Release-chain detection looks for marker evidence, not
verified tag/publish completion. These are escalation heuristics, not measured
stage SLAs or automatic repairs.

The post-merge release-gate dispatch sets `dry_run=true` and
`promotion_stage=validate`. Packaging is dispatched independently; this is an
evidence recorder, not an enforced production promotion barrier.

## Measured timing and gaps

The 48-hour window ended 2026-10-06 14:41 UTC: 5,761 unique runs, 98 sampled
job records. Equal 24-hour run volumes were 607 then 5,154; 1,190 cancelled.
There were 432 repeated workflow/SHA/event groups with 896 extra candidates,
not 896 proven redundant builds. Historical attempts are not separately counted.
Workflow elapsed time is not pure execution; use executed steps for job timing.

Successful Linux test medians were 7.9 then 8.6 minutes; Windows medians
16.0, 17.3, then 15.1 minutes, with a small late sample. Sampled successful
runner wait was approximately 4-6 seconds; failed acquisition is excluded.

Concrete handoffs on 2026-10-06:

- Issue #3574 opened at 14:56:44 UTC; synthesis labels at 15:06:07; draft
  #3586 opened at 15:08:51: 12m07s intake-to-draft, not intake-to-implementation.
- Twelve #3586 runs were held from 15:11:54-55. They were still held around
  15:41; producer-driven recovery ran at 15:47 and a later snapshot showed zero
  holds. The timing brackets recovery; it does not establish the exact approval
  instant. This demonstrates a gap after a sweep, not a persistent token failure.
- #3571 opened at 14:17:48 and merged at 14:54:11: 36m23s PR lifetime.
  Tag release run `37483002945` began at 14:55:17 and ended successfully at
  14:56:50; publish `37483002860` ended at 14:56:54; docs dispatch
  `37483233351` succeeded at 14:57:09. This is one sample, not an end-to-end SLA.
- Repeated `v4.6.2` tag-triggered runs generated duplicate changelog PRs #3572
  and #3581. Both remained ready, green, and without auto-merge or eligibility
  status at the audit snapshot. Missing reevaluation is observed; the exact
  lost-event cause is not established.

Priority gaps and tracking:

- #3573: unquoted model-refresh heredoc breaks full workflow lint.
- #3574: `--delete-branch` makes merge enablement fail with the native queue.
- #3575: core Windows wrapper can mask nested script nonzero exits.
- #3576: syntax enforcement gap; also reconcile intended eligibility enforcement.
- #3577: metadata/completion fan-out; retain legitimate exact-tree queue checks.
- #3578: packaging revalidation and immutable target/evidence alignment.
- #3579: irrelevant housekeeping allocations and late-held-run recovery.
- #3580: stage timing, attempts, failures, queue and deployment observability.
- #3587: this trace, directive asymmetry, draft-to-implementation handoff,
  disabled reconciliation, release-label mismatch, and tag ownership.

Do not call work delivered solely because an issue closed, a PR merged, a
dry-run gate passed, or a dispatch comment exists. Verify intended version/tag,
release assets, public publish, and required docs/smoke evidence. The public tag
can have a different commit SHA because publication sanitizes the source tree.
