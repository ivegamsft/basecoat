# Retrospective follow-up requirements

Status: read-only proposal for #3530, dated 2026-10-09. No dashboard, workflow,
threshold, automated issue closure or delivery policy is implemented here.
The original 2026-09-29 through 2026-10-06 retrospective remains historical.

## Existing Ownership and Meaning

Its 14/15 calculation included a skipped run. That figure is a dated
successful-conclusion ratio, not a current executed-check pass rate or proof
of stable CI. The report's zero-release assertion must remain attributable to
its collection evidence; this document does not certify or rewrite it.

Existing #3517 owns truthful collector/consumer measurements; #3590/#3645 own
missed recovery/platform backpressure, and #3690 owns coupled delivery repair.
No generic duplicate incident issues or a competing recovery worker are needed.
The remaining proposals need contracts before runtime implementation.

## Release Cadence Observation

Measure eligible unreleased scope, not every merge. Bind repository, default
branch, exact observation cut, last verified tag/release identity and merged PR
membership. Use the governed release owner's coverage/no-release decisions
under #3594/#3595; unknown eligibility, tag history or coverage is unknown, not
zero unreleased work.

Keep count and age separately: `eligible_unreleased_count` and
`oldest_eligible_age`. Report docs-only/no-release scope, incomplete coverage
and held items distinctly. A candidate release issue or green packaging run
does not reset these measurements; only a verified release covering the named
scope does.

The release owner must choose a count threshold, age threshold, observation
cadence and recipient before reminder automation is enabled. Record them as
configuration, not hard-coded guesses based on 31 historical merges.
Threshold comparison is strictly greater-than unless the approved contract
chooses otherwise; test equality and the first count/time above it.

Deduplicate reminders by repository, verified prior release and eligible-scope
digest. New unrelated merges cannot reset an old reminder's age. Reminders
remain advisory: no tag, packaging dispatch, merge or production permission is
inferred. Empty known scope means no reminder; unavailable history means a
blocked observation with an owner action.

## Rolling CI Trend

Use fixed UTC half-open intervals `[start, end)` over a configured number of
complete weeks. Bind repository, workflow population, event/branch filters,
API pagination completeness, observation time and sampling limits. Do not
compare mismatched populations or silently use the latest N runs as a week.

Proposed execution sample: completed runs whose conclusion is `success` or
`failure`. Report cancelled, skipped, timed-out, action-required, stale and
unknown conclusion counts separately. This narrow trend is explicitly an
executed success/failure ratio, not all delivery reliability; timeouts and
cancellations remain visible and cannot be marketed as healthy CI.

Deduplicate a logical workflow run by run ID; select the latest observed
attempt by the cut first, then include it in the ratio only if completed
with `success` or `failure`. Report retry attempts independently so reruns
cannot inflate the denominator or conceal first-attempt instability.
Pending latest attempts cannot be borrowed from an older green attempt.

| Observation | Required representation |
| --- | --- |
| Known success/failure sample | Success / (success + failure), with counts and population |
| No qualifying runs, complete enumeration | Null rate, known zero sample, not 0% failure or 100% health |
| Permission/API/pagination failure | Unavailable interval, null counts/rate, explicit reason |
| Cancelled/skipped/timeout-only interval | Null execution rate; excluded conclusion counts remain visible |
| Changed filters, cut or workflow population | Non-comparable, not an improvement/regression |

Freshness comes from the current collection cut and exact interval identity.
Keep historical unavailable gaps null; do not coerce them to zero in charts or
averages. #3517's nullable contract is reusable but does not implement this
multi-week population selector.

## Automation Signal-to-Noise

Separate incident family, trigger/root-cause evidence and resolution class.
Labels alone cannot prove false positive, flaky infrastructure or recurring
root cause. Deduplicate exact incident fingerprints and report reopen/retry
counts rather than counting copied issues as unique defects.

Disposition classes are confirmed defect, expected governance hold, transient
transport, evidence unavailable and unclassified. Each has an evidence URL,
exact run/head/attempt and owner. Expected holds must remain truthful non-success
for admission; reducing alert noise cannot suppress required checks or secrets
scanning. #3699's transport failure is an example, not a universal classifier.

## Closure Notes and Exceptions

Start with read-only assessment of closed issues. Bind issue, closing event ID,
actor, reason, timestamp and resolution evidence; a mere latest comment may be
unrelated or after the closure. Distinguish manual completion, auto-close by
merged PR, duplicate/not-planned, managed standing report and external-owner
closure. A merged design proposal cannot prove runtime acceptance.

Count unresolved evidence as unknown/needs-owner, not proof of invalid closure.
Use the exact closing PR/commit and its source criteria where applicable;
release-required items remain incomplete until their release evidence exists.
Preserve managed report ownership; never reopen or close all issues in a label
bucket, or erase a human's concurrent disposition automatically.

The governance owner must approve event selection, evidence rules, exceptions,
write authority and anti-loop behavior before enforcement. Read-only detection
may propose an owner comment but does not create/revoke approval, assign work or
mutate closure state. Retain original closure evidence for audit.

## Acceptance, Failure and Delivery Sequence

Fixtures must cover exact threshold boundaries, no-release scope, held/unknown
eligibility, tag replacement, partial release, empty intervals, skipped-only
samples, retry/pending attempts, inaccessible pages and changed populations.
Closure fixtures cover each actor/event class, missing evidence, contradictory
comments, reopen/reclose loops and concurrent human disposition.

Each proposed measurement must include explicit unavailable reasons, scope
digest, collection cut and bounded retry state. A partial API response cannot
be returned as a complete healthy report. Preserve redaction; no tokens or full
private bodies belong in trend/reminder output.

Next sequence is requirements review, source-scoped implementation issues and
artifact contracts, read-only controlled fixtures, then separately authorized
advisory rollout. Enforcement and release automation need independent decisions.
Rollback disables new observation/reminder producers and preserves history;
it does not reopen issues, revoke authority or retarget releases.

## References

- #3530 original retrospective and its dated collection window.
- [Nullable metric meanings](../reference/metrics-schema-glossary.md).
- [Release gate caller boundaries](../guides/ship-it-control-plane.md).
- [Issue and PR governance](../reference/governance-contract.md).
