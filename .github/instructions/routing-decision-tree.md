---
description: "Routing decision tree: map user intent directly to an agent or skill without routing through the legacy router"
applyTo: ".github/**/*,agents/**/*,skills/**/*"
---

# Routing Decision Tree

Direct routing — call the right skill or agent the first time. Each router call costs
~500k tokens; direct calls skip that overhead.

## How to Use

Find your intent below and call the listed skill or agent directly.

## Issue Management

| Intent | Direct Call |
|---|---|
| Triage open issues, assign labels/owners | `/issue-triage` |
| Close stale or resolved issues | `/issue-triage` |
| File a new bug or feature request | `/issue-triage` |
| Log observations as issues | `/issue-triage` |

## Sprint Planning

| Intent | Direct Call |
|---|---|
| Plan the next sprint, rank backlog | `/sprint-planner` |
| Re-scope or adjust sprint mid-cycle | `/sprint-planner` |
| Estimate effort for a set of issues | `/sprint-planner` |

## Code Review and Quality

| Intent | Direct Call |
|---|---|
| Review staged or branch diff | `/code-review` |
| Validate PR before merge | `/code-review` |
| Check for security vulnerabilities | `/code-review` |
| Assess test coverage gap | `/code-review` |

## Build and CI

| Intent | Direct Call |
|---|---|
| Diagnose failing CI workflow | `/build-failure-triage` |
| Debug flaky tests | `/build-failure-triage` |
| Analyze lint or type-check failures | `/build-failure-triage` |
| Trace root cause of broken deploy | `/build-failure-triage` |

## CI/CD Diagnostics (Data Only)

| Intent | Direct Call |
|---|---|
| Produce raw CI/CD metrics snapshot only (no recommendations) | `/ci-cd-diagnostics` |
| Return diagnostics with explicit `BLOCKED: [reason]` values for unavailable metrics | `/ci-cd-diagnostics` |
| Inventory PR lifecycle timing, merge-queue wait/requeue rates, and backlog deltas with command-backed sources | `/ci-cd-diagnostics` |

Use `ci-audit` for governance policy-vs-live gap analysis, and `devops-audit`
for broader remediation-oriented pipeline/process auditing.

## Branch and Git Hygiene

| Intent | Direct Call |
|---|---|
| Clean up merged/stale branches | `/branch-hygiene-sweeper` |
| List branches ready to delete | `/branch-hygiene-sweeper` |
| Audit PR lifecycle health | `/branch-hygiene-sweeper` |

## Agents and Skills

| Intent | Direct Call |
|---|---|
| Design or create a new agent | `agent-designer` |
| Update agent frontmatter or scope | `agent-designer` |
| Create or update a skill | `agent-designer` |
| Review agent eval coverage | `agent-designer` |
| Deploy, canary, or roll back an agent | `agentops` |
| Monitor agent health in production | `agentops` |

## Documentation

| Intent | Direct Call |
|---|---|
| Write or update a doc file | `/code-review` then direct edit |
| Audit docs for broken links or duplication | `/build-failure-triage` |
| Update mkdocs.yml nav | direct edit |

## Infrastructure and Security

| Intent | Direct Call |
|---|---|
| Audit Azure resource compliance | `azure-compliance` (agent) |
| Review RBAC role assignments | `azure-rbac` (agent) |
| Harden container or pod security | `container-security` (agent) |
| Scan for leaked secrets | `config-auditor` (agent) |
| Fix API security findings | `api-security` (agent) |

## Token and Cost

| Intent | Direct Call |
|---|---|
| Get in-session cost status with compaction signal | `/token-status` |
| Check session token usage | `/usage` |
| Compact session history mid-run | `/compact` |
| Analyze token spend across sessions | `workiq-ask_work_iq` via Copilot |

## Fleet and Delegation

| Intent | Direct Call |
|---|---|
| Burn down multiple independent issues in parallel | `/fleet` |
| Delegate a mechanical PR to background agent | `/delegate` |
| Run a task without blocking main context | background subagent |
| Check status of running tasks | `/tasks` |

## Routing Anti-Patterns

Prefer direct skill or agent calls. Use the orchestrator only when no specific skill or
agent maps to your intent and you need routing to identify the right path.

See also: `.github/instructions/cost-optimization.instructions.md` for session hygiene
patterns that further reduce token spend.
