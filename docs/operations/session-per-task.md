# Dedicated Session per Task Policy

## Purpose

Define how and when BaseCoat operators create new CLI sessions so each task has focused context, lower token overhead, and cleaner auditability.

## Problem Statement

Long-running shared sessions accumulate unrelated context. As work shifts between triage, implementation, release coordination, and maintenance, every turn carries stale history that does not help the current task.

## Learning Update (2026-06-24)

Recent token-usage review showed a branch/session churn pattern where many tasks
start in fresh sessions and pay setup cost repeatedly instead of reusing warmed
context for related work.

### Learning

- High churn increases repeated repo priming, repeated requirement restatement,
  and continuity loss.
- For related work in the same repo/theme, session reuse plus periodic compact
  checkpoints is typically lower-cost than starting new sessions.
- New sessions still matter, but primarily for isolation boundaries.

### Operating rule

**Compact before you fork; fork for isolation, not cleanup.**

### Decision matrix

| Situation | Best move |
|---|---|
| Same repo, same goal, context is long/noisy | Compact current conversation |
| Same repo, different but related task | Stay in the current session |
| Different repo or truly independent workstream | Start a new session |
| Conversation has irrelevant history but task is still related | Compact first; switch only if signal stays poor |
| Clean audit/isolation is required for deliverable risk | Start a new session/branch |

## Decisions

### 1. Task boundary for creating a new session

A new session is required when any of the following changes:

1. **Primary objective** (for example, fixing CI to writing a design spec).
2. **Primary deliverable** (for example, one issue/PR/document to another).
3. **Primary validation surface** (for example, docs lint to workflow E2E or deployment checks).

Keep work in the same session when only phase changes within the same objective (triage to implementation to merge wait) and use `/compact` at each phase boundary.

### 2. Session granularity model

Base default is **per-issue session**.

Use these exceptions:

| Scenario | Session strategy | Why |
|---|---|---|
| Single GitHub issue with one coherent deliverable | One session | Lowest coordination overhead |
| Feature tracker with multiple independent child issues | One session per child issue | Prevents context cross-contamination |
| Same issue but truly separate domains (for example docs plus infra rollout) | One parent coordination session plus one execution session per domain | Keeps reviewable decisions in one place while isolating execution context |
| Hotfix continuation for same issue after context loss | Reuse issue-scoped session name and branch | Preserves traceability |

Per-sprint or per-category sessions are not defaults; they are allowed only as lightweight orchestration shells that delegate execution to per-task sessions.

### 3. Cross-session state sharing

Cross-session state must be explicit and linkable, not implicit memory.

Required handoff artifacts:

1. **Source of truth link**: issue URL and, if present, parent feature issue.
2. **Execution pointer**: active branch name and latest PR link (or "none yet").
3. **State summary**: concise "done / next / blocked" note.
4. **Validation note**: which command set passed or which failure blocks progress.

Approved channels:

- GitHub issue comment or PR comment for durable history.
- Session-to-session message for active coordination.
- Repository doc updates when policy or operating model changes.

Disallowed:

- Depending on unstated chat context in another session.
- "Resume from memory" requests without links to artifacts.

## Operating Procedure

1. Start from the issue in scope and create one dedicated session for that task.
2. Keep all implementation for that issue in that session until the deliverable is merged or explicitly handed off.
3. If objective changes, start a new session and include the required handoff artifacts.
4. During long tasks, use `/compact` at phase boundaries before deciding whether a new session is required.

## Acceptance Criteria

- Every active implementation task maps to one issue-scoped session.
- Cross-session handoffs include all four required artifacts.
- No execution session spans unrelated issues.
- Token-expensive runs (high event count or repeated context replay) decline after adoption.

## Related

- Issue: [#1667](https://github.com/IBuySpy-Shared/basecoat/issues/1667)
- Parent feature: [#1738](https://github.com/IBuySpy-Shared/basecoat/issues/1738)
- Audit context: [docs/audit/ci-cd-findings-2026-06-14.md](../audit/ci-cd-findings-2026-06-14.md)
- Session hygiene policy: [.github/instructions/cost-optimization.instructions.md](../../.github/instructions/cost-optimization.instructions.md)
