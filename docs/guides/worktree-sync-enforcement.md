# Worktree Sync Enforcement

Enforces latest-main sync for all active worktrees before coding or pushing.
Addresses the root cause of rebase churn, stale CI runs, and merge failures
caused by working on branches that have diverged from `origin/main`.

## Lane Start Sequence (Mandatory)

Before making any code edits in a worktree lane:

```bash
git fetch origin
git rebase origin/main
echo "Synced to main @ $(git rev-parse --short origin/main)"
```

Confirm the output reports the current `origin/main` SHA before proceeding.

## Pre-Push Gate (Mandatory)

Before every push or merge attempt:

```bash
git fetch origin
git rebase origin/main
git log --oneline origin/main..HEAD
```

The `git log` output must show **only your commits** — no commits from `origin/main`
that are not in your branch. If the branch is `BEHIND`, re-sync before pushing.

## Orchestrator Confirmation Policy

When promoting a lane to active head, the orchestrator must receive explicit
confirmation from the operator or agent:

> "Synced to main @ `<sha>`"

Example: `Synced to main @ e18f4a3`

No lane may enter the coding phase without this confirmation on record.

## Stale Branch Policy

A branch is considered **stale** when it is more than 50 commits behind `origin/main`.

Stale branches must re-sync before:

- Any CI fan-out (parallel job dispatch)
- Any merge or PR creation
- Any code review assignment

To check staleness:

```bash
git fetch origin
git rev-list --count HEAD..origin/main
```

If the count exceeds 50, run the lane start sequence above before continuing.

## Why This Matters

| Without sync enforcement | With sync enforcement |
|--------------------------|----------------------|
| Rebase conflicts discovered late | Conflicts surface immediately at lane start |
| CI runs against stale base | CI always validates against current main |
| Merge failures block fleet progress | Merges succeed on first attempt |
| Out-of-date assumptions in code | Code written against current interface contracts |

## References

- [Workflow Conventions](../../.github/instructions/workflow-conventions.instructions.md) — Branch naming, commit conventions, fleet merge pacing
- [Fleet Dispatch Policy](../operations/fleet-dispatch-policy.md) — Pre-dispatch checklist, stale branch gate
- [Lane Start Checklist](lane-start-checklist.md) — Step-by-step lane readiness checklist
