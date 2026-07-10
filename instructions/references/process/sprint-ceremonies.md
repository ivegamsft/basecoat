# Sprint Ceremonies — Facilitation Guide

## Ceremony Schedule

| Ceremony | When | Duration | Purpose |
|---|---|---|---|
| Sprint Planning | Day 1, Monday morning | 90 min | Select and scope work from the prioritized backlog |
| Daily Standup | Every weekday | 15 min | Surface blockers, align on the day's priorities |
| Backlog Refinement | Wednesday, Week 1 | 60 min | Estimate, clarify, and split upcoming stories |
| Sprint Review | Last Friday, afternoon | 60 min | Demo completed work to stakeholders, collect feedback |
| Sprint Retrospective | Last Friday, after review | 45 min | Identify process improvements, assign action items |
| Sprint Closeout / Branch Cleanup | Last Friday, after retrospective | 30 min | Verify merged work, prune stale branches/worktrees, and publish closeout evidence |

## Sprint Planning (90 min)

### Agenda

1. **Review sprint goal** (15 min) — PO presents the goal and top-priority items.
2. **Capacity check** (10 min) — team reports PTO, on-call commitments.
3. **Story walkthrough** (40 min) — for each candidate: clarify acceptance criteria, estimate with planning poker, split if > 8 points.
4. **Commit** (25 min) — team pulls from backlog into sprint until capacity is reached; assign every committed issue.

### Sprint Goal Template

```text
In this sprint, we will [deliver X] so that [users/stakeholders can Y].
We will know we succeeded when [acceptance criteria Z].
```

### Estimation Scale (Fibonacci)

| Points | Meaning |
|---|---|
| 1 | Trivial — a few minutes, no unknowns |
| 2 | Small — a few hours, well understood |
| 3 | Medium — one day, mostly understood |
| 5 | Large — 2–3 days, some unknowns |
| 8 | XL — close to a sprint item; consider splitting |
| 13+ | Too large — split before committing |

## Daily Standup (15 min)

**Format (per person, ≤ 2 min):**

1. What did I complete since yesterday?
2. What am I working on today?
3. What is blocking me?

- Side discussions and problem-solving move to a thread immediately after standup.
- Blockers are raised to team lead within standup if unresolved > 24 hours.
- Standup is a synchronization event, not a status report to management.

## Backlog Refinement (60 min)

### Refinement Agenda

1. **Stale issue review** (15 min) — close or re-prioritize issues inactive > 14 days.
2. **New issue walkthrough** (30 min) — clarify, label, estimate, split if needed.
3. **Dependency mapping** (15 min) — identify cross-team blockers, create linked issues.

### Splitting Criteria

- A story is too large if it cannot be completed in < 3 days by one person.
- Split by: user role, acceptance criterion, data set, or platform.
- After splitting, link child issues to the parent with `Part of #<N>`.

## Sprint Review (60 min)

### Review Agenda

1. **Demo** (40 min) — team demos each completed item against acceptance criteria.
2. **Stakeholder feedback** (15 min) — open discussion; capture feedback as new issues.
3. **Metrics review** (5 min) — velocity, cycle time, deployment frequency.

### Demo Format

- Demo in a real environment (staging), not slides.
- Show the feature from the user's perspective.
- If the item is not demo-able (e.g., infrastructure), show evidence: logs, metrics, test results.

## Sprint Retrospective (45 min)

### Start-Stop-Continue Format

1. **Generate** (15 min) — silent sticky-note writing: what should we Start / Stop / Continue?
2. **Cluster** (10 min) — group similar items; dot-vote to prioritize.
3. **Act** (20 min) — convert top 3 clusters into GitHub Issues labeled `process-improvement`, each with an owner and due date.

### Anti-patterns to Avoid

- Retro without action items — always produce filed issues.
- Blaming individuals — focus on systems and processes.
- Repeating the same action items — if unresolved, escalate or close as won't-fix.

## Sprint Closeout / Branch Cleanup (30 min)

### Closeout Agenda

1. **Verify merged work** — confirm PRs, CI, and issue links are complete.
2. **Prune branches/worktrees** — run the audit-first cleanup flow and review the dry-run before deletions.
3. **Publish handoff** — capture carry-forward items, risk notes, and closeout evidence.

### Cleanup Guidance

- Use `instructions/references/governance/workflow-rules.md` for the canonical verify → merge → prune → close/report sequence.
- Use `scripts/cleanup-branches.ps1` to audit stale branches and orphaned local branches.
- Use `skills/git-worktrees/SKILL.md` when the sprint used parallel worktrees.
- Prefer deleting only merged branches with no open PRs.
