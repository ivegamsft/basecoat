# Multi-Agent Workflow Guide

How to structure parallel agent work so branches stay mergeable, conflicts stay minimal, and the merge step does not hang.

## The Problem

When multiple agents work in parallel on separate branches, every agent touches overlapping files: `README.md`, `INVENTORY.md`, `CHANGELOG.md`, shared config, shared test fixtures. Without structure, the merge step becomes a manual conflict-resolution marathon — or worse, it silently hangs waiting for an interactive git editor that never gets input.

This guide captures the patterns that work.

---

## The Fresh Clone Principle

> **Always clone fresh. Never reuse a dirty working directory.**

A working directory from a previous agent run may carry:
- Unresolved conflict markers (`<<<<<<< HEAD`)
- A detached HEAD state from an aborted rebase
- Uncommitted changes that corrupt subsequent merges
- Stale remote-tracking refs that hide new commits

The fix is trivial and non-negotiable:

```bash
WORKDIR="/tmp/agent-$(date +%s)"
git clone <repo-url> $WORKDIR
cd $WORKDIR
git fetch --all
```

Clean up after each run:

```bash
cd /tmp && rm -rf $WORKDIR
```

---

## Branch Naming Conventions

Consistent names let tooling (and humans) understand scope and order at a glance.

### Parallel sprint branches

```
feature/sprint-{N}-{app-or-area}
```

Examples:
```
feature/sprint-3-api
feature/sprint-3-ui
feature/sprint-3-data
feature/sprint-3-tests
feature/sprint-3-docs
```

- `N` is the sprint number — makes ordering unambiguous
- `app-or-area` is the bounded context the agent owns for this sprint
- Never reuse a branch name across sprints (creates confusing history)

### Hotfix branches

```
hotfix/{issue-number}-{short-description}
```

### Agent-specific branches (non-sprint)

```
feature/{issue-number}-{short-description}
```

This is the single-issue pattern used when an agent is working a specific GitHub Issue, not part of a coordinated sprint.

---

## Minimizing Conflicts by Design

### 1. Assign file ownership to agents

Before the sprint starts, decide which agent owns which files. An agent that does not need a file should not touch it.

| File | Owner |
|------|-------|
| `README.md` | docs agent only |
| `INVENTORY.md` | docs agent only |
| `CHANGELOG.md` | release agent only |
| `package.json` / `*.csproj` | one agent per manifest |
| `src/api/**` | backend-dev agent |
| `src/ui/**` | frontend-dev agent |
| `tests/**` | qa agent |

### 2. Avoid shared infrastructure files in every branch

If every branch touches `.gitignore`, `README.md`, and `INVENTORY.md`, every merge has conflicts. Instead:

- Route all shared-file updates to a single designated branch
- Other agents skip those files and file issues requesting the update
- The docs/infra branch merges last

### 3. Use feature flags instead of shared config changes

If two agents need to change the same config file, use a feature-flag pattern: each agent adds its own key under a namespaced section. They never edit the same line.

---

## Merge Order Strategies

### Strategy 1: Dependency graph (preferred)

Build a directed acyclic graph (DAG) of which branches depend on each other. Merge leaves first, roots last.

```
feature/sprint-3-schema
    └──► feature/sprint-3-api
              └──► feature/sprint-3-ui
              └──► feature/sprint-3-tests
```

Merge order: `schema → api → ui → tests`

To detect dependencies programmatically:
1. For each branch, list changed files
2. Check if any other branch imports/requires those files
3. If branch B imports something introduced in branch A → A must merge before B

### Strategy 2: Conflict surface area (fallback)

When no explicit dependencies exist, merge in ascending order of conflict surface area:

1. Branches that touch zero shared files — merge first (clean, no risk)
2. Branches that touch low-conflict shared files (`.gitignore`, new docs) — merge second
3. Branches that touch high-conflict files (shared config, shared lib) — merge last with extra validation

### Strategy 3: Chronological (simplest, lowest safety)

Merge in the order branches were created (oldest first). This works when agents were given non-overlapping scopes, but it provides no protection against scope drift.

---

## When to Use merge-coordinator vs. Manual Merge

| Situation | Use |
|-----------|-----|
| ≥ 2 branches with no source code conflicts | `merge-coordinator` agent |
| Known dependency order, documentation/config conflicts only | `merge-coordinator` agent |
| Single branch, clean diff | Manual merge (`git merge --no-edit`) |
| Source code (`.ts`, `.cs`, `.py`) conflict in any branch | Manual merge — human required |
| Branches > 200 commits behind target | Manual merge — stale branch cleanup first |
| Merge of a breaking-change branch | Manual merge — review required before push |

---

## Safe Git Commands for Automated Agents

### ✅ Always use these

```bash
git merge origin/<branch> --no-commit --no-ff    # attempt merge, inspect first
git merge origin/<branch> --no-edit              # merge and auto-accept message
git commit --no-edit                             # commit with auto message
git commit -m "explicit message"                 # commit with explicit message
git cherry-pick <hash> --no-commit               # apply commit without committing
git merge origin/<branch> -X ours --no-edit      # take ours on conflict (docs only)
git merge origin/<branch> -X theirs --no-edit    # take theirs on conflict (docs only)
```

### ❌ Never use these in automated contexts

```bash
git rebase origin/main          # HANGS — opens editor on conflicts
git rebase --continue           # HANGS — opens editor for commit message
git commit                      # HANGS — opens editor for message
git merge --continue            # HANGS — opens editor for message
git rebase -i HEAD~N            # HANGS — interactive rebase, always requires editor
```

### Environment variables that prevent hangs

Set these at the start of any automated agent session:

```bash
export GIT_TERMINAL_PROMPT=0     # never prompt for credentials
export GIT_EDITOR=true           # no-op editor
export GIT_MERGE_AUTOEDIT=no     # suppress merge message editor
```

---

## Parallel Sprint Playbook (Step-by-Step)

### Before the sprint

1. Identify the sprint number and scope
2. Assign file ownership — document which agent owns which files
3. Create all branches from the same `main` commit (same base, minimal drift)
4. Share the branch list and dependency order with merge-coordinator

```bash
BASE=$(git rev-parse main)
for area in api ui data tests docs; do
  git checkout -b feature/sprint-3-$area $BASE
  git push origin feature/sprint-3-$area
done
```

### During the sprint

- Agents work in parallel on their branches
- Each agent runs in a fresh clone
- Agents do NOT merge or rebase against each other's branches mid-sprint
- If an agent discovers it needs something from another branch, it files an issue — it does not cherry-pick

### After the sprint (merge phase)

1. All agents push their final commits
2. Open PRs for all branches (target: `main`)
3. Run `merge-coordinator` agent with the branch list and dependency order
4. Review the merge report
5. Approve and merge PRs that were flagged clean or auto-resolved
6. Manually resolve any PRs flagged for human review

---

## Checklist: Is a Branch Ready to Merge?

- [ ] Branch is up to date with target (or merge-coordinator will handle it)
- [ ] All CI checks pass on the branch
- [ ] No secrets committed (gitleaks passes)
- [ ] PR description references the issue number (`Closes #NN`)
- [ ] Changed files are within the agent's assigned ownership scope
- [ ] No conflict markers (`<<<<<<<`, `=======`, `>>>>>>>`) left in files
- [ ] No debug files or local config files staged

---

## References

- `agents/merge-coordinator.agent.md` — the automated merge agent
- `instructions/governance.instructions.md` — governance rules (priority:1)
- `docs/CONFIG_PATTERN.md` — local config pattern to avoid committing secrets
- Issue #51 — merge-coordinator origin story (parallel 5-agent sprint, rebase hang)
