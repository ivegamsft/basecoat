# Lane Start Checklist

Use this checklist before beginning any coding work in a worktree lane.
Complete all steps in order. Do not skip the sync steps — stale branches
cause rebase churn and CI failures downstream.

## Pre-Coding Sync (Required)

```text
□ git fetch origin
□ git rebase origin/main  (resolve any conflicts before continuing)
□ echo "Synced to main @ $(git rev-parse --short origin/main)"
□ Confirm output: "Synced to main @ <sha>" recorded in lane status
```

## Lane Identity Check

```text
□ Confirm you are in the correct worktree: git worktree list
□ Confirm branch matches intended scope: git branch --show-current
□ Confirm no uncommitted changes from prior work: git status
```

## Scope Validation

```text
□ Issue number is known and matches branch name
□ Acceptance criteria reviewed and understood
□ No overlapping in-progress work in another lane targeting the same files
```

## Pre-Push Gate (Required Before Every Push)

```text
□ git fetch origin
□ git rebase origin/main
□ git log --oneline origin/main..HEAD  (only your commits should appear)
□ Branch is NOT behind origin/main: git rev-list --count HEAD..origin/main == 0
□ Confirm: "Synced to main @ <sha>" before pushing
```

## CI Fan-Out Gate (Required Before Parallel Job Dispatch)

```text
□ git rev-list --count HEAD..origin/main  (must be < 50)
□ If count >= 50: re-run Pre-Coding Sync before dispatching CI
```

## References

- [Worktree Sync Enforcement](worktree-sync-enforcement.md) — Policy rationale and commands
- [Workflow Conventions](../../.github/instructions/workflow-conventions.instructions.md) — Fleet merge pacing, branch naming
- [Fleet Dispatch Policy](../operations/fleet-dispatch-policy.md) — Pre-dispatch checklist
