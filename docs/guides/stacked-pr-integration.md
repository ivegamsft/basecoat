# Stacked PR Integration

## Goal

Use GitHub stacked pull requests for dependency-ordered wave work so each
change lands on top of the prerequisite change while preserving BaseCoat's
`feature/*` integration-lane contract.

## When to Use

- Wave work with explicit dependency order
- Branches that must build on an earlier unmerged change
- Multi-layer cleanup, migration, or refactor tracks

## When Not to Use

- Independent chores
- Single-file fixes
- Hotfixes that should land directly on `main`

## Mapping BaseCoat Concepts

| BaseCoat concept | GitHub stacked PR concept |
|---|---|
| Wave item | Stack layer |
| Parent blocker | Base branch below the PR |
| Unblock lane | Lower stack layer that must merge first |
| Lane closeout | Merge bottom-up, then prune branches and worktrees |

## Workflow

1. Order work oldest-to-newest and group dependent items into a stack.
2. Create the bottom integration branch as `feature/<issue>-<name>` from `main`.
3. Create each next branch from the previous stack branch.
4. Open one PR per layer, targeting the immediate parent branch.
5. Merge or retarget layers bottom-up, rerunning validation after each parent
   branch changes.
6. Land the completed integration branch through one `feature/* -> main`
   finalization PR.
7. After finalization, prune remaining worktrees and branches.

## Guardrails

- Keep branch protections and required checks on every layer.
- Do not collapse independent work into one stack.
- Refresh the whole stack when a lower layer changes.
- Keep the integration lane and finalization PR aligned with the hybrid
  branching policy.
- Prefer native GitHub stack ordering over manual “merge later” comments.
- No repository feature flag is required; use the existing PR settings.
