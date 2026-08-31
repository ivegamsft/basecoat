# Failure Pattern Run Contract

## Contract Purpose

Provide a concise, scriptable contract for running the failure pattern process from intake through prioritized planning.

## Inputs

- `repo_name`: target repository
- `analysis_window`: start and end dates or commit range
- `evidence_sources`: issue, PR, CI, incident, log, and comment sources
- `run_id`: unique run identifier
- `owner`: accountable operator

## Outputs

- `A1-source-index`
- `A2-pattern-candidates`
- `B1-raw-findings-log` (no pruning)
- `C1-triage-matrix`
- `C2-classification-rationale`
- `D1-enhancement-backlog`
- `D2-early-detection-gates`
- `run-summary` (gate results and next-action handoff)

## Workstream 2 Minimum Reliability Slice (#2047)

For the smallest viable implementation of the reliability-debt program under
epic [#1452](https://github.com/ivegamsft/basecoat/issues/1452), each run
must explicitly satisfy the [#2047](https://github.com/ivegamsft/basecoat/issues/2047)
outcome contract:

1. **Top 3 recurring failure modes triaged** with owner, RCA record, and fix
   plan link.
2. **MTTR baseline captured** and current trend computed against baseline.
3. **Recurrence rate measured** for fixed failure classes over a 2-week window.

Required `run-summary` fields (must be present and non-empty):

- `top3_failures`: array of exactly 3 records
  - `failure_mode`
  - `owner`
  - `rca_link`
  - `fix_plan_link`
- `mttr_baseline_hours`
- `mttr_current_hours`
- `mttr_improvement_pct`
- `recurrence_rate_2w_pct`
- `meets_issue_2047_targets` (boolean)

Target thresholds for `meets_issue_2047_targets=true`:

- `mttr_improvement_pct >= 20`
- `recurrence_rate_2w_pct <= 10`

## Canonical Stage Model

`queued -> mining -> raw_logged -> triaged -> planned -> completed`

Failure state:

`* -> blocked`

## Stage Transition Rules

| From | To | Required Condition | Required Artifact Check |
|---|---|---|---|
| queued | mining | Inputs validated | `repo_name`, `analysis_window`, and source list present |
| mining | raw_logged | Pattern candidates extracted | `A1-source-index` and `A2-pattern-candidates` present |
| raw_logged | triaged | Raw logging complete with no pruning | `B1-raw-findings-log` present and append-only |
| triaged | planned | Classification complete | `C1-triage-matrix` and `C2-classification-rationale` present |
| planned | completed | Prioritized plan and gates finalized | `D1-enhancement-backlog`, `D2-early-detection-gates`, and `run-summary` present |
| any | blocked | Missing inputs, missing evidence, or gate failure | Block reason recorded with owner and unblock action |

## Issue Title Patterns

- Run tracking issue: `Failure Pattern Run: <repo_name> (<analysis_window>)`
- Blocked run issue or comment: `Failure Pattern Run Blocked: <repo_name> (<run_id>)`
- Plan handoff issue: `Failure Pattern Enhancements: <repo_name> (<run_id>)`

## Issue Body Template (Run Tracking)

```markdown
## Run Metadata
- Run ID:
- Repo:
- Analysis Window:
- Owner:

## Stage
- Current Stage:
- Gate Status: Gate1 | Gate2 | Gate3 | Gate4

## Artifacts
- [ ] A1-source-index
- [ ] A2-pattern-candidates
- [ ] B1-raw-findings-log (no pruning)
- [ ] C1-triage-matrix
- [ ] C2-classification-rationale
- [ ] D1-enhancement-backlog
- [ ] D2-early-detection-gates
- [ ] run-summary

## Blockers
- None | <block reason>

## Evidence Links
- <links>
```

## Quality Gate Enforcement

- Gate 1 enforces source provenance and mining completeness.
- Gate 2 enforces raw-log integrity and no-pruning policy.
- Gate 3 enforces evidence-backed classification.
- Gate 4 enforces prioritized planning plus early-detection gate definitions.
- Gate 4 also enforces the Workstream 2 minimum-slice fields when the run is
  tied to issue #2047.

## Non-Goals

- Creating or modifying agent, skill, or script implementations
- Auto-remediating code from findings within this contract

## Scripted Issue Artifact Generation

Use repository scripts for deterministic, non-destructive issue artifact generation:

- `pwsh scripts\generate-failure-pattern-raw-findings-issue.ps1`
  - Required inputs: `RepoName`, `AnalysisWindow`, `RunId`, `Owner`, `SourceEvidence`, `PatternCandidatesRef`, `RawFindingsLogRef`
  - Default title pattern: `Failure Pattern Run: <repo_name> (<analysis_window>)`
- `pwsh scripts\generate-failure-pattern-triage-plan-issue.ps1`
  - Required inputs: `RepoName`, `RunId`, `RawIssueReference`, `TriageMatrixRef`, `ClassificationRationaleRef`, `CommonPatternsRef`, `RepoSpecificPatternsRef`, `EnhancementBacklogRef`, `EarlyDetectionGatesRef`, `RunSummaryRef`
  - Default title pattern: `Failure Pattern Enhancements: <repo_name> (<run_id>)`
- `pwsh scripts\link-failure-pattern-issues.ps1`
  - Required inputs: `RepoName`, `RawIssueNumber`, `PlanIssueNumber`, `RunId`
  - Generates copy/paste linkage comments for both issues by default (`Mode=both`)
