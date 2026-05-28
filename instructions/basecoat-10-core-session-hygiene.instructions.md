---
description: "Use when managing long-running Copilot sessions, switching tasks, or coordinating handoffs. Covers context hygiene, session rotation, and clean-state working practices."
applyTo: "**/*"
---

# Session Hygiene Standards

Use this instruction to keep Copilot sessions focused, reduce token waste, and avoid carrying stale context between unrelated tasks.

## Expectations

- Start a fresh session for unrelated work instead of piling multiple domains, goals, or incidents into one conversation.
- Rotate sessions when context feels degraded, after major task completion, or when switching to a substantially different domain.
- Compact context with `/compact` or an equivalent summarization step when older history no longer helps the current task.
- Before ending or rotating a session, produce a structured handoff summary covering what is done, what is in progress, what failed, and key decisions made.
- Use isolated subagents for investigation or broad research so exploratory work does not pollute the main execution context.
- Do not rely on dirty state. Prefer a clean working directory, clean branch, or otherwise well-understood environment before starting new work.

## Session Rotation Triggers

Rotate to a fresh session when any of these are true:

- The conversation contains substantial history that is unrelated to the current objective.
- The active task is complete and the next task is meaningfully different in scope, domain, or stakeholder.
- Prior failed experiments, discarded approaches, or dead-end debugging paths are crowding the useful context.
- You notice degraded reasoning quality, repeated misunderstandings, or difficulty locating the current plan in the session history.

## Context Compaction

When a session is still the right place to continue but the history is bloated:

1. Summarize the current objective, constraints, and next steps.
2. Use `/compact` or an equivalent context-compaction mechanism.
3. Resume from the compacted summary rather than dragging forward obsolete turns.

Compaction is for preserving relevant continuity. Rotation is for separating work that should no longer share context.

## Handoff Checklist

Before ending a session or handing work to a new one, leave a summary with these sections:

- **Done** — completed changes, validations run, and outcomes.
- **In Progress** — active work and the exact next step.
- **Failed or Deferred** — attempts that did not work, blockers, and anything intentionally postponed.
- **Key Decisions** — assumptions, tradeoffs, and important repository-specific findings.

Make the handoff concrete enough that a fresh session can continue without rereading the full conversation.

## Investigation Boundaries

- Use subagents for parallel discovery, repo-wide research, or other exploratory tasks that may generate noisy context.
- Keep the main session focused on decisions, implementation, and verified outcomes.
- Pull back only the findings that matter to the task at hand.

## Review Lens

- Is this task actually related to the current session, or should it start fresh?
- Has stale history been compacted or discarded before it starts to confuse execution?
- Would a new session be able to continue from the handoff summary alone?
- Is the current workspace clean enough that previous task state will not leak into the next one?
