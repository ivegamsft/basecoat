# Queue Rebalancer — Detail Reference

## Default Scoring Policy

```yaml
scoring:
  weights:
    impact: 0.35
    urgency: 0.25
    blockers: 0.30
    churn: 0.10
  scale_max: 100
approval:
  high_risk_move_score: 75
  max_position_jump_without_checkin: 3
  high_downstream_count: 4
```

Scoring formula: `score = (impact * w_impact) + (urgency * w_urgency) + (blockers * w_blockers) - (churn * w_churn)`

Override via `--score-policy <path>` or `--approval-policy <path>`.

## Phase Details

### Phase 1 — Collect Work Items

```bash
gh pr list --state open --json number,title,headRefName,statusCheckRollup,body,labels
gh issue list --state open --json number,title,body,labels,milestone
```

Collect: PR CI status, body keywords (`Blocks #N`, `Blocked by #N`, `Depends on #N`, `Closes #N`), labels.

### Phase 2 — Dependency Graph

Edges sourced from:

1. Explicit body keywords (hard dependency)
2. PR base-branch chains with CI failures (hard dependency)
3. `Closes #N` linking PRs to blocker issues (soft dependency)
4. Shared label markers (`feature:*`, `capability:*`, `sprint:*`, `wave:*`) (soft dependency)

Tag each edge with `edge_type` (`hard`|`soft`) and `edge_reason`.

### Phase 3 — Feature Clusters

Required cluster fields:

| Field | Description |
|---|---|
| `cluster_id` | Stable identifier for this run |
| `member_items` | Included issue/PR references |
| `cluster_confidence` | Numeric confidence (0-1) |
| `cluster_rationale` | Explanation for grouping |
| `hard_edge_count` | Hard dependency edges inside cluster |
| `soft_edge_count` | Soft dependency edges inside cluster |

### Phase 4 — Score Records

| Field | Description |
|---|---|
| `impact` | Delivery impact score (0-100) |
| `urgency` | Active breakage urgency score (0-100) |
| `blockers` | Normalized downstream-blocker score (0-100) |
| `churn` | Change volatility/risk score (0-100) |
| `score` | Final weighted score |
| `score_policy_version` | Policy file/version used |

### Phase 5 — Item Classification

| Classification | Criteria |
|---|---|
| `blocker` | Outgoing edge; not itself blocked |
| `blocked` | Has incoming edge |
| `independent` | No edges in either direction |
| `chain-member` | Both incoming and outgoing edges |

### Phase 6 — Unblock Group

- Include only blockers with active CI failure or dependency-stall impact.
- Keep group small (default max 3-5 items).
- Note whether fix source is existing PR commit(s), linked issue fix branch, or cherry-pickable hotfix.

### Phase 7 — Scope Gate Rules

Gate `needs-check-in` when:

- Item has `enhancement` label or introduces net-new functionality
- Move score >= `approval.high_risk_move_score`
- Queue promotion jump > `approval.max_position_jump_without_checkin`
- Item has downstream dependents >= `approval.high_downstream_count`

Gate `no-tests` when: no test file paths (`*_test.*`, `*.test.*`, `*.spec.*`, `tests/`, `__tests__/`, `e2e/`) in diff and change introduces feature behavior.

```bash
gh pr diff <number> --name-only | rg '(_test\.|\.test\.|\.spec\.|tests/|__tests__/|e2e/)'
```

### Phase 9 — Queue Ranking Tiebreakers

1. CI status: failing PRs that block others rank above passing ones
2. Downstream count: higher dependent count ranks higher
3. Age: older items rank above newer
4. Label: `priority:critical` > `priority:high` > `priority:medium` > `priority:low`

### Phase 10 — Critical Path (rebalance mode)

| Field | Description |
|---|---|
| `critical_path` | Ordered list from root blocker to terminal dependent |
| `critical_path_length` | Number of nodes |
| `critical_path_risk` | Aggregated risk signal |
| `critical_path_reasoning` | Explanation |

### Phase 11 — Labels and Comments

When `--dry-run` is set, report these actions without executing them.

```bash
gh pr edit <number> --add-label "queue:promoted"
gh pr comment <number> --body "Queue rebalanced for unblock lane: ..."
gh pr edit <number> --add-label "gate:no-tests"
gh pr edit <number> --add-label "gate:needs-check-in"
```

## Audit Log Schema

| Field | Description |
|---|---|
| `item` | PR or issue reference |
| `previous_rank` | Rank before rebalancing |
| `new_rank` | Rank after rebalancing |
| `score_before` | Previous score snapshot |
| `score_after` | Current score snapshot |
| `decision` | promoted, blocked, or gated |
| `reason` | Human-readable rationale |
| `gates` | Applied gates (`none`, `no-tests`, `needs-check-in`) |
| `operator` | Actor or automation identity |
| `timestamp_utc` | ISO-8601 timestamp |

## Report Template

```markdown
## Queue Rebalancer Report — <repo> — <date>

### Dependency Graph Summary
| Item | Type | Classification | Score | Hard Deps | Soft Deps | Gate | Downstream Count |
|------|------|---------------|-------|-----------|-----------|------|-----------------|

### Feature Clusters
| Cluster | Members | Confidence | Rationale |

### Critical Path (rebalance mode)
`#N -> #M -> #R` (length: 3, risk: medium)

### Unblock Group (executed first)
1. #N — <title> (blocks #A, #B, #C)

### Excluded Items (gate:no-tests)
### Waiting for Check-In (gate:needs-check-in)
### Chains Stalled by Gated Items
### Audit Log
```

## Output Summary

- Blocker-first reorder plan with configurable weighted scoring
- Hard and soft dependency graph with edge rationale
- Feature clusters with confidence and rationale
- Critical-path artifact in rebalance mode
- Approved unblock group with cherry-pick sources
- Gated items requiring tests or explicit check-in
- Audit log with before/after rank and score rationale
- Resume marker for returning to normal dependency order
