---
name: repo-cleanup
description: "Bulk repo-wide hygiene sweep after a wave of PRs merge. USE FOR: sync main and clean up worktrees and branches together (return the primary worktree to a synced main, prune stale/orphaned worktrees, and delete local+remote branches whose PR is merged or closed with no unlanded content). DO NOT USE FOR: a plain 'go to main and get latest' sync with no worktree/branch cleanup requested, closing out a single active lane with WIP (use lane-closeout), deleting branches with open PRs, force-pushing, or resolving merge conflicts."
compatibility: [github-copilot-cli]
visibility: public
category: workflow
metadata:
  category: workflow
  maturity: beta
  audience:
    - developer
allowed-tools: [git, gh, powershell, bash]
context_policy:
  load_scope: minimal
  retention: none
  handoff_schema:
    - branches_deleted
    - worktrees_pruned
    - escalations
  max_context_budget: 4000
---

# Repo Cleanup

Bulk, repo-wide hygiene sweep: sync `main`, prune stale worktrees, and delete
branches proven safe to delete. This is the "wrap up after a merge wave"
command — a lighter-weight counterpart to `lane-closeout` (which finishes one
lane with WIP-safety). It uses the `git-worktrees` skill only for worktree
creation/removal mechanics; branch classification and deletion, and the
worktree-vs-PR safety checks, are performed entirely within this skill's own
contract and are never delegated elsewhere.

## When to Use

- After a batch of PRs merge (a "ship-it wave", sprint closeout, or fleet run)
  and the working directory/worktrees are left pointed at stale feature branches.
- Recurring hygiene: unattended or scheduled sweep to keep the repo tidy.

## When NOT to Use

- A single branch/worktree still has uncommitted WIP or an open PR under
  active review — use `lane-closeout` instead, it is WIP-safe.
- You need to resolve merge conflicts, force-push, or change branch protection.

## Contract

1. **Discover worktree layout** — run `git worktree list --porcelain` to find
   the path-to-branch mapping. `--porcelain` output does **not** report
   uncommitted changes, so it only tells you *which* worktree, if any, has
   `main` checked out — it never tells you whether that worktree is clean.
   Never blindly `git checkout main` in the worktree you happen to be in:
   - If a worktree already has `main` checked out: run `git -C <that-path>
     status --porcelain` there specifically. If clean, operate from that
     worktree. If dirty, stop and escalate — never carry local edits onto
     `main` via checkout, and never switch away from a dirty worktree to
     "fix" this.
   - If no worktree has `main` checked out (all worktrees are on feature
     branches): run `git status --porcelain` in the *current* worktree. If
     it is clean, `git checkout main` here. If it is dirty, do not check out
     `main` in a dirty worktree — either use `git worktree add` to create a
     fresh worktree for `main`, or stop and escalate.
2. **Sync main** — in the worktree now holding `main`: `git fetch origin
   --prune`, `git pull --ff-only origin main` (explicit remote and branch,
   not a bare `git pull --ff-only`, so this can't silently sync from the
   wrong remote or fail only because local `main` has no configured
   upstream — per `instructions/references/governance/workflow-rules.md:48-50`).
   Abort and escalate if `--ff-only` fails (local main has diverged commits)
   rather than force-resetting.
3. **Enumerate worktrees** — `git worktree list --porcelain`; verify the exact
   path-to-branch mapping. Never infer a path.
4. **Identify worktree pruning candidates** — apply the `git-worktrees`
   skill's cleanliness rules: confirm each candidate is clean (no
   uncommitted changes) and not in use by an active agent. **Before
   anything else, exclude from candidacy**: the worktree currently holding
   `main` (never remove it — it is the sync target, not cleanup fodder),
   and any worktree whose branch has a `preserved/`, `backup/`, or `wip/`
   prefix (these are protected regardless of cleanliness, mirroring the
   step-5 branch "Keep" rule). Only worktrees that pass both this exclusion
   check and the cleanliness check proceed to the PR-state check below.
   Additionally, resolve the PR state of the branch each candidate worktree
   maps to — use
   `gh pr list --head <branch> --state all --limit 50 --json
   number,state` (not the single-result `gh pr view <branch>`, which can
   hide a second open PR for the branch) and treat a result count equal to
   the `--limit` value as truncated/ambiguous — escalate rather than assume
   there is no additional PR. A clean worktree whose branch still has any
   open PR falls under this skill's "active review" exclusion and must be
   kept, even though the worktree itself is clean. **The absence of an open
   PR is not sufficient on its own**: a worktree is only a pruning
   candidate if its branch *also* passes step 5's classification as "Safe
   to delete" (merged PR, `baseRefName == main`, exact `headRefOid` match)
   — run that same classification here for the branch. A clean worktree
   for a branch with no PR at all, a closed-but-unmerged PR, or a merged PR
   whose `headRefOid` no longer matches the branch tip must be **kept or
   escalated**, matching step 5's "Keep"/"Escalate" rules, even though the
   worktree itself is clean — such a branch may be an active local lane
   that simply never opened a PR yet, or has diverged since merge. **Do not
   run `git worktree remove` in this step** — only record candidates that
   pass the cleanliness check, the PR-state check, and this step-5
   classification check; removal happens in step 7, after the step 6
   approval gate, so a reviewer who rejects the candidate list can prevent
   worktree removal too, not just branch deletion.
5. **Classify branches** — enumerate **both** local branches (`git branch
   --format='%(refname:short)'`) and remote branches (`git branch -r` /
   `git ls-remote --heads origin`), de-duplicated by name, since a merged
   branch may exist only on `origin` with no local counterpart. For every
   branch other than `main`, resolve **all** PRs for that head — do not use
   `gh pr view <branch>`, which returns only a single PR and can hide
   conflicting evidence (e.g. a second open PR for a reused branch name).
   Always enumerate with `gh pr list --head <branch> --state all --limit 50
   --json number,state,mergedAt,headRefName,headRefOid,baseRefName`,
   mirroring `.github/base-coat/scripts/cleanup-branches.ps1:170-180`. If a
   result count equals the `--limit` value, treat it as truncated/ambiguous
   rather than complete. If results are ambiguous, truncated, or contain
   more than one non-terminal (`OPEN`) entry, escalate rather than
   guessing. Classify:
   - **Safe to delete**: PR `state == MERGED`, `baseRefName == main`, and
     `headRefOid` exactly matches the branch's current tip commit (`git
     rev-parse refs/heads/<branch>` locally — the fully qualified ref,
     since a bare `<branch>` name is ambiguous and can resolve to a
     same-named tag instead of the branch — or the remote ref's object ID
     for a remote-only branch) — or PR `CLOSED` with an explicit
     confirmation it was superseded/discarded and has no unlanded content.
     A merged PR whose base was not `main`, or whose `headRefOid` no longer
     matches the branch tip, does **not** qualify: the branch may have
     advanced since merge or landed somewhere other than `main`.
   - **Keep**: open PR, no PR and recent commits, `preserved/`, `backup/`, or
     `wip/` prefix, or a release/freeze-protected branch.
   - **Escalate**: ambiguous state (e.g., closed PR with unclear disposition),
     or a merged PR whose `headRefOid` does not match the current branch tip.
6. **Dry-run report and approval gate** — before removing or deleting
   anything, produce an explicit candidate report covering **both** the
   step-4 worktree-pruning candidates and the step-5 branch-deletion
   candidates (branch name, PR number, matched `headRefOid`, local vs.
   remote, worktree path where applicable) and stop for review. Only
   proceed to step 7 once the full candidate list has been reviewed and
   approved — repository policy requires automated branch cleanup to run in
   dry-run first and enable deletion only after review
   (`instructions/references/governance/workflow-rules.md:28-31`), and this
   skill extends the same gate to worktree removal since both are
   destructive and irreversible.
7. **Prune worktrees, then delete safe branches** (only the candidates
   approved in step 6):
   - **Worktrees**: immediately before each `git worktree remove`, re-verify
     `git worktree list --porcelain` and the branch's PR state (same
     bounded `gh pr list --head <branch> --state all --limit 50` query as
     step 4, including its truncation check: treat a result count equal to
     the limit as ambiguous and escalate). Re-confirm the step-4 exclusions
     still hold too — never remove the worktree currently holding `main`,
     and never remove a worktree whose branch has a `preserved/`,
     `backup/`, or `wip/` prefix, even if it was somehow queued as a
     candidate. Also re-check for active agent use immediately before
     removal, not just at step 4 — a worktree can become active during the
     step-6 approval pause without becoming dirty (e.g. an agent has it
     checked out but hasn't written yet), so cleanliness alone is not
     enough at removal time. Skip and escalate if the worktree is gone,
     dirty, now in use by an active agent, the branch now has an open PR,
     the branch is protected, or the PR lookup is truncated. Only then
     `git worktree remove` for each approved worktree individually. **Do
     not run a bare `git worktree prune`** —
     it operates repository-wide on all stale administrative entries, not
     just the ones removed or approved above, so it could delete an
     unrelated entry that became stale during the step-6 approval pause
     without that entry ever having appeared in the candidate report,
     bypassing the approval gate entirely. `git worktree remove` on each
     approved worktree already clears its own administrative entry; no
     further pruning step is needed.
   - **Immediately before deleting each branch** — not just once for the
     whole batch — refresh both its PR state and its worktree mapping, since
     time passes during the step-6 approval pause: re-run the same bounded
     head-PR enumeration as step 5 (`gh pr list --head <branch> --state all
     --limit 50 --json number,state,headRefOid,baseRefName`) — never the
     single-result `gh pr view <branch>`, which can miss a second PR opened
     for the same branch during the pause — and re-run `git worktree list
     --porcelain`. Reject the deletion and escalate if the refreshed lookup
     returns any open, ambiguous, or truncated (result count == limit)
     result, or if a worktree now has the branch checked out. Do not rely on
     the ref-OID lease alone to catch this, since an unchanged branch tip
     can still gain a new PR or worktree during the pause.
   - **Local**: immediately before deleting, re-run `git rev-parse
     refs/heads/<branch>` (the fully qualified ref, to avoid resolving a
     same-named tag) and require it to exactly match the `headRefOid`
     recorded during classification — `git branch -d` alone is not a
     sufficient lease against the approval-pause race: when the branch has
     a configured upstream, `-d` checks whether it is merged into *that*
     upstream, not necessarily into `main`, so a branch that advanced and
     was pushed elsewhere during the pause could still pass `-d`'s own
     check. If the local ref moved, skip and escalate. Otherwise run `git
     branch -d <branch>` only — never `-D`. `-d` refuses to delete a branch
     with commits not reachable from its upstream, which is exactly the
     "advanced after merge" case; if it refuses, keep the branch and
     escalate instead of forcing.
   - **Remote**: immediately before deleting, re-verify the remote hasn't
     moved: `git ls-remote --heads origin refs/heads/<branch>` and compare
     the returned object ID to the `headRefOid` recorded during
     classification. Only delete with an exact-ref compare-and-swap, e.g.
     `git push --force-with-lease=refs/heads/<branch>:<expected-object-id>
     origin --delete <branch>`. If the tip moved or the query fails, skip and
     escalate rather than deleting. This mirrors both the lease pattern and
     the immediately-before-delete re-check in
     `.github/base-coat/scripts/cleanup-branches.ps1:456-540`.
   - This skill performs branch classification and deletion within its own
     contract; it delegates only worktree mechanics to the `git-worktrees`
     skill (creation/removal syntax, not PR-state or deletion decisions). It
     does **not** delegate any part of this workflow — worktree pruning or
     branch deletion — to `@branch-hygiene-sweeper`: that agent's current
     guardrails only require a terminal PR state and do not implement an
     exact-ref lease, bounded PR enumeration, or last-minute PR refresh
     (`agents/basecoat-10-core-branch-hygiene-sweeper.agent.md:59-66`), so
     routing any part of this workflow through it would bypass the
     compare-and-swap safety checks above. Routing tables and documentation
     must not list `@branch-hygiene-sweeper` as an alternative for this
     workflow.
8. **Report** — a compact summary: branches scanned, worktrees pruned, safe
   deletions, and any escalations with rationale and next action.

## Guardrails

- Never delete a branch with an open PR, uncommitted changes, or an active
  worktree pointed at it.
- Never remove a worktree without re-verifying `git worktree list` immediately
  before removal — never remove by assumed path.
- Never force-push or force-reset `main`; if `main` cannot fast-forward,
  escalate instead of overwriting local history.
- Never `git checkout main` without first discovering the worktree layout and
  confirming the relevant worktree — the one that owns `main`, or the current
  one if none does — is clean via `git status --porcelain`. `git worktree
  list --porcelain` only reports the path-to-branch mapping, never
  uncommitted changes, so it cannot substitute for a cleanliness check.
- Never classify a branch as safe to delete on `mergedAt`/`headRefName`
  alone — require the PR's `baseRefName == main` and an exact `headRefOid`
  match against the branch's current tip; a merged PR does not prove the
  branch didn't advance afterward or land somewhere other than `main`.
- Never skip the dry-run report and approval gate — produce the exact
  candidate list (worktree-pruning candidates and branch-deletion
  candidates together) and stop for review before any removal or deletion,
  per `instructions/references/governance/workflow-rules.md:28-31`.
- Never auto-delete `preserved/`, `backup/`, or `wip/`-prefixed branches — log
  an owner follow-up instead.
- Never force-delete a local branch (`-D`); if `git branch -d` refuses
  because of unmerged commits, keep the branch and escalate — a merged PR
  does not guarantee the local tip has no later, unlanded commits.
- Never delete a remote branch without an immediate, exact-ref
  compare-and-swap (`--force-with-lease=refs/heads/<branch>:<expected-oid>`)
  taken right before the delete — the remote ref can move or a new PR can
  appear between classification and deletion.
- The ref-OID lease alone does not catch every change during the step-6
  approval pause: an unchanged branch tip can still gain a new open PR or a
  new worktree. Re-check PR state and worktree mapping immediately before
  each individual deletion, not once for the whole batch.
- Classify both local *and* remote branches — a branch merged and deleted
  locally by someone else may still exist on `origin`.
- Always use `gh pr list --head <branch> --state all` (never the
  single-result `gh pr view <branch>`) to confirm merge state — `gh pr view`
  can hide a second PR for a reused branch name, and squash/rebase merges do
  not fast-forward the local branch ref either way.
- Always bound `gh pr list` queries with an explicit `--limit` (e.g. `50`)
  and treat a result count equal to the limit as truncated/ambiguous, not
  complete — the default page size (30) can silently omit a PR that would
  otherwise block a worktree or branch removal, mirroring
  `.github/base-coat/scripts/cleanup-branches.ps1:170-180`.
- Run `git worktree remove` only after confirmed, approved removals (step
  6), never speculatively or before the approval gate. Never run a bare
  `git worktree prune` — it is repository-wide and can silently remove
  unrelated stale entries outside the approved candidate set.
- This is a **bulk, destructive** cleanup (worktree removal + branch
  deletion). A plain "go to main and get latest" / "sync main" request is
  sync-only — do not route it here; only invoke this skill when the request
  also asks for worktree and/or branch cleanup.

## Related Assets

- `skills/git-worktrees/SKILL.md` — worktree creation/removal mechanics and safety rules.
- `skills/lane-closeout/SKILL.md` — WIP-safe single-lane closeout (use before this skill if a lane still has unpublished work).
- `agents/basecoat-10-core-branch-hygiene-sweeper.agent.md` — related branch-hygiene agent; this skill does not delegate any part of its workflow (worktree pruning or branch deletion) to it, since it lacks an exact-ref compare-and-swap lease, bounded PR enumeration, and last-minute PR refresh (see Contract step 7).
