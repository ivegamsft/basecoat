# Failure Pattern Consumer Process

## Purpose

Define a reusable, evidence-first process for consumer repositories, based on the successful wawkr flow:

1. Mine failure patterns
2. Log raw findings without pruning
3. Triage common versus repo-specific patterns
4. Produce a prioritized enhancement plan with early-detection gates

## Required Inputs

- Repository scope and branch or commit window
- Evidence sources (issues, PRs, CI runs, logs, incidents, comments)
- Time window for analysis
- Run owner

## Process Phases

| Phase | Objective | Required Artifacts | Evidence Standard | Quality Gate |
|---|---|---|---|---|
| 1. Mine failure patterns | Collect all candidate failure signals from source evidence | `A1-source-index`, `A2-pattern-candidates` | Every candidate links to a source URL or file path plus timestamp | Gate 1 passes when source coverage and traceability are complete |
| 2. Log raw findings (no pruning) | Preserve complete extracted findings before interpretation | `B1-raw-findings-log` | Raw log is append-only, includes duplicates/noise, and preserves original wording where possible | Gate 2 passes when no entries are removed or merged pre-triage |
| 3. Triage common vs repo-specific | Classify each finding into reusable common pattern or local repo-specific condition | `C1-triage-matrix`, `C2-classification-rationale` | Every classification has rationale and linked evidence from Phase 2 | Gate 3 passes when all findings are classified or explicitly marked unknown |
| 4. Prioritized enhancement plan with early-detection gates | Convert triaged patterns into ranked, actionable improvements and prevention checks | `D1-enhancement-backlog`, `D2-early-detection-gates` | Each item has priority, owner recommendation, expected signal, and validation method | Gate 4 passes when top priorities include at least one early-detection gate per high-risk pattern class |

## Required Artifacts

1. Source index with provenance (`A1-source-index`)
2. Pattern candidate extract (`A2-pattern-candidates`)
3. Raw findings log (`B1-raw-findings-log`)
4. Triage matrix (`C1-triage-matrix`)
5. Classification rationale notes (`C2-classification-rationale`)
6. Prioritized enhancement backlog (`D1-enhancement-backlog`)
7. Early-detection gate catalog (`D2-early-detection-gates`)

## Evidence Rules

- No unlinked claims: each statement traces to evidence.
- No silent pruning in Phase 2.
- No merged classifications without rationale in Phase 3.
- No plan item without measurable validation in Phase 4.

## Quality Gates

### Gate 1: Mining completeness

- Required evidence sources are present.
- Candidate list has source provenance and timestamps.

### Gate 2: Raw log integrity

- Raw findings are unfiltered and append-only.
- Duplicate and conflicting findings are retained.

### Gate 3: Triage quality

- Findings are partitioned into common, repo-specific, or unknown.
- Unknown items include follow-up questions.

### Gate 4: Plan readiness

- Enhancements are prioritized by impact and recurrence risk.
- Early-detection gates are defined with trigger, owner, and expected action.
- Top-priority items are implementation-ready for downstream automation work.

## Exit Criteria

A process run is complete only when all four gates pass and all required artifacts are present with evidence links.

## #2047 Outcome Mapping (Smallest Viable Slice)

When this process is used to execute workstream 2
([#2047](https://github.com/ivegamsft/basecoat/issues/2047)), treat the
following as required completion mapping:

| Issue #2047 outcome | Process artifact expectation |
|---|---|
| Top 3 recurring failure modes are triaged with owner + RCA + fix plan | `C1-triage-matrix` includes at least 3 ranked recurring failure classes; each includes `owner`, `rca_link`, and `fix_plan_link` |
| MTTR trend improves by >=20% versus captured baseline | `run-summary` records `mttr_baseline_hours`, `mttr_current_hours`, and `mttr_improvement_pct`; trend target met at `>=20%` |
| Recurrence rate for fixed failure classes is <=10% over a 2-week window | `run-summary` records `recurrence_rate_2w_pct` for fixed classes and verifies `<=10%` |

Use this formula for deterministic recurrence calculation in the 2-week
validation window:

`recurrence_rate_2w_pct = (repeat_incidents_after_fix / total_incidents_after_fix) * 100`

## Out of Scope

- Implementing agents, skills, scripts, or workflows
- Applying repository code changes from the enhancement plan
- Pruning historical evidence before triage completion
