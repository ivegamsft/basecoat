# Learning Promotion and Memory Hygiene Criteria (Sprint 41)

Execution contract for issue #2492. Defines how learning candidates are collected, what
qualifies for promotion, the evidence required, and when stale items are rejected or cleaned
up. Grounded in [`audit-learning-memory.md`](../audit-learning-memory.md) and the
learning-to-memory promotion pipeline (`scripts/aidl-learning-memory-promotion.ps1`, validated
by `tests/aidl-learning-memory-promotion-tests.ps1`).

## 1. Candidate extraction rules

Pattern candidates are harvested from completed delivery, incidents, and retrospectives and
evaluated against these quality checks. Each candidate declares a `sourceType`, which must be
one of the four supported classes: `sprint`, `incident`, `review`, or `governance`; any other
value is rejected as an unsupported source. A candidate that fails a check is not discarded
silently; it flows to the decision model (section 2), where, for example, an unsourced
candidate is assigned `reject`.

| Check | Rule |
|---|---|
| Evidence-backed | Cites at least one non-empty source string (PR, incident, retro); a candidate with no evidence link is rejected. Deep validation of citation format and resolvability is a Wave 2 target (see section 3). |
| Reusable | Applies beyond the originating task. Reuse is not an independent admission gate: the pipeline admits a candidate only when it clears the ephemeral-noise safeguard in section 2 (`recurrence >= MinimumRecurrence` AND `impact >= MinimumImpact`), so team breadth alone cannot admit a low-recurrence candidate. Reuse instead feeds the reuse score component (higher for `affectedTeams >= 2` or `recurrence >= 4`), influencing the promote/hold/reject band rather than pass/fail admission. |
| Non-duplicate | Not already represented in a pending candidate or prior memory. The current pipeline performs no duplicate detection: it evaluates and appends every candidate without tracking the normalized `(sourceType, title, pattern)` tuple, so duplicate inputs produce duplicate evaluations, ledger rows, and packets. All duplicate detection is a Wave 2 target: within-batch dedup requires comparing the normalized tuple across the input batch, and cross-run dedup additionally requires persisting that tuple in the ledger row schema and loading/merging prior ledger entries (comparison against arbitrary target assets further requires a canonical index). |
| Scoped | Resolves to a candidate ID and a target asset path, both derived outputs. When no `id` is supplied the pipeline currently fills a random GUID fragment (`candidate-<guid8>`), so reprocessing the same candidate yields a different ID, subject, and target path. For deterministic traceability and deduplication, callers must supply a stable `id` (or the pipeline must derive it from the normalized `(sourceType, title, pattern)` tuple above). |

## 2. Promotion decision outcomes

Every candidate resolves to exactly one outcome:

| Decision | Entry criteria | Required metadata |
|---|---|---|
| `promote` | Score at/above the promote threshold with validated source evidence. | Approver, rationale, target asset path. |
| `hold` | Score in the hold band (below promote, above reject) or unresolved confidence. | Reviewer, missing-evidence note, re-review date. |
| `reject` | Score below the reject threshold, unsourced, or superseded. | Reviewer, rejection rationale. |

Promotion is never applied automatically: the pipeline scores each candidate (default
`promote` at score >= 70, `hold` at 45-69, `reject` below 45) and records a recommended
decision as pending approval (for example `memory-curator (pending approval)`). A `promote`
recommendation still requires an explicit approver to finalize. The pipeline emits these
decisions as lowercase values (`promote`/`hold`/`reject`).

The score is deterministic. A candidate must first pass all safeguard gates (required fields
`title`/`pattern`/`resolution`/`outcome`, at least one evidence link, supported `sourceType`,
`recurrence >= 0`, `impact` in 1-5, no sensitive content, and not filtered as ephemeral noise
where `recurrence < MinimumRecurrence` or `impact < MinimumImpact`); any gate failure forces
`reject` regardless of score. For a candidate that passes the gates, the total score is the
sum (capped at 100) of five components:

- Recurrence: `min(40, recurrence * 10)`.
- Impact: `min(30, impact * 6)`.
- Evidence: `min(10, evidenceCount * 3)`.
- Reuse: `10` if `affectedTeams >= 3`, `7` if `affectedTeams == 2`, `5` if `recurrence >= 4`,
  otherwise `2`.
- Source weight: `incident` = 15, `governance` = 12, `sprint` = 10, `review` = 8.

The resulting score maps to `promote` (>= 70), `hold` (45-69), or `reject` (< 45) using the
default thresholds above.

## 3. Adoption evidence requirement

- Promotion currently requires at least one non-empty evidence string; the pipeline does not
  yet parse or resolve citations, so a malformed or non-resolving reference still passes.
  Defining and enforcing an evidence-validation predicate (allowed URL/file-reference formats
  and whether references must resolve) is a Wave 2 target so the promotion requirement is
  testable. Each promoted candidate must carry an owned adoption-tracking commitment: the
  pipeline emits an `adoption-impact-tracking` plan so downstream usage is verified after
  promotion rather than assumed at publication.
- Per issue #2492, adoption evidence is required *for* promotion: before a candidate is
  finalized as `promote`, the approver must confirm (a) at least one concrete adoption signal
  as defined in `audit-learning-memory.md` (a linked consumer artifact or observed workflow
  uptake demonstrating the pattern is already used), and (b) an established adoption-tracking
  commitment (the emitted `adoption-impact-tracking` plan naming the metric, baseline, target,
  and 30-day checkpoint). The tracking plan alone expresses intent, not realized adoption, and
  does not by itself satisfy the requirement. Post-promotion validation then verifies continued
  downstream usage against that commitment and demotes to `hold` if usage lapses.
- The tracking checkpoint occurs 30 days after promotion (`review_after_days = 30` in the
  emitted `adoption-impact-tracking` plan). Encoding this explicit interval ensures every
  implementation demotes the same candidate at the same time.
- The emitted `adoption-impact-tracking` plan currently carries the candidate, metric,
  baseline, target, checkpoint, and source artifact but no owner, so the ownership requirement
  above cannot yet be validated from the plan. Adding an `owner` field to the plan and
  requiring it before final promotion is the required Wave 2 hardening.

## 4. Cleanup rules for stale items

- Candidates in `hold` past their re-review date with no new evidence are rejected. The
  re-review date is defined as the evaluation timestamp plus a fixed 30-day interval (the same
  interval as the adoption checkpoint in section 3). The current pipeline does not yet emit a
  re-review date on `hold` recommendations, so populating this derived field is a Wave 2 target
  required to make this stale-item rule deterministically testable.
- Memory entries whose citations no longer resolve (dead PR/file references) are flagged for
  removal. A stale or superseded pattern is deprecated with a replacement link (per
  `audit-learning-memory.md`) rather than deleted outright, preserving the migration path; an
  entry is not removed without either a recorded replacement or an explicit no-replacement
  rationale.
- Superseded or duplicate memory entries are consolidated; the retained entry is the one with
  the most recent `evidence_recorded_at` (ISO-8601 UTC) among the evidence-backed matches. When
  that field is absent or tied, the sole deterministic tie-break is the lexicographically
  greatest `id` (a stable, order-independent field), so the same duplicate set always retains
  the same entry regardless of input order or which run merged it. Consumers must supply
  `evidence_recorded_at` for reliable recency-based consolidation.
- Cleanup actions are recorded with reviewer and rationale for auditability.

## 5. Audit outputs

- A learning-and-memory scorecard listing candidates, decisions, adoption evidence, and
  cleanup actions, scored by the pass/warn/fail dimensions in `audit-learning-memory.md`.

## Acceptance criteria mapping

- Candidate extraction rules defined -> section 1.
- Promotion decision outcomes defined -> section 2.
- Adoption evidence required for promotion -> section 3.
- Cleanup rules for stale items defined -> section 4.
