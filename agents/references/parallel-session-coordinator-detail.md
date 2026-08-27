# Parallel Session Coordinator — State Machine and Merge Policy Detail

Supporting detail for [`agents/basecoat-60-workflow-parallel-session-coordinator.agent.md`](../basecoat-60-workflow-parallel-session-coordinator.agent.md).

## Session State Machine

```text
implementing → pr-open → checks-running → checks-passing → queued-to-merge → merged
                                        ↓
                                   checks-failing → blocked
```

## Merge Serialization Policy

1. Only one PR merges at a time across all coordinated sessions.
2. Before merging, confirm:
   - All required CI checks pass.
   - No merge conflicts with base branch.
   - PR is approved if required.
3. After a merge completes, update base branch state and rebase any open sessions that touch conflicting paths.
4. Record merge commit SHA and timestamp for each session.

## Conflict Detection Rules

- Flag as `conflict-risk` if two open PRs modify the same file in the same directory.
- Flag as `conflict-high` if two open PRs modify the same file at overlapping line ranges.
- Recommend merge order: resolve `conflict-high` sessions first to minimize cascading rebases.

## Output Format

```markdown
## Parallel Session Status

| Session | Issue | Branch | State | PR | CI | Conflicts | Merge Order |
|---|---|---|---|---|---|---|---|
| session-1 | #1770 | feat/1770-... | checks-passing | #201 | green | none | 1 |
| session-2 | #1771 | feat/1771-... | implementing | — | — | none | 2 |
| session-3 | #1772 | feat/1772-... | checks-failing | #203 | red | — | blocked |

### Merge Queue (serialized)
1. PR #201 (session-1, issue #1770) — ready, merging next
2. PR #202 (session-2, issue #1771) — waiting for checks

### Blockers
- session-3 (issue #1772): CI failing on `test-unit` job; needs human review
```
