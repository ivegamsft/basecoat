---
description: "Git workflow, branch naming, commit conventions, and Copilot agent triggers"
applyTo: ".github/**/*,*.md"
---

# Workflow Conventions

## Branch and Commit Conventions

- Branches: `<type>/<issue-number>-<short-description>` (e.g., `feat/1334-split-instructions`)
- Commits: `<type>(<scope>): <summary>` (conventional commits)
- Always include `Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>` trailer

Example:

```bash
git checkout -b feat/1334-split-instructions
git add . && git commit -m "feat(instructions): split monolithic copilot-instructions.md into 7 targeted files

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

## PR Workflow

Standard pattern for all changes:

```bash
git checkout -b <type>/<issue>-<desc>
git add . && git commit -m "<type>(<scope>): <summary>"
gh auth switch --user ibuyspy
git push origin <branch>
gh pr create --title "<title>" --body "<body>"
gh pr merge --squash --admin
```

Use `--admin` to bypass CI wait when change is pre-validated locally.

## CLI session transition policy

For long runs, enforce context transitions explicitly:

1. **Triage -> implementation**: run `/compact`.
2. **Implementation -> merge waiting**: run `/compact`.
3. **Domain pivot** (for example sprint planning -> release triage): run `/new`.
   Reload only the required references.

Message hygiene:

- Do not paste large instruction blocks into chat; reference files by path.
- Batch related operations in one turn.
- Keep the main thread focused on decisions and outcomes; use delegation for broad scan/research work.
- Prefer Ask mode for small, direct queries and edits; switch to Agent mode for multi-file execution, long-running workflows, or broad investigations.

## Fleet Merge Pacing

During fleet or burndown sessions, enforce serialized merge pacing:

1. Queue work in parallel if needed, but merge one PR at a time.
2. Before each merge, confirm required checks are green and mergeability is clean.
3. Wait for merge completion before starting the next merge.
4. After each merge, clean up local and remote branch state before continuing.

## Token-Efficient Operating Defaults

Use these defaults unless task complexity requires escalation:

1. Keep responses concise by default and expand only when risk, ambiguity, or investigation depth requires it.
2. Start in Auto/default model routing for routine work; upshift only for architecture/security reasoning or complex cross-system debugging.
3. Audit each tool call for overhead: prefer direct file tools for local repo work and reserve remote/MCP calls for data not available in-repo.
4. Apply output-token shape defaults: lead with outcome, prefer bullets/tables over long prose, and provide deep explanation only when needed for risk or decision quality.

## Keep Defaults (Issue #2046)

The following proven patterns are now default operating behavior:

1. Compact at semantic phase boundaries (`triage -> implementation -> merge waiting`).
2. Use file references instead of large pasted instruction or artifact blocks.
3. Prefer one kickoff and `/tasks`-based monitoring over repeated orchestration restarts.

Runbooks:

- `docs/guides/kept-patterns/phase-boundary-compaction.md`
- `docs/guides/kept-patterns/file-reference-only-context.md`
- `docs/guides/kept-patterns/single-kickoff-tasks-monitoring.md`

For promoting future candidates, use:

- `docs/guides/keep-candidate-acceptance-checklist.md`

## Triggering the Copilot Coding Agent

Post `/approve` as an issue comment to trigger the Copilot coding agent workflow
(`issue-approve.yml`). The workflow adds `approved` + `copilot-agent` labels,
checks `suggestedActors(capabilities: [CAN_BE_ASSIGNED])` for `copilot-swe-agent`,
and assigns the issue with the documented Copilot cloud-agent payload
(`copilot-swe-agent[bot]` + `agent_assignment`). The `@copilot` mention does
**not** trigger the agent.

## Worktree Sync Enforcement

**Mandatory before any code edits in a worktree lane:**

1. `git fetch origin`
2. `git rebase origin/main` (or `git merge origin/main` for merge-style lanes)
3. Confirm: branch includes latest `origin/main @ <sha>` before starting work

**Mandatory before every push/merge attempt:**

1. Re-sync: `git fetch origin && git rebase origin/main`
2. Verify: `git log --oneline origin/main..HEAD` shows only your commits
3. Confirm branch is not `BEHIND` before pushing

**Orchestrator policy**: When promoting a lane to active head, require explicit confirmation:
> "Synced to main @ $(git rev-parse --short origin/main)"

**Flag stale branches**: Any branch more than 50 commits behind `origin/main` must re-sync before CI fan-out.

## Worktrees

When creating worktrees, use naming pattern: `../<repo>-wt-<issue-or-pr>` (e.g., `../basecoat-wt-1334`).

Worktree cleanup safety playbook:

1. Verify branch-to-path mapping with `git worktree list` before removal.
2. Never delete worktrees by assumed paths.
3. Use `git worktree prune` only after mapping is confirmed and stale entries are identified.
