# Metrics and Formulas

## Core Metrics

| Metric | Formula |
|---|---|
| Issue count | `count(issues)` |
| PR count | `count(prs)` |
| Merged PR count | `count(prs where mergedAt != null)` |
| LOC changed | `sum(pr.files[].additions + pr.files[].deletions)` |
| Closure ratio | `closed_issues / total_issues` |
| Median cycle time (days) | `median(issue.closedAt - issue.createdAt)` |
| P95 cycle time (days) | `p95(issue.closedAt - issue.createdAt)` |
| Activity span (days) | `max(item.timestamp) - min(item.timestamp)` |
| Blocker density | `blocked_issues / total_issues` |

## Group Similarity (for merge/split)

Weighted similarity score in `[0,1]`:

`similarity = 0.35*tag_overlap + 0.30*reference_overlap + 0.20*time_overlap + 0.15*area_overlap`

Where:
- `tag_overlap = Jaccard(tags_a, tags_b)`
- `reference_overlap = shared_refs / union_refs`
- `time_overlap = overlap_days / union_days`
- `area_overlap = Jaccard(area_labels_a, area_labels_b)`

## Debate Confidence

`confidence = max(merge_score, split_score)`

Recommended policy:
- `confidence >= 0.85`: auto decision
- `0.70 <= confidence < 0.85`: auto decision + flag “review suggested”
- `confidence < 0.70`: no auto decision; require human call

## Significance Thresholds (default)

Pass if:
1. breadth gate: `issues >= 5 OR merged_prs >= 3`
2. activity gate: `loc_changed >= 200 OR activity_span_days >= 7 OR explicit sprint/milestone`

If fail:
- merge with nearest valid group when similarity >0.65
- else mark residual and exclude from headline release metrics

## Release Note Quality Rules

A group may be included in top-line release notes only when:
- significance gate passed
- at least one merged PR exists
- summary can be stated in user-impact language

