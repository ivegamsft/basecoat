# Lane Closeout Workflow

## Safety Invariants

- A dirty tree is evidence, not a cleanup target. Preserve it before syncing.
- Never use `reset --hard`, `clean -fd`, force-push for branch updates,
  `branch -D`, manual
  worktree-directory deletion, or path-assumptive cleanup.
- A remote prune may use an exact-ref
  `--force-with-lease=<ref>:<audited-oid>` only as a compare-and-swap deletion
  guard. If the remote tip moved, retain the branch and report the failed prune.
- Never remove a worktree used by an active agent or containing uncommitted
  changes.
- Never prune `wip/`, `preserved/`, or `backup/` refs automatically.
- A blocked PR is a valid `HANDED_OFF` state, not an abandoned lane.
- Re-running closeout must update the same PR and ledger record rather than
  duplicate them.

## Discovery

Capture these facts before mutation:

```text
repository root
current branch and HEAD
git worktree list --porcelain
git status --porcelain=v1 --untracked-files=all
upstream and ahead/behind counts
open or closed PR for the exact head branch
required checks, reviews, labels, and merge state
exact worktree whose branch is refs/heads/main
```

If branch, path, owner, or PR identity is ambiguous, stop as `PARKED`.

## Capture

Prefer a normal reviewed commit on the lane branch. Do not blindly stage ignored
files or known sensitive paths. When a normal commit is unsafe, snapshot tracked
and untracked non-ignored WIP with `git stash push --include-untracked`, push the
stash commit to a unique ref named from the lane and tree hash, then restore the
stash with `--index`. Keep the stash if restoration fails.

Do not push a snapshot when status paths suggest secrets, credentials, private
keys, or environment files. Retain the local stash, record its object ID, and
classify `PARKED` with a human review action.

## Sync and Publish

1. `git fetch origin`
2. `git rebase origin/main`
3. If conflict occurs, capture conflict evidence, `git rebase --abort`, preserve
   the pre-rebase HEAD on a WIP ref, push it, and stop `PARKED`.
4. Push normally with upstream setup when needed. Never force.
5. Query PRs by exact head branch. Create one only when none exists; otherwise
   update the existing PR body or comment with fresh validation evidence.

## Terminal Classifier

Evaluate in order:

1. `PARKED` — unresolved conflict, interrupted capture, sensitive-path warning,
   failed restore, or failed publish.
2. `MERGED` — PR is already merged, or explicit merge authority exists and all
   mandatory checks, reviews, labels, and policy gates pass.
3. `HANDED_OFF` — PR is open and any gate remains pending or blocked.
4. `ABANDONED` — diff against `origin/main` is empty or a linked superseding PR
   is verified, and an authorized rationale is recorded.

Never infer `ABANDONED` from age, a missing upstream, or an absent PR.

## Prune and Return

Only `MERGED` and explicitly authorized `ABANDONED` lanes are prune candidates.
Invoke `@branch-hygiene-sweeper` for branch deletion and the `git-worktrees`
skill for worktree removal. Both must re-run `git worktree list --porcelain`,
verify cleanliness, and avoid protected WIP refs.

Do not check out `main` inside a linked worktree when another worktree already
owns it. Discover the existing `main` worktree, move execution there after safe
lane removal, then fetch and `pull --ff-only`. If no `main` worktree exists,
report the missing return target instead of creating or deleting one implicitly.

## Ledger

Use one record keyed by repository identity and lane branch. Store local records
under the path returned by `git rev-parse --git-path basecoat/lane-closeout`.
Remote automation may mirror the record to a PR comment, workflow artifact, or
the orphaned-lane issue.

Required fields:

```json
{
  "lane": "feat/123-example",
  "head": "<sha>",
  "pr": "<url-or-null>",
  "terminalState": "MERGED|HANDED_OFF|ABANDONED|PARKED",
  "evidence": [],
  "nextAction": "<action-or-null>",
  "updatedAt": "<utc>"
}
```

## Compact Summary

```text
Lane: <branch> @ <sha>
Terminal state: <state>
PR: <url-or-none>
WIP: <clean|commit|wip-ref|local-stash>
Cleanup: <not-eligible|delegated|verified>
Main: <path and sync result>
Next action: <action-or-none>
```
