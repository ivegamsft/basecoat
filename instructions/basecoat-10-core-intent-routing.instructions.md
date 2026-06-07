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
| `spike:` | Time-boxed investigation, no deliverable | Now | `@solution-architect` |
| `chore:` | Maintenance, cleanup, non-functional work | Soon | `@devops-engineer`, `@release-manager` |
| `fleet:` | Close the sprint, plan the next one, triage oldest issues, and clean branches | Now | `@sprint-closeout-auditor`, `@sprint-planner`, `@issue-triage`, `@broken-build-troubleshooter`, `@branch-hygiene-sweeper` |
| `workflow:` | GitHub Actions/workflow failure triage and repair | Now | `@broken-build-troubleshooter`, `@self-healing-ci`, `@devops-engineer` |
| `actions:` | GitHub Actions configuration, runs, and policy checks | Now | `@self-healing-ci`, `@ci-failure-escalation`, `@devops-engineer` |
| `pr:` | Pull request triage, mergeability, or stale PR cleanup | Now | `@orphaned-pr-cleanup`, `@merge-coordinator`, `@code-review` |
| `issue:` | GitHub issue triage, labeling, and backlog hygiene | Now | `@issue-triage`, `@sprint-planner` |
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

## Audit Mode (`audit:`)

`audit:` is always read-only unless the user explicitly says "and fix" or
"resolve."

## Fleet Routing

`fleet:` is the shortcut intent for sprint execution, backlog triage, and
branch cleanup.

## GitHub-Native Routing

GitHub-native prefixes are deterministic and should avoid extra disambiguation
turns when the request already names a GitHub artifact.

Execution contracts:

1. `workflow:` and `actions:` go straight to failed-run evidence first (run,
   job, failing step), then apply a minimal fix, then rerun the affected scope.
2. `pr:` routes to PR-first triage (mergeability, stale ownership, review
   blockers) before any broad repo analysis.
3. `issue:` routes to issue quality/label/backlog triage first.
4. `release:` routes to release workflow (version source, changelog, tag/release
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
