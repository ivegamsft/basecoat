# Portfolio Drift Detection Audit Rules (Sprint 41)

Execution contract for issue #2490. Defines what constitutes drift, how it is measured, what
is reported, and the thresholds that trigger warnings or failures for the portfolio project
automation guardrails. Implemented by `scripts/project-rules-drift-audit.ps1` against the
baseline manifest `scripts/project-rules-baseline.json`; grounded in
[`management-architecture.md`](../management-architecture.md).

## 1. Drift signals

Drift is any divergence between the committed baseline of required project automation rules
and the live project's configured workflows:

| Drift type | Signal |
|---|---|
| `missing` | A baseline-required automation rule has no matching live workflow. |
| `modified` | A matched rule differs from the baseline (enabled-state drift is detected today; condition/action signature drift is deferred, see #2504). |
| `extra` | A live workflow exists with no corresponding baseline rule. |

## 2. Detection thresholds

Each finding carries a severity derived from the baseline rule:

| Finding | Severity source |
|---|---|
| `missing` (required rule absent) | `severity_if_missing` from the baseline rule (`critical`/`high`/`medium`/`low`). |
| `modified-enabled` (required rule disabled) | `severity_if_missing`; other enabled-state changes are `medium`. |
| `extra` | `low`. |

The baseline manifest assigns each rule a `severity_if_missing` across the full
`critical`/`high`/`medium`/`low` domain (for example PRD-008 is `low`), so `low` findings are
in scope and reported even though they do not block.

## 2a. Audit outcome mapping

The scorecard rolls the (SeverityThreshold-filtered) per-finding severities into an overall
audit outcome:

| Condition | Outcome |
|---|---|
| Any `critical` or `high` finding | Fail |
| Any `medium` finding (no critical/high) | Warn |
| Only `low` findings | Warn |
| No findings | Pass |

Enforce mode opens remediation issues (labelled `project-rules-drift` + `governance`) for
findings at or above the configurable `SeverityThreshold` (whose default is `low`, so all
findings are actionable unless the threshold is narrowed). The report emits a single named
machine-readable `outcome` field at `summary.outcome` in `drift-report.json` (`pass`/`warn`/
`fail`) computed from the mapping above, so alerting and downstream consumers gate on it
directly rather than re-deriving from the per-severity counts (which remain available at
`summary.by_severity`). The drift workflow surfaces the same `outcome` in its step summary and
opens/updates a `governance` tracking issue and fails the run when `outcome` is `fail`.

## 3. Ownership and response expectations

- The portfolio governance owner is the DRI for drift remediation.
- `critical`/`high` findings require remediation within the current sprint; `medium` within
  the next sprint; `low` is tracked but not blocking.
- Every enforce-mode finding **at or above the `SeverityThreshold`** maps to a remediation
  issue with an explicit action; findings below the threshold are excluded from the filtered
  outputs and do not open issues.

## 4. Audit outputs

Named, scoped artifacts. In `advisory`/`enforce` runs the findings are first filtered by
`SeverityThreshold`, and both outputs below reflect that filtered set:

- `drift-report.json` (the `-OutputPath` value, default `drift-report.json`) - the persisted
  machine-readable report of record: `summary.outcome` (`pass`/`warn`/`fail`),
  `summary.total_findings`, `summary.by_severity`, `summary.by_drift_type`, and per-finding
  remediation/effort/rationale.
- A human-readable Markdown scorecard of the same (filtered) findings is rendered to stdout
  for the run log; the JSON is the persisted artifact.
- In enforce mode, the remediation issues described in section 2a are the actionable output.

## 5. Determinism and safety

- Findings use stable `finding_id`s so identical inputs produce an identical set of findings
  (the per-run `audit_id` and `generated_at` timestamp naturally vary). Global `finding_id`
  uniqueness is the Wave 2 target: the current exception is `extra` findings, whose id the
  helper derives by replacing every non-alphanumeric character in the live rule name with `-`,
  so distinct names such as `A B` and `A-B` collide to the same id. A collision-safe identifier
  (the live workflow node id or a hash of the name), with tests covering colliding names, is the
  required Wave 2 hardening that establishes the uniqueness invariant.
- Counts are guarded so a drift type with zero matches reports `0` rather than failing.
- Baseline-only mode (no live project) is parse/load-only: it deserializes the baseline JSON
  and skips `Compare-Rules`, so it does not validate the baseline contract. Missing rule
  fields, invalid severities, duplicate IDs/names, or malformed condition/action objects still
  produce a clean report. Adding baseline schema validation (required fields, severity enum,
  unique IDs/names, well-formed conditions/actions) is a Wave 2 enhancement.

## Acceptance criteria mapping

- Drift signals defined -> section 1.
- Detection thresholds documented -> section 2, section 2a (audit outcome mapping).
- Ownership and response expectations documented -> section 3.
- Audit outputs named and scoped -> section 4.
