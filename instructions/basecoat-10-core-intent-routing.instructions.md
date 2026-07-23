---
description: "Intent prefix routing — interprets user-defined prefixes to determine urgency, timing, and which agents or skills to invoke. Applies to all conversations."
applyTo: "**/*"
---

# Intent Prefix Routing

The user communicates intent through structured prefixes. Parse the prefix
before any plain-text interpretation.

## Enforcement Contract

Prefix parsing is a hard contract, not a soft hint. When a recognized prefix
appears at the start of a message, it must be interpreted as an authoritative
routing signal before any plain-text interpretation occurs.

Rules:

1. Parse the prefix first.
2. A recognized prefix overrides any other reading of the request.
3. `bug:` routes immediately to the defect workflow.
4. `feature:` routes immediately to the implementation/design workflow.
5. Any agent or pipeline that ignores a recognized prefix is in violation of
   this contract.
6. Before any implementation begins for a recognized implementation prefix
   (`bug:`, `feature:`, `chore:`, `refactor:`, `test:`, `deploy:`), the
   LOG-FIRST gate in `governance.instructions.md` must be satisfied.

## Prefix Vocabulary

| Prefix | Intent | Default timing | Primary agents |
|---|---|---|---|
| `bug:` | Defect, regression, broken behavior | Now | `@code-review`, `@self-healing-ci`, `@config-auditor` |
| `feature:` | New capability or enhancement | Later | `@sprint-planner`, `@solution-architect` |
| `audit:` | Review, assess, validate — no changes | Now | `@security-analyst`, `@config-auditor`, `@github-security-posture` |
| `plan:` | Sprint or project planning | Now | `@sprint-planner`, `@product-manager` |
| `optimize:` | Convert high-entropy requests into normalized execution packets before action | Now | `@task-scope-validator`, `@orchestrator`, `@prompt-coach` |
| `spike:` | Time-boxed investigation, no deliverable | Now | `@solution-architect` |
| `chore:` | Maintenance, cleanup, non-functional work | Soon | `@devops-engineer`, `@release-manager` |
| `fleet:` | Close the sprint, plan the next one, triage oldest issues, and clean branches | Now | `@parallel-session-coordinator`, `@sprint-closeout-auditor`, `@sprint-planner`, `@issue-triage`, `@broken-build-troubleshooter`, `@branch-hygiene-sweeper` |
| `workflow:` | GitHub Actions/workflow failure triage and repair | Now | `@broken-build-troubleshooter`, `@self-healing-ci`, `@devops-engineer` |
| `actions:` | GitHub Actions configuration, runs, and policy checks | Now | `@self-healing-ci`, `@ci-failure-escalation`, `@devops-engineer` |
| `pr:` | Pull request lifecycle execution: remaining WIP logging, mergeability, broken-build recovery, and safe cleanup | Now | `@orphaned-pr-cleanup`, `@merge-coordinator`, `@broken-build-troubleshooter`, `@branch-hygiene-sweeper` |
| `issue:` | GitHub issue triage, labeling, and backlog hygiene | Now | `@issue-triage`, `@sprint-planner` |
| `portfolio:` | Project audit for issue/PR dedupe, categorization, dependency mapping, feature grouping, and project linkage | Now | `@issue-triage`, `@orphaned-pr-cleanup`, `@sprint-project-mapper`, `@sprint-planner`, `@governance-auditor` |
| `release:` | Release planning, version bumping, and publication | Now | `@release-manager`, `@release-readiness-chair`, `@release-impact-advisor` |
| `security:` | Security concern or vulnerability | Now | `@security-analyst`, `@guardrail` |
| `perf:` | Performance degradation or concern | Now | `@performance-analyst` |
| `outage:` | Service outage, broken or dead system, site down | Now | `@rca` |
| `rca:` | Root-cause analysis of a known failure | Now | `@rca`, `@config-auditor` |
| `deploy:` | Staged infrastructure deployment | Now | `@devops-engineer` |
| `azure:` | Azure-scoped operation | Now | `@devops-engineer`, `@solution-architect` |
| `infra:` | Infrastructure change | Now | `@devops-engineer`, `@solution-architect` |
| `architect:` | Architecture design or system-design decision | Later | `@solution-architect` |
| `docs:` | Documentation only | Soon | `@tech-writer` |
| `chronicle:` | Export session/worktree learnings into durable story artifacts and follow-up issue packets | Soon | `@memory-promoter`, `@tech-writer` |
| `version:` | BaseCoat version inspection and drift check | Now | `@release-manager`, `@devops-engineer` |
| `test:` | Test coverage gap or test failure | Now | `@manual-test-strategy`, `@strategy-to-automation` |
| `refactor:` | Structural improvement, no behavior change | Later | `@code-review`, `@performance-analyst` |
| `ux:` | User experience or design concern | Soon | `@ux-designer`, `@frontend-dev` |

## Syntax Determines Timing

The same prefix has different timing implications depending on context.

### Standalone message — act now

When a prefix appears as the first word of a standalone message, treat it as
immediate work.

### Bulleted list — triage and log, not implement

When prefixes appear as items in a bulleted list, they are triage items, not
immediate work orders. Log them and confirm receipt.

### Mixed message — respect both

A message can contain both an immediate preamble and a triage list. The
preamble may be immediate; the list items remain triage.

## Timing Modifiers

These words override the default timing of a prefix:

| Modifier | Effect |
|---|---|
| `now`, `immediately`, `urgent` | Promote any prefix to immediate action |
| `later`, `backlog`, `next sprint` | Defer any prefix, even `bug:` |
| `no changes`, `read-only`, `analysis only` | Suppress implementation even for `bug:` |
| `log it`, `file an issue` | Log only; do not implement |
| `just document` | Documentation output only; no code changes |

## Optimize Routing (`optimize:`)

`optimize:` is an advisory-first prefix that packetizes a composite request into a
bounded execution contract before running side effects.

Execution contract:

1. Parse scope into one or more explicit objectives.
2. Emit a normalized execution packet with:
   - scope boundaries
   - stop conditions
   - measurable done criteria
   - validation clauses
   - routing hints (agent/skill or direct workflow path)
3. If `advisory-only` is present, stop after emitting the packet.
4. If execution is requested, run the packet in order and report cycle summaries.
5. When `optimize:` wraps `ship-it` or `rca`, preserve those governance gates and
   do not downgrade required checks.

## Audit Mode (`audit:`)

`audit:` is always read-only unless the user explicitly says "and fix" or
"resolve."

## Fleet Routing

`fleet:` is the shortcut intent for a sprint-execution batch that combines
closeout, planning, oldest-first issue triage, PR/build auditing, and branch
cleanup. It must start with the parallel-session coordinator and a latest-main
sync preflight before fan-out.

Execution contract:

1. Start with `@parallel-session-coordinator`.
2. Confirm latest-main sync before any write-capable lane starts.
3. Fan out to the sprint closeout, triage, build audit, planning, and hygiene
   agents only after preflight is recorded.

## Fleet Persistent Control-Loop Mode

When a user repeats wave-continuation phrasing (for example, "plan and execute
the next wave", "execute the next wave", or "continue the ship-it loop"),
route the execution step to the persistent control-loop contract instead of
restarting broad sprint planning each turn.

Execution contract:

1. Normalize to `fleet:` intent and start from `@parallel-session-coordinator`
   preflight.
2. Run bounded cycle execution with `ship-it-control-loop` semantics
   (`max_cycles`, `max_retries`, `dry_run`).
3. Emit a cycle checkpoint from active `/tasks`, in-scope PR state, and
   required-check status each cycle.
4. Continue only while stop conditions are not met and convergence is viable.
5. Stop on completion, blocking dependency/policy gate, max-cycle exhaustion,
   or explicit manual stop.

## GitHub-Native Routing

GitHub-native prefixes are deterministic and should avoid extra disambiguation
turns when the request already names a GitHub artifact.
Deterministic guardrail order: `workflow:` `actions:` `pr:` `issue:` `portfolio:` `release:`.

Execution contracts:

1. `workflow:` and `actions:` go straight to failed-run evidence first (run,
   job, failing step), then apply a minimal fix, then rerun the affected scope.
2. `pr:` routes to PR-first lifecycle triage (remaining WIP log, mergeability,
   stale ownership, review blockers) before any broad repo analysis.
3. `issue:` routes to issue quality/label/backlog triage first.
4. `portfolio:` routes to issue/PR hygiene and grouping workflow first: dedupe,
   categorize, wire dependencies, cluster by feature, then ensure a canonical
   sprint/project link is captured in repo docs.
5. `release:` routes to release workflow (version source, changelog, tag/release
   operations) first.

## Version Routing

`version:` is deterministic and should not trigger follow-up disambiguation when
the request already names BaseCoat/downstream version checks.

Execution contract:

1. Read downstream installed version from `.github/base-coat/version.json` when present.
2. Determine install origin:
   - Published BaseCoat source (release/tag or synced `.github/base-coat` payload)
   - Non-published/manual/local customization source
3. If origin is published BaseCoat, fetch latest published BaseCoat release and report drift (`installed` vs `latest`).
4. If origin is not published BaseCoat, report installed version and state that latest published comparison is not authoritative for that source.

## PR Lifecycle Modifier

`pr-lifecycle=<none|standard|full>` is a supported lifecycle modifier for
`feature:` and `pr:` work.

Execution contract:

1. Keep the recognized prefix (`feature:` or `pr:`) as the authoritative routing
   trigger.
2. Parse `pr-lifecycle=<none|standard|full>` as a first-class modifier when
   present.
3. For `feature:` requests, if PR language is present but `pr-lifecycle` is
   omitted, default to `pr-lifecycle=standard`.
4. For `feature:` requests without PR language and without `pr-lifecycle`, do
   not infer lifecycle mode.
5. Reject invalid `pr-lifecycle` values and return explicit guidance listing
   allowed values.
6. Reject dual-prefix combinations (for example `feature: pr:`) and require a
   single authoritative prefix.
7. When `pr-lifecycle=full` is selected, expand routing to full lifecycle
   coverage: remaining WIP logging, merge-readiness triage, broken-build
   follow-up, closure evidence, and post-merge branch hygiene.
8. Keep branch cleanup subordinate to PR state: only merged or explicitly
   closed work moves into branch-hygiene actions.
9. In `pr-lifecycle=full` mode, do not mark the request complete while WIP
   tasks or uncommitted changes remain unresolved.

## Plan-First Enforcement

For any implementation intent that touches multiple files or requires design
decisions, planning is required before execution begins.

Affected prefixes: `feature:`, `refactor:`, `architect:`

When a standalone `feature:`, `refactor:`, or `architect:` message would
produce multi-file changes or architectural decisions:

1. Emit a plan covering scope, approach, risks, and verification criteria.
2. Present the plan to the user.
3. Do not begin implementing until the plan is confirmed or explicitly waived.

See `instructions/basecoat-10-core-plan-first.instructions.md` for the compatibility alias used
during the rollout.

## Sprint-Style Request Nudge

When the user asks to plan and execute the next sprint or use similar
sprint-planning language:

1. Route to `@sprint-planner` first.
2. Present the sprint plan and wait for confirmation.
3. Only then begin execution with the oldest actionable item.

## Azure Preflight Guardrail

For `azure:` and `infra:` work, review these compatibility aliases before
proceeding:

- `instructions/basecoat-60-workflow-ci-firewall.instructions.md`
- `instructions/basecoat-50-security-rbac-authentication.instructions.md`

These files preserve the legacy names while the prefixed BaseCoat instruction
files remain the canonical source.

## Routing Notes

- Use `instructions/basecoat-10-core-plan-first.instructions.md` when a request asks to plan
  before execution.
- Use the Azure preflight aliases before any Azure provisioning or RBAC-sensitive
  changes.
- Keep the canonical prefixed files and the compatibility aliases in sync during
  migration.

## Chronicle Routing (`chronicle:`)

`chronicle:` is for converting execution history into durable narrative artifacts.

Execution contract:

1. Generate a markdown story/update packet from session history references.
2. Support append and update behavior for target story documents.
3. Emit issue-ready learnings for follow-up tracking.
4. When requested, produce memory-promotion suggestions with dedupe checks.
