# Governance — Workflow Rules Reference

## Issue-First Mandate

Every change originates from an issue. If no issue exists, create one before touching code.
Issue fields required: title, description, acceptance criteria, labels.

## PR Workflow (Required Steps)

1. Create or confirm issue exists
2. Create branch: `<type>/<issue-number>-<short-description>`
3. Open PR referencing the issue
4. Wait for CI to pass
5. Request review or self-approve per repo policy
6. Merge via PR

Direct pushes to `main` are rejected by branch protection.

## Sprint Close Workflow (Verify → Merge → Prune → Close/Report)

Run this sequence for every sprint closeout batch:

1. **Verify**
   - Confirm each PR has linked issue(s), green CI, and required approvals.
   - Confirm local branch is up to date with `origin/main`.
2. **Merge**
   - Merge only verified PRs using squash merge per repo policy.
3. **Prune branches/worktrees**
   - Delete merged local/remote branches and stale worktree registrations.
4. **Close/report**
   - Close completed issues and post a concise sprint close summary with outcomes and carry-forward items.

### Sprint Close Checklist

- [ ] Verified PR status, checks, approvals, and issue links
- [ ] Merged approved PRs to `main`
- [ ] Deleted merged branches (local + remote)
- [ ] Pruned stale worktrees and refs
- [ ] Closed completed issues
- [ ] Published sprint close report (done, deferred, risks)

### Command Examples

```bash
# 1) Verify
git fetch --all --prune
git checkout main
git pull --ff-only origin main
gh pr list --state open --limit 50
gh pr checks <pr-number>

# 2) Merge
gh pr merge <pr-number> --squash --delete-branch

# 3) Prune branches/worktrees
git branch --merged main
git branch -d <local-branch>
git push origin --delete <remote-branch>
git worktree list
git worktree prune
git fetch --prune

# 4) Close/report
gh issue close <issue-number> --comment "Completed in sprint closeout via PR #<pr-number>."
gh issue comment <meta-issue-number> --body "Sprint close report: merged PRs ..., closed issues ..., carry-forward ..."
```

## Branch Naming

```text
<type>/<issue-number>-<short-description>
```

| Type | Use For |
|---|---|
| `feat` | New features, content, agents, skills |
| `fix` | Bug fixes, correctness corrections |
| `docs` | Documentation only |
| `chore` | Maintenance, dependencies, CI |
| `security` | Security-related changes |

## Commit Message Format

```text
<type>(<scope>): <short summary> (#<issue-number>)
```

- First line ≤ 72 characters
- Always reference the issue number
- Never include secrets, tokens, keys, passwords, or PII

## File Placement Rules

| Asset | Location |
|---|---|
| Agents | `agents/` |
| Skills | `skills/<skill-name>/` |
| Instructions | `instructions/` |
| Templates | `docs/templates/` |
| Governance docs | `docs/` and repo root |

## PR Description Template

```markdown
## Summary
<what changed and why>

## Validation
<how you verified this works>

## Issue Reference
closes #<issue-number>

## Risk
- Risk level: low | medium | high
- Rollback: <how to undo if needed>
```
