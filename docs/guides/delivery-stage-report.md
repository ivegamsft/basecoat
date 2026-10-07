# Read-only delivery stage comparisons

`scripts/report-delivery-stages.ps1` adds a report surface beside runner health,
using the existing GitHub CLI authentication and Python metrics conventions.
It never changes workflows, approvals, queue entries, refs, tags, or releases.

## Collect and reproduce

```powershell
pwsh scripts\report-delivery-stages.ps1 -Repository IBuySpy-Shared/basecoat `
  -Start '2026-10-06T23:30:00Z,2026-10-06T23:45:00Z' `
  -End '2026-10-06T23:45:00Z,2026-10-07T00:00:00Z' `
  -OutputPath test-results\delivery-live -MaxRequests 2000
```

Use whole-second UTC, equal nonoverlapping `[start,end)` windows. The output
prefix creates `.capture.json`, `.json`, and `.md`. Reproduce with the same
arguments plus `-FixturePath test-results\delivery-live.capture.json`.
Exit 2 means partial evidence was written, **not** healthy delivery; exit 0
means collection completeness, **not** promotion authorization.

## Evidence and sampling

The cohort is runs **created** within each window, deduplicated by run ID.
All available historical attempts are expanded by `(run ID, attempt)` and
their jobs are paginated. Attempts may execute outside their cohort window.
Actions inventories over 1,000 results recursively partition by UTC seconds;
an overflowing single second, missing page/attempt, request budget, or API
failure marks collection incomplete. Observed counts then are lower bounds.
Capture retains API page counts, boundaries, collection time, and immutable SHAs.
Retention gaps cannot be disproved; convenience samples have no confidence
intervals. Existing runner-health and dashboard metrics remain unchanged.

Execution is job start to completion, never workflow update minus creation.
Checks and packaging use job wall spans, not CPU time. Missing request and
approval timestamps remain null; captured request/approval intervals are
separate, and overlap invalidates acquisition rather than double counting.
Jobs without starts remain unacquired/unknown. Nearest-rank percentiles exclude
negative/missing intervals, and report valid and excluded sample counts.

Eligibility is completed checks to a following successful same-SHA
`BaseCoat merge eligibility` status timestamp for an unambiguous observed PR
target, not a main/merge-group status. PR merge metadata is a point
milestone, not a fabricated merge duration. Release publication joins packaging
only when an explicit full immutable release SHA matches a trusted captured
package target (`package_target` with SHA, source, and URL). Controller workflow
SHAs stay separate and are never inferred as artifact targets; live collection
marks targets unknown. Nonterminal attempts/jobs have no stage end.
Delivery joins PR creation to publication only when the captured PR head,
merge commit, successful packaging target, and immutable release target agree.
PR heads, merge groups, and main remain distinct. Repeat candidates do not
assert equivalent execution, including reruns. Run success never establishes
whether a deployment gate was dry-run or production.

REST lacks historical enqueue and approval/request observations in this
collector. Queue, enqueue, and merge operation intervals
are explicit unknowns unless captured evidence supplies immutable target SHA,
unambiguous run/attempt identity, start/end, source, stage, and evidence URL
in `stage_evidence`. A capture can
include `requested_at`, `approval_started_at`, and `approval_completed_at` on
jobs when those observations exist. These are observations, not estimates.
Captured runs may supply `deployment_mode` (`dry-run` or `production`) with
`deployment_mode_source`; modes remain distinct and neither proves promotion.

## Alerts and limitations

Default fan-out alert: relative increase at least 0.25 runs per known target.
Default cancellation alert: absolute rate increase at least 0.10 per observed
attempt. Override with `-FanoutThreshold` and `-CancellationThreshold`.
Both rates include numerator/denominator; a zero baseline has no relative
increase, only an absolute delta. Two windows indicate change, not a proven
sustained trend. Incomplete alerts are qualified.

Current failures are separate from historical statistics: latest observed
workflow/event/context/branch in the first 100 current runs, with actionable
run links. This bounded snapshot is not a complete current workflow inventory.
Published releases, prereleases, and unknown gate modes are not production
promotion proof. API permission, retention, rate, and network errors produce
explicit incomplete evidence without zero-value healthy fallbacks.

## Validation and rollback

Run `python tests\delivery-report-tests.py`; this is also wired into
`tests\run-tests.ps1`. Validate a captured report, then a small live comparison.
Rollback removes the added report path without altering delivery behavior.
