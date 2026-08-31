# Keep/Fix/Throttle Adoption Experiment Plan

**Issue:** [#2051](https://github.com/ivegamsft/basecoat/issues/2051)  
**Parent Epic:** [#1452](https://github.com/ivegamsft/basecoat/issues/1452)  
**Owner:** @ibuyspy  
**Experiment Window:** 4–6 weeks (2026-06-25 to 2026-08-06)

## Objective

Validate the Keep/Fix/Throttle operating model by running a time-boxed adoption experiment with explicit thresholds for success/failure. Measure throughput, failure rates, and incident frequency before and during the experiment to inform go/no-go decisions.

## Success Criteria

The experiment succeeds if **all three conditions** are met by the end of the window:

1. **Baseline captured:** Start-of-experiment metrics recorded and experiment window defined ✓
2. **Velocity impact:** Net merged PR velocity ≥ baseline (no regression)
3. **Failure control:** Workflow failure rate and incident rate remain within target bounds:
   - Failure rate: ≤ 2% (baseline: 0%, tolerance: +2%)
   - P0/P1 incident rate: ≤ 7 per 30 days (baseline: 7 per 30 days, stable)

## Baseline Snapshot (2026-06-25)

Captured before rollout of workstreams 1–4; used as the experiment start point.

| Metric | Baseline | Target | Collection window |
|--------|----------|--------|-------------------|
| Throughput (merged PRs/day) | 10.0 | ≥10.0 | Last 30 days |
| Workflow failure rate | 0.0% | ≤2.0% | Last 14 days |
| Manual intervention proxy (approved PR share) | 100.0% | <95% (improvement signal) | Last 30 days |
| Open P0 incidents | 0 | ≤1 | Snapshot |
| Open P1 incidents | 1 | ≤3 | Snapshot |
| P0/P1 incident creation rate | 7 in 30 days | ≤7 per 30 days | Last 30 days |

## Experiment Phases

### Phase 1: Prepare (Week 0)

- Finalize experiment plan and baseline metrics (this document)
- Publish adoption experiment plan artifact
- Configure weekly scorecard workflow ([#2050](https://github.com/ivegamsft/basecoat/issues/2050))
- Complete workstreams 1–4 rollout

### Phase 2: Run (Weeks 1–5)

- Execute workstreams 1–4 changes in production
- Collect weekly scorecards with trend tracking
- Respond to any P0/P1 incidents immediately
- Record observational notes about adoption friction

### Phase 3: Readout (Week 6)

- Compile final metric summary
- Compare end-of-experiment metrics to baseline
- Document go/no-go decision: "Keep," "Fix and retry," or "Throttle"
- Publish recommendations for Q3 planning

## Measurement

### Weekly Scorecard Cycle

1. Workflow: `.github/workflows/keep-fix-throttle-weekly-scorecard.yml` runs every Monday 08:00 UTC
2. Generates scorecard artifact with trend classification (improving/stable/regressing)
3. Posts readout comment to [#2050](https://github.com/ivegamsft/basecoat/issues/2050)
4. Runbook: `docs/operations/keep-fix-throttle-weekly-scorecard.md`

### Go/No-Go Decision Logic

| Scenario | Decision | Action |
|----------|----------|--------|
| All metrics meet targets AND no P0 incidents | **KEEP** | Adopt defaults into governance; close experiment |
| Velocity or failure metrics miss targets | **FIX AND RETRY** | Identify root cause; iterate on workstreams 1–4; restart experiment |
| P0 incident rate exceeds ≥2 per week average | **THROTTLE** | Pause rollout; implement safeguards; set 2-week observation window before retry |

## Scope

### Included (Rollout Scope)

- Workstream 1: Standardize proven patterns as defaults
- Workstream 2: Reliability debt program for recurring failures
- Workstream 3: Tooling routing matrix (local/background/cloud/manual)
- Workstream 4: Risk-tier autonomy policy enforcement

### Excluded

- Workstreams 5–6 (scorecard and this experiment plan)
- Unrelated feature development
- Emergency hotfixes (continue as-is)

## Reporting

Weekly readout target: [Issue #2050](https://github.com/ivegamsft/basecoat/issues/2050)

Each readout includes:

- Metric snapshot (throughput, failure rate, MTTR, manual intervention)
- Trend classification (improving/stable/regressing)
- Remediation links for regressions
- Observational notes from the team

## Exit Criteria

Experiment closes when:

1. **Success:** All three success criteria met → adopt defaults into governance
2. **Failure:** Metrics miss targets by >10% for ≥2 consecutive weeks → halt and replan
3. **Blocker:** P0 incident rate exceeds 2 per week for ≥1 week → implement throttle, retry after 2 weeks

## Notes

- Baseline snapshot location: `docs/operations/keep-fix-throttle-model.md`
- Spec for weekly scorecard: `docs/spec/keep-fix-throttle-weekly-scorecard.spec.md`
- Related PRD: `docs/guides/prd-and-spec-guidance.md`
