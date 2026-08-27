# Sprint/Project Mapper — Grouping Workflow Detail

Supporting detail for [`agents/basecoat-10-core-sprint-project-mapper.agent.md`](../basecoat-10-core-sprint-project-mapper.agent.md).

## Phase 1 — Collect and Normalize

1. Pull issues and PRs for the requested window.
2. Normalize label aliases (e.g., `sprint-32`, `sprint:32`, `wave-2`).
3. Build a unified work-item table:
   - issue number/title/type/priority/state/created/closed
   - linked PRs and merge status
   - LOC delta from merged PR files (`additions + deletions`)
   - cycle time (`closed_at - created_at`)

## Phase 2 — Candidate Grouping

Generate candidate clusters from:

- explicit sprint/wave/project labels
- related issue references (`blocks`, `depends on`, `part of`)
- shared area labels (`area/*`) plus timeframe overlap
- shared branch/PR naming patterns

## Phase 3 — Debate (Split vs Merge)

For every candidate group, run both positions:

- **Split argument**: why the group is too broad or heterogeneous (mixed domains, low linkage, distorted metrics).
- **Merge argument**: why combining groups improves planning value (shared dependencies, same release surface, same
  milestone intent).

Then decide with a confidence score.

Decision rules:

- Prefer **merge** when overlap/dependency density is high and timeline alignment is strong.
- Prefer **split** when groups hide different risk classes or make release notes ambiguous.
- If confidence < 0.70, mark **needs human decision**.

## Phase 4 — Significance Gate

Only finalize groups that meet minimum significance:

- at least **5 issues** OR **3 merged PRs**
- at least **200 LOC changed** (sum of additions + deletions)
- at least **7 days of activity span** OR explicit sprint/milestone binding

If a group fails thresholds:

- merge with nearest related group if similarity > 0.65, else keep as backlog residue
- do not produce standalone release metrics for sub-threshold groups
