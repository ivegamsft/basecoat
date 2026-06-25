---
name: receiving-code-review
compatibility: [github-copilot-cli]
description: "Use when responding to pull request review feedback. Covers acknowledging comments, categorizing severity, addressing changes, and re-requesting review. USE FOR: address PR review comments, respond to code review feedback, categorize review items, re-request review after changes, resolve review threads. DO NOT USE FOR: performing initial code review, writing review comments on others' PRs, general PR creation."
---
# Receiving Code Review — Response Protocol

## Workflow

### Phase 1 — Acknowledge

1. Read all comments before responding.
2. Categorize: **must-fix** (blocking), **suggestion**, **question**, **nit**.
3. Post brief summary ("3 must-fix, 2 suggestions, 1 question").

### Phase 2 — Prioritize

Address in order: questions → must-fix → suggestions → nits (batched).

### Phase 3 — Respond

- Must-fix: commit fix, reference SHA in reply.
- Suggestion (accepted): "Done in [commit]".
- Suggestion (declined): explain reasoning. Never silently ignore.
- Nit: batch into single commit.

Rules: never force-push without notice; escalate disagreements on must-fix to second reviewer; resolve threads only after reviewer confirms.

### Phase 4 — Re-request Review

Only when: all must-fix addressed, questions answered, CI green, PR description updated if scope changed.

## Anti-Patterns

- Silent force-push, ignoring nits, partial must-fix resolution, re-requesting before CI passes, mega-commits addressing many comments at once.
