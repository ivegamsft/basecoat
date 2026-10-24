# CI trend observation: 2026-10-10

Read-only measurement for #3733, following the requirements of #3530 in
[retrospective follow-up contracts](../design/retrospective-followup-contracts.md).
This is a dated observation, not a collector, dashboard, threshold decision,
implementation approval, or release-health claim. The original retrospective
remains unchanged.

## Population and Collection Identity

Repository: `ivegamsft/basecoat`. Collection ended at
`2026-10-10T11:49:46.6302875Z`, using authenticated read-only Actions API requests.
Population: all API-visible workflows, branches and events whose `created_at`
falls within each UTC half-open interval `[start, end)`. No workflow or branch
filter was applied. These are three complete Monday-to-Monday weeks selected
around the original retrospective, not the latest three weeks at collection.

Each logical run is counted once by run ID using its latest API-visible attempt
at collection. This is not attempt history or the state as of each week's end.
The API collection is sequential, not an atomic repository snapshot; subsequent
reruns, deletions and retention can change a recollection.

## Observed Results

The executed-conclusion ratio is `success / (success + failure)` for completed
runs. Cancelled and skipped runs are excluded from that denominator but remain
visible. No other conclusions or pending statuses appeared in the final sample.

| UTC week start | Exclusive end | Unique runs | Success | Failure | Cancelled | Skipped | Executed ratio | IDs with attempt > 1 |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 2026-09-14 | 2026-09-21 | 2925 | 2154 | 114 | 325 | 332 | 94.97% | 182 |
| 2026-09-21 | 2026-09-28 | 267 | 260 | 5 | 1 | 1 | 98.11% | 12 |
| 2026-09-28 | 2026-10-05 | 2350 | 1740 | 78 | 302 | 230 | 95.71% | 83 |

Each row reconciles unique runs to successes, failures and excluded conclusions.
The retry column counts logical IDs whose `run_attempt` exceeds one; it is not
a count of retry attempts, first-attempt failures, or recovered incidents.
No pending latest attempt was replaced with an older green attempt.

The changing run volumes and workflow mix prevent interpreting the ratios as
an improvement/regression in a fixed workflow population. They are descriptive
all-workflow samples, not main-branch required-check reliability, shipped value,
or a certification of healthy CI. A fixed-workflow trend and attempt-level
instability assessment remain separate work.

## Pagination Evidence

Weekly queries initially reached the API's 1000-run enumeration cap. Daily
queries also exceeded it on busy dates. Those partial samples were not accepted.
Final collection recursively bisected intervals until every leaf query
enumerated exactly its reported `total_count`. All endpoints were explicitly
converted to UTC before formatting; local-time rendering is not a UTC boundary.

The Actions API created-date range may include its upper endpoint. Final
membership was filtered again with `created_at >= start && created_at < end`,
then deduplicated by ID. Every retained run passed membership and count checks.

| UTC start | UTC end | API total | Enumerated unique IDs |
| --- | --- | ---: | ---: |
| 2026-09-14T00:00:00Z | 2026-09-17T12:00:00Z | 273 | 273 |
| 2026-09-17T12:00:00Z | 2026-09-18T09:00:00Z | 735 | 735 |
| 2026-09-18T09:00:00Z | 2026-09-18T19:30:00Z | 613 | 613 |
| 2026-09-18T19:30:00Z | 2026-09-19T06:00:00Z | 555 | 555 |
| 2026-09-19T06:00:00Z | 2026-09-21T00:00:00Z | 749 | 749 |
| 2026-09-21T00:00:00Z | 2026-09-28T00:00:00Z | 267 | 267 |
| 2026-09-28T00:00:00Z | 2026-10-01T12:00:00Z | 138 | 138 |
| 2026-10-01T12:00:00Z | 2026-10-03T06:00:00Z | 420 | 420 |
| 2026-10-03T06:00:00Z | 2026-10-04T03:00:00Z | 426 | 426 |
| 2026-10-04T03:00:00Z | 2026-10-04T05:37:30Z | 646 | 646 |
| 2026-10-04T05:37:30Z | 2026-10-04T08:15:00Z | 361 | 361 |
| 2026-10-04T08:15:00Z | 2026-10-04T13:30:00Z | 227 | 227 |
| 2026-10-04T13:30:00Z | 2026-10-05T00:00:00Z | 132 | 132 |

## Recollection Procedure

For each interval above, execute the following read-only query with its encoded
UTC endpoints. Use `per_page=100`, paginate all pages, and retain `id`,
`run_attempt`, `status`, `conclusion`, `created_at` and `updated_at`.

```powershell
$start = [DateTimeOffset]::Parse('2026-09-21T00:00:00Z').ToUniversalTime()
$end = [DateTimeOffset]::Parse('2026-09-28T00:00:00Z').ToUniversalTime()
$range = [uri]::EscapeDataString(
    "$($start.ToString('yyyy-MM-ddTHH:mm:ssZ'))..$($end.ToString('yyyy-MM-ddTHH:mm:ssZ'))")
gh api "repos/ivegamsft/basecoat/actions/runs?per_page=100&created=$range" --paginate --slurp
```

Compare each response's total with its deduplicated enumeration before accepting
it. On a cap, split the interval again; on an API error or unreconciled count,
report unavailable, not a partial healthy rate. Combine leaf results, enforce
half-open week membership, select one latest observed record per ID and classify
completed success/failure separately from all other statuses/conclusions.
Known zero qualifying runs yields a null ratio; incomplete enumeration yields
null counts and ratio with a named reason. New collection has a new cut and
cannot silently replace this historical evidence.

The reduced collection evidence retained in the originating session has SHA-256
`a0ee5b02e6b7ae9af2f9422453e795c8d6f4f9a3871f5fa902ec7f915c03249d`.
The digest identifies that exact capture, not a publicly retrievable archive.
This document persists the aggregates, query partitions and methodology; raw
private workflow records and credentials are not distributed with it.

## Remaining Decisions

Issue #3530 stays open. This observation does not implement its rolling dashboard,
release cadence reminder, signal-to-noise classifier or closure-note enforcement.
Release eligibility still depends on #3594/#3595; count/age thresholds and write
authority are not guessed from historical merge volume. The proposed contract's
fixed workflow selection, attempt history and approved advisory rollout remain
unimplemented. No secret, assignment, approval, dispatch, merge, tag or release
was created by collection.
