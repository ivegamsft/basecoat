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
   (`bug:`, `feature:`, `chore:`, `pr:`, `refactor:`, `test:`, `deploy:`), the
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
| `pr:` | Pull request lifecycle handling: triage, merge readiness, build-gated closeout, and branch hygiene | Now | `@orphaned-pr-cleanup`, `@merge-coordinator`, `@broken-build-troubleshooter`, `@branch-hygiene-sweeper` |
| `fleet:` | Close previous sprint, plan and execute the next sprint, triage oldest issues, audit PRs/builds, and clean branches | Now | `@sprint-closeout-auditor`, `@sprint-planner`, `@issue-triage`, `@broken-build-troubleshooter`, `@branch-hygiene-sweeper` |
| `security:` | Security concern or vulnerability | Now | `@security-analyst`, `@guardrail` |
| `perf:` | Performance degradation or concern | Now | `@performance-analyst` |
| `outage:` | Service outage, broken or dead system, site down | Now | `@rca` |
| `rca:` | Root-cause analysis of a known failure | Now | `@rca`, `@config-auditor` |
| `deploy:` | Staged infrastructure deployment | Now | `@devops-engineer` |
| `azure:` | Azure-scoped operation | Now | `@devops-engineer`, `@solution-architect` |
| `infra:` | Infrastructure change | Now | `@devops-engineer`, `@solution-architect` |
| `architect:` | Architecture design or system-design decision | Later | `@solution-architect` |
| `docs:` | Documentation only | Soon | `@tech-writer` |
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

`fleet:` is the shortcut intent for a sprint-execution batch that combines
closeout, planning, oldest-first issue triage, PR/build auditing, and branch
cleanup.

## PR Routing

`pr:` is the direct intent for PR lifecycle execution.

Default sequence:

1. Triage stale or blocked pull requests with `@orphaned-pr-cleanup`.
2. Validate merge readiness and ordering with `@merge-coordinator`.
3. Verify CI status before closure; if builds are red, route to `@broken-build-troubleshooter`.
4. Run `@branch-hygiene-sweeper` after merge/close actions to prune only safe branches.

Guardrails:

- Do not close or mark complete while required builds are still pending.
- If required builds fail, keep the PR open and attach failure evidence.
- Only run branch cleanup for branches tied to merged/closed PRs with required builds passing.
- Prefer serial merges for overlapping branches to reduce conflict churn.

## Plan-First Enforcement

For any implementation intent that touches multiple files or requires design
decisions, planning is required before execution begins.

Affected prefixes: `feature:`, `refactor:`, `architect:`

When a standalone `feature:`, `refactor:`, or `architect:` message would
produce multi-file changes or architectural decisions:

1. Emit a plan covering scope, approach, risks, and verification criteria.
2. Present the plan to the user.
3. Do not begin implementing until the plan is confirmed or explicitly waived.

See `instructions/plan-first.instructions.md` for the compatibility alias used
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

- `instructions/ci-firewall.instructions.md`
- `instructions/rbac-authentication.instructions.md`

These files preserve the legacy names while the prefixed BaseCoat instruction
files remain the canonical source.

## Routing Notes

- Use `instructions/plan-first.instructions.md` when a request asks to plan
  before execution.
- Use the Azure preflight aliases before any Azure provisioning or RBAC-sensitive
  changes.
- Keep the canonical prefixed files and the compatibility aliases in sync during
  migration.
