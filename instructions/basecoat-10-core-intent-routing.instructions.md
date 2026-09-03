---
description: "Intent prefix routing — interprets user-defined prefixes to determine urgency, timing, and which agents or skills to invoke. Applies to all conversations."
applyTo: "agents/**/*,skills/**/*,prompts/**/*,.github/**/*"
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
| `pr:` | Pull request lifecycle execution: remaining WIP logging, mergeability, broken-build recovery, lane closeout, and safe cleanup | Now | `lane-closeout` skill, `@orphaned-pr-cleanup`, `@merge-coordinator`, `@broken-build-troubleshooter`, `@branch-hygiene-sweeper` |
| `repo-cleanup:` | Bulk post-merge hygiene sweep: sync `main`, prune stale/orphaned worktrees, delete merged local+remote branches | Now | `repo-cleanup` skill, `git-worktrees` skill |
| `issue:` | GitHub issue triage, labeling, and backlog hygiene | Now | `@issue-triage`, `@sprint-planner` |
| `portfolio:` | Project audit for issue/PR dedupe, categorization, dependency mapping, feature grouping, and project linkage | Now | `@issue-triage`, `@orphaned-pr-cleanup`, `@sprint-project-mapper`, `@sprint-planner`, `@governance-auditor` |
| `release:` | Release planning, version bumping, and publication | Now | `@release-manager`, `@release-readiness-chair`, `@release-impact-advisor` |
| `security:` | Security concern or vulnerability | Now | `@security-analyst`, `@guardrail` |
| `perf:` | Performance degradation or concern | Now | `@performance-analyst` |
| `outage:` | Service outage, broken or dead system, site down | Now | `@rca`, `@incident-responder` |
| `rca:` | Root-cause analysis of a known failure | Now | `@rca`, `@config-auditor` |
| `deploy:` | Staged infrastructure deployment | Now | `@devops-engineer` |
| `azure:` | Azure-scoped operation | Now | `@devops-engineer`, `@solution-architect` |
| `infra:` | Infrastructure change | Now | `@devops-engineer`, `@solution-architect` |
| `architect:` | Architecture design or system-design decision | Later | `@solution-architect` |
| `docs:` | Documentation only | Soon | `@tech-writer` |
| `chronicle:` | Export session/worktree learnings into durable story artifacts and follow-up issue packets | Soon | `@memory-promoter`, `@tech-writer` |
| `learn:` | Opt-in extract or consult of recurring CI/workflow signatures in `docs/reference/repo-pathways.md` | Now | `repo-learning` skill, `@rca`, `@self-healing-ci`, `@ci-failure-escalation` |
| `version:` | BaseCoat version inspection and drift check | Now | `@release-manager`, `@devops-engineer` |
| `test:` | Test coverage gap or test failure | Now | `@manual-test-strategy`, `@strategy-to-automation` |
| `refactor:` | Structural improvement, no behavior change | Later | `@code-review`, `@performance-analyst` |
| `ui:` | User interface: components, layout, visual and interaction implementation | Soon | `@frontend-dev`, `@ux-designer`; conditional sheen delegate for governance/audit |
| `ux:` | User experience: user flows, usability, journeys, interaction design | Soon | `@ux-designer`, `@frontend-dev`; conditional sheen delegate for governance/audit |
| `ia:` | Information architecture: content structure, navigation, taxonomy, sitemap | Soon | `@ux-designer`, `@tech-writer`; conditional sheen delegate for governance/audit |
| `design:` | Product-definition and UX/UI governance, design system, component audit, or finish-coat work; `debate:` requests compare options before implementation | Soon | Read downstream `PRODUCT.md`, use `.github/base-coat/docs/reference/design-debate-format.md` (or custom overlay location), then delegate to the `IBuySpy-Shared/basecoat-sheen` catalog when applicable |
| `sprint:` | Sprint planning, execution, or closeout | Now | `@sprint-planner`, `@sprint-closeout-auditor` |
| `wave:` | Dependency-ordered batch within a sprint (issues and PRs) | Now | `@sprint-planner`, `@parallel-session-coordinator` |
| `autopilot:` | Continuous oldest-to-newest backlog burndown in dependency-ordered waves, unattended until stopped or blocked | Now | `@backlog-autopilot`, `@parallel-session-coordinator`, `@ship-it-control-loop`, `@delivery-autopilot` |

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

## Backlog Autopilot Routing (`autopilot:`)

`autopilot:` is a continuous backlog-delivery intent. It burns the issue backlog
oldest to newest in dependency-ordered waves and runs unattended until stopped
or blocked. It is a thin orchestration layer over existing assets and must not
reimplement their behavior. It runs standalone (`concurrency=1`) or as a fleet
(`concurrency=N`). See `docs/design/backlog-autopilot-intent.md`.

Relationship to neighboring intents:

- `fleet:` is sprint-boundary scoped (closeout, plan, cleanup) and runs once.
- `wave:` is a single dependency-ordered batch, with no continuing loop.
- `autopilot:` is the continuing multi-wave loop that composes both, plus the
  ship-it control loop and delivery-autopilot, plus deploy to final destination.

Execution contract:

1. Start with `@backlog-autopilot`. For fleet mode, start from
   `@parallel-session-coordinator` preflight and confirm latest-main sync before
   any write-capable lane starts.
2. Select the oldest N open, actionable issues via `backlog-burndown` and
   `@issue-triage`; exclude blocked or needs-info items. Build the next wave by
   topological sort using `scripts/backlog-autopilot/build-waves.ps1`.
3. For each item run the phase gates in order: design and debate
   (`@solution-architect` plus the `design-debate` format), scope
   (`@task-scope-validator`), positive-and-negative tests
   (`@strategy-to-automation`), implement, commit, push, and PR.
4. Land PRs via the GitHub-native merge queue. Autopilot lanes run under
   `merge_queue_posture: required` so `pr-auto-merge-executor` defers to the
   queue and merges stay serialized and conflict-free.
5. Pace with `scripts/backlog-autopilot/pace-gate.ps1`: enforce a minimum
   interval between merges and exponential backoff on `403`, `429`, and
   secondary-rate-limit responses.
6. Monitor for blocks and broken builds (`@self-healing-ci`,
   `@broken-build-troubleshooter`, `automation-stuck-state-watchdog`); retry
   within `max_retries`, else escalate and mark blocked.
7. Deploy to final destination via `post-merge-release-chain` and
   `publish-to-production`, gated by the ship-it release gate.
8. Emit a per-cycle checkpoint using `ship-it-control-loop` semantics
   (`max_cycles`, `max_retries`, `dry_run`, `stop_conditions`) and advance to
   the next wave. Stop on empty backlog, blocking dependency or policy gate,
   max-cycle exhaustion, repeated deploy-gate failure, or manual stop.

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

## Dependent PR Stack Routing

Stacked PRs are allowed only for explicit dependency chains. They are not the
default shape for independent wave work.

Routing rules:

1. Route dependent multi-PR work to `feature/*` integration lanes.
2. Keep independent items on separate branches and avoid artificial stacking.
3. Retarget every upper PR after its parent merges, then rerun validation.
4. Use a single `feature/* -> main` finalization PR when the stack is collapsed.
5. Keep `agent/*` as the authoring lane and `feature/*` as the integration lane
   only when ordering constraints require it.

This routing must stay synchronized with `docs/operations/hybrid-branching-policy-contract.md`
and the current ship-it/lane-closeout control-loop assets.

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

## Term Disambiguation and Aliases

Normalize these bare terms and phrases to an intent before plain-text
interpretation.

### Design terms (UI vs UX vs IA)

`ui`, `ux`, and `ia` are distinct disciplines and must not collapse to one route.
All three may delegate to `IBuySpy-Shared/basecoat-sheen` for AI-assisted UX/UI
governance, design-system auditing, and finish-coat work. This delegation is
conditional: direct implementation remains with the local frontend/UX route,
while governance and audit requests may use the downstream delegate.

| Term | Discipline | Normalized intent | Route to |
|---|---|---|---|
| `ui` | User interface — components, layout, visual and interaction implementation | `ui:` | `@frontend-dev`, `@ux-designer`; conditional sheen delegate for governance/audit |
| `ux` | User experience — flows, usability, journeys, interaction design | `ux:` | `@ux-designer`, `@frontend-dev`; conditional sheen delegate for governance/audit |
| `ia` | Information architecture — content structure, navigation, taxonomy, sitemap | `ia:` | `@ux-designer`, `@tech-writer`; conditional sheen delegate for governance/audit |
| `design` / `finish-coat` / `sheen` | AI-assisted UX/UI governance, design system, or finish-coat work | `design:` | Delegate to the downstream `basecoat-sheen` catalog |

## Downstream Delegate: basecoat-sheen

`IBuySpy-Shared/basecoat-sheen` is the finish-coat layer of BaseCoat, providing
AI-assisted UX/UI governance skills.

Delegate routing contract:

1. When a `ui:`, `ux:`, `ia:`, or `design:` request is primarily about
   governance, auditing, or design-system enforcement, route to `basecoat-sheen`.
2. When the request is a direct implementation task (write the React component,
   fix the CSS), route to `@frontend-dev` as primary, with sheen for review.
3. Verify the downstream repository's current catalog and entry point before
   delegating; BaseCoat does not assume skill names or contracts in that repo.
4. Public catalog: [basecoat-sheen](https://github.com/ivegamsft/sheen)

### Error and failure terms (noun-keyed)

`error`, `fail`, and `failing` are overloaded. Route on the subject noun, not
the word itself.

| Subject of the error/failure | Normalized intent | Route to |
|---|---|---|
| A running service, site, or app is down | `outage:` | `@rca`, `@incident-responder` |
| A GitHub Actions workflow run, job, or CI step | `workflow:` | `@broken-build-troubleshooter`, `@self-healing-ci` |
| Application code or a test defect | `bug:` | `@code-review`, `@self-healing-ci` |
| Repeated or unknown failure needing diagnosis first | `rca:` | `@rca`, `@config-auditor` |

When the subject noun is absent or ambiguous, ask one disambiguation question
before acting. The `outage:` aliases (`broke`, `broken`, `down`, `dead`,
`site down`, `not responding`, `incident`) apply only when the subject is a
running service, site, or app; application code or test defects route to `bug:`
and GitHub Actions workflow/CI failures route to `workflow:`.

### Credential exposure security subroute

Treat `token exposed`, `secret leaked`, `credential in logs`, `key disclosed`,
and equivalent phrases as an active `security:` incident. Route to
`@incident-responder` for containment and closure tracking, then
`@secrets-manager` for revocation, replacement, and consumer verification, and
finally `@guardrail` for prevention validation.

Do not introduce a separate intent for credential exposure. Keep the incident
open and blocked while any credential-owner action remains. Deleting a log,
removing the disclosure path, or replacing a repository secret does not prove
the exposed source credential was revoked.

### Work-in-progress and cleanup

| Term or phrase | Normalized intent | Route to |
|---|---|---|
| `wip` | `pr:` (remaining WIP logging / merge-readiness) | `@orphaned-pr-cleanup` |
| `backlog wip` | `issue:` (backlog WIP triage) | `@issue-triage` |
| `clean up branches` / `stale branches` | `chore:` | `@branch-hygiene-sweeper` |
| `clean up worktrees` / `clean up work trees` / `prune worktrees` | `chore:` | `@branch-hygiene-sweeper` + `git-worktrees` skill |
| `sync main and clean up branches and worktrees` / `repo cleanup` | `repo-cleanup:` | `repo-cleanup` skill |
| `finish this lane` / `close out this branch` / `return to main` | `pr:` | `lane-closeout` skill |

Branch cleanup routes to `@branch-hygiene-sweeper`; worktree cleanup additionally
uses the `git-worktrees` skill (`skills/git-worktrees/SKILL.md`), which owns the
stale-worktree pruning workflow and its safety checks. A combined "sync main +
prune worktrees + delete merged branches" ask routes to `repo-cleanup:`,
which performs its own branch classification and deletion directly (with
exact-ref safeguards) rather than delegating to `@branch-hygiene-sweeper`,
and orchestrates only the `git-worktrees` skill for worktree pruning, as
one bulk sweep (`skills/repo-cleanup/SKILL.md`).

Lane finish requests route first to `skills/lane-closeout/SKILL.md`. It owns
dirty-WIP capture, sync/publish, PR create-or-update, terminal-state
classification, and safe handoff to branch/worktree cleanup primitives.

`wip/`, `preserved/`, and `backup/` branches are retained (never auto-pruned)
and logged with an owner and next action. Never remove a worktree that has
uncommitted changes or one an active agent is using.

Session/worktree-end automation uses lane-closeout `safe` mode: capture, push,
and report only, with no rebase, merge, PR close, branch deletion, or worktree
removal.

### Backlog and sprint execution

| Phrase | Normalized intent | Route to |
|---|---|---|
| `burn down the backlog` / `backlog burndown` / `burndown` | backlog-burndown skill | `@issue-triage`, `@orphaned-pr-cleanup`, `@sprint-planner` |
| `plan sprint` / `execute sprint` / `sprint` | `sprint:` | `@sprint-planner` |
| `close sprint` / `sprint closeout` / `sprint retro` | `sprint:` | `@sprint-closeout-auditor` |
| `wave` | `wave:` | `@sprint-planner`, `@parallel-session-coordinator` |
| `burn the backlog` / `work the backlog` / `backlog autopilot` / `continuous delivery loop` | `autopilot:` | `@backlog-autopilot`, `@ship-it-control-loop`, `@delivery-autopilot` |

Burn-down and wave execution include open PRs, not just issues. Decomposition
hierarchy: **sprint -> wave -> issue -> task**.

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
