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

1. `bug:` routes immediately to the defect workflow.
2. `feature:` routes immediately to the implementation/design workflow.

## Prefix Vocabulary

| Prefix | Intent | Default timing | Primary agents |
|---|---|---|---|
| `feature:` | New capability or enhancement | Later | `@sprint-planner`, `@solution-architect` |
| `refactor:` | Structural improvement, no behavior change | Later | `@code-review`, `@performance-analyst` |
| `architect:` | Architecture design or system-design decision | Later | `@solution-architect` |
| `workflow:` | GitHub Actions/workflow failure triage and repair | Now | `@broken-build-troubleshooter`, `@self-healing-ci`, `@devops-engineer` |
| `actions:` | GitHub Actions configuration, runs, and policy checks | Now | `@self-healing-ci`, `@ci-failure-escalation`, `@devops-engineer` |
| `pr:` | Pull request triage, mergeability, or stale PR cleanup | Now | `@orphaned-pr-cleanup`, `@merge-coordinator`, `@code-review` |
| `issue:` | GitHub issue triage, labeling, and backlog hygiene | Now | `@issue-triage`, `@sprint-planner` |
| `portfolio:` | Project audit for issue/PR dedupe, categorization, dependency mapping, feature grouping, and project linkage | Now | `@issue-triage`, `@orphaned-pr-cleanup`, `@sprint-project-mapper`, `@sprint-planner`, `@governance-auditor` |
| `release:` | Release planning, version bumping, and publication | Now | `@release-manager`, `@release-readiness-chair`, `@release-impact-advisor` |
| `version:` | BaseCoat version inspection and drift check | Now | `@release-manager`, `@devops-engineer` |
| `azure:` | Azure-scoped operation | Now | `@devops-engineer`, `@solution-architect` |
| `infra:` | Infrastructure change | Now | `@devops-engineer`, `@solution-architect` |

## GitHub-Native Routing

`workflow:`, `actions:`, `pr:`, `issue:`, `portfolio:`, and `release:` are deterministic
GitHub-scoped routes and should not trigger extra disambiguation turns.

## PR Lifecycle Modifier

`pr-lifecycle=<none|standard|full>` is supported for `feature:` and `pr:`.

Execution contract:

1. Keep a single authoritative prefix (`feature:` or `pr:`).
2. Parse `pr-lifecycle` when present and validate enum values.
3. Reject dual-prefix combinations such as `feature: pr:`.
4. For `feature:` requests with PR language but no modifier, default to
   `pr-lifecycle=standard`.
5. In `pr-lifecycle=full`, require required-check readiness before closeout,
   keep cleanup after merge or explicit close, and block completion while WIP
   or uncommitted state remains.

## Version Routing

`version:` inspects downstream installed BaseCoat version and, when the install
source is published BaseCoat, compares against latest published release.

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

- `instructions/basecoat-60-workflow-ci-firewall.instructions.md`
- `instructions/basecoat-50-security-rbac-authentication.instructions.md`
