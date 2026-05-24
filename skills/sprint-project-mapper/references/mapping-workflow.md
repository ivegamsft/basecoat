# Sprint/Project Mapping Workflow

## 1) Collect Source Data

Gather issues and PRs for the target window (sprint dates, milestone, or release interval).

```bash
gh issue list --state all --limit 500 --json number,title,labels,state,createdAt,closedAt,assignees
gh pr list --state all --limit 500 --json number,title,labels,state,createdAt,mergedAt,author,files
```

For each PR, capture:
- merged state
- LOC delta (`sum(file.additions + file.deletions)`)
- linked issue references (`#123`, `closes #123`, `fixes #123`)

## 2) Normalize Labels and Tags

Normalize tag aliases into canonical dimensions:

| Canonical | Accepted aliases |
|---|---|
| `sprint:<n>` | `sprint-<n>`, `sprint<n>`, `sprint/<n>` |
| `wave:<n>` | `wave-<n>`, `wave<n>`, `wave/<n>` |
| `project:<name>` | `proj:<name>`, `epic:<name>`, `initiative:<name>` |
| `area/<x>` | `component:<x>`, `domain:<x>` |

## 3) Generate Candidate Groups

Create candidates from:
1. explicit `project:*` tags
2. `(sprint, wave, area)` combinations
3. connected components from references (`depends on`, `blocks`, linked PR/issue chains)

Each candidate should include:
- issue set
- PR set
- shared tags
- timespan

## 4) Debate: Split vs Merge

For each candidate pair with similarity >0.40, produce:

- **Split argument** (heterogeneous labels, divergent areas, mismatched timeline)
- **Merge argument** (strong dependency edges, same milestone intent, release coupling)

Decision guidance:

- Merge if overlap and dependency density are both high.
- Split if merged metrics would hide major risk classes or unrelated domains.
- If confidence <0.70, flag for human review.

## 5) Apply Significance Gate

A group is significant if:
- `(issues >= 5 OR merged_prs >= 3)` and
- `(loc_changed >= 200 OR activity_span_days >= 7 OR has_explicit_sprint_or_milestone)`

Sub-threshold handling:
- merge into nearest valid group if similarity >0.65
- otherwise classify as residual and exclude from top-line release metrics

## 6) Compute Metrics

Per group:
- total issues
- open issues
- closed issues
- merged PRs
- LOC changed (sum additions + deletions)
- median cycle time (days)
- P95 cycle time
- closure ratio (`closed / total`)
- blocker count

## 7) Produce Outputs

1. Group mapping table
2. Debate decision table
3. Release note bullets
4. Residual/outlier report

