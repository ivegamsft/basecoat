# Repo Cleanup Contract

Supporting contract for [`SKILL.md`](SKILL.md).

## Candidate Classification

Discover mappings with `git worktree list --porcelain`. Check cleanliness with
`git -C <path> status --porcelain`; porcelain worktree output does not include
working-tree changes. Exclude the `main` worktree and `preserved/`, `backup/`,
and `wip/` branches, plus release/freeze-protected branches. Never perform destructive operations on `main`;
synchronize it only from a clean selected
worktree. Never operate in a dirty worktree or switch away from one to obtain
`main`; create a fresh worktree or escalate.

Synchronize the `main` worktree with:

```bash
git fetch origin --prune
git pull --ff-only origin main
```

Enumerate both local and remote branches. For each non-`main` branch, use
`gh pr list --head <branch> --state all --limit 50 --json number,state,mergedAt,headRefName,headRefOid,baseRefName`.
Treat a result count of 50 as truncated and escalate. Resolve all PRs; keep
open PRs, protected prefixes, branches with no PR and recent commits, and
ambiguous or closed-but-unconfirmed states. A branch is safe only when its PR
is merged into `main`, or when a closed superseded/discarded PR was explicitly
confirmed as having no unlanded content, and its recorded `headRefOid` exactly
equals the current local or remote tip. A merged PR with a different base or
moved tip is escalated.

For each worktree candidate, classify its associated branch first. Only a
worktree whose branch passes the safe-to-delete classification may enter the
removal list; keep every other worktree for escalation, even when it is clean.

## Approval and Race Checks

The dry-run report must include every worktree and branch candidate, PR number,
matched OID, local/remote location, and worktree path. Stop for explicit
approval before removal or deletion.

Immediately before each action, re-run the bounded PR query and
`git worktree list --porcelain`. Reject the action if a new open PR, truncation,
protected prefix, active worktree or active agent use, dirty worktree, refresh
failure (any refresh failure rejects the action), ambiguous state, newly
closed-but-unconfirmed PR, or changed ref appears.
Re-check changed mappings and active-agent use
separately before each action.
Never use `git worktree prune`; remove only individually approved paths.

For local deletion, compare `git rev-parse refs/heads/<branch>` to the recorded
OID and run `git branch -d <branch>` only. For remote deletion, compare
`git ls-remote --heads origin refs/heads/<branch>` and use:

```bash
git push --force-with-lease=refs/heads/<branch>:<expected-oid> origin --delete <branch>
```

## Output

Report branches scanned, worktrees removed, local/remote deletions, and every
escalation with its reason and next action.
