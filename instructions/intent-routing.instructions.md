---
description: "BaseCoat compatibility alias for intent prefix routing. Preserves the legacy filename while the prefixed BaseCoat instruction is the canonical source."
applyTo: "**/*"
compatibilityAlias: true
canonicalInstruction: "basecoat-10-core-intent-routing.instructions.md"
---

# Intent Prefix Routing

This legacy alias mirrors `basecoat-10-core-intent-routing.instructions.md`.
Keep it in sync so older references still receive the full routing guidance.

## Enforcement Contract

Prefix parsing is a hard contract, not a soft hint. When a recognized prefix
appears at the start of a message, it must be interpreted as an authoritative
routing signal before any plain-text interpretation occurs.

## Prefix Vocabulary

| Prefix | Intent | Default timing | Primary agents |
|---|---|---|---|
| `feature:` | New capability or enhancement | Later | `@sprint-planner`, `@solution-architect` |
| `refactor:` | Structural improvement, no behavior change | Later | `@code-review`, `@performance-analyst` |
| `architect:` | Architecture design or system-design decision | Later | `@solution-architect` |
| `pr:` | Pull request lifecycle handling: triage, merge readiness, build-gated closeout, and branch hygiene | Now | `@orphaned-pr-cleanup`, `@merge-coordinator`, `@broken-build-troubleshooter`, `@branch-hygiene-sweeper` |
| `fleet:` | Close previous sprint, plan and execute the next sprint, triage oldest issues, audit PRs/builds, and clean branches | Now | `@sprint-closeout-auditor`, `@sprint-planner`, `@issue-triage`, `@broken-build-troubleshooter`, `@branch-hygiene-sweeper` |
| `azure:` | Azure-scoped operation | Now | `@devops-engineer`, `@solution-architect` |
| `infra:` | Infrastructure change | Now | `@devops-engineer`, `@solution-architect` |

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

## Plan-First Enforcement

For any implementation intent that touches multiple files or requires design
decisions, planning is required before execution begins.

Affected prefixes: `feature:`, `refactor:`, `architect:`

## Sprint-Style Request Nudge

When the user asks to plan and execute the next sprint or use similar
sprint-planning language, route to `@sprint-planner` first and wait for
confirmation before execution.

## Azure Preflight Guardrail

For `azure:` and `infra:` work, review these compatibility aliases before
proceeding:

- `instructions/ci-firewall.instructions.md`
- `instructions/rbac-authentication.instructions.md`
