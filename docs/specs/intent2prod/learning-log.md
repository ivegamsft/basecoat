# Intent2Prod Learning Log

**Control Plane Issue**: [#1874](https://github.com/IBuySpy-Shared/basecoat/issues/1874)  
**Program**: Intent2Prod — contract-driven, governed execution loop for ship-it automation

---

## Run 1 Summary (June 2026)

**Sprints completed**: 1, 2, 3  
**Tracks completed**: A-F (Intent Contract, Goal-Loop Engine, PR hygiene, build-break recovery, release gates, artifact completeness)  
**PRs merged**: #1955, #1958, #2063, #2064, #2065, #2066  
**Issues closed**: #1875, #1876, #1877, #1853, #1857, #1849, #1856, #1848, #1850

---

## What Worked Well

1. **Additive docs-first approach**: Starting with architecture spec (Sprint 1) before implementation (Sprint 2) kept scope clear and CI checks green on first attempt.

2. **Serialized sprint merge pattern**: Waiting for Sprint 1 to merge before starting Sprint 2 prevented merge conflicts and kept the branch tree clean.

3. **Detached HEAD workaround**: Using `git checkout -b feat/<branch> origin/main` from a detached HEAD worktree is reliable; avoid `git checkout main` in multi-worktree setups.

4. **goal-loop-engine as a diagnostic**: The state machine engine in `scripts/ship-it/goal-loop-engine.ps1` provides a repeatable way to answer "where are we?" for any control-plane run without needing to manually inspect all three sprint issues.

5. **sprint:42 label auto-creation**: The release-label-gate was satisfied by creating the label before the PR — this pattern should be automated in future runs (pre-flight label creation step).

---

## What Needs Improvement

1. **Lane policy overlays need ongoing calibration**: pilot lanes can enforce stricter checks than risk-band defaults; keep lane rules narrow to avoid unnecessary promotion friction for non-pilot runs.

2. **Dispatch-intent.ps1 does not validate against Intent Contract v1**: The dispatcher script (`scripts/ship-it/dispatch-intent.ps1`) predates the intent contract spec. Future work should add schema validation at dispatch time.

3. **Goal-loop engine requires manual invocation**: There is no CI trigger for the engine. Future work should wire it into the ship-it workflow or a scheduled job to auto-report stale control-plane runs.

4. **Pilot onboarding sequencing remains important**: luxesite (#1851) is now active on the completed C-F control plane, while wawkr (#1852) and work-tracker (#1855) still require staged activation and evidence baselines.

5. **Autonomy band configuration not yet enforced**: The intent contract v1 defines autonomy bands A0–A5, but no enforcement mechanism exists in the dispatch workflow yet. The goal-loop engine reports the band from issue metadata but does not gate actions on it.

---

## Follow-Up Issues to Open

| Priority | Topic | Notes |
|----------|-------|-------|
| High | Pilot luxesite stabilization | Verify lane-aware dispatch artifacts and strict release-gate overlays for #1851 |
| Low | Dispatch-intent schema validation | Integrate intent-contract-v1.md into dispatch-intent.ps1 |
| Low | Automate goal-loop status reporting | Wire engine into scheduled workflow |
| Low | Pilot onboarding (wawkr, work-tracker) | Sequence activation after luxesite pilot evidence stabilizes |

---

## Run 2 Summary (Wawkr Canary Onboarding — #1852)

**Issues implemented**: #1852 (wawkr canary pilot activation)  
**Deliverables**: Profile registration, lane policies, test coverage, doc updates  
**Implementation approach**:

1. Added `pilot-wawkr` profile to `dispatch-intent.ps1` with canary-specific configuration
2. Registered `pilot-wawkr` execution lane in `release-gate-enforcer.ps1` with same strict requirements as luxesite
3. Defined stage-specific canary lanes (baseline, contract, deployment, validation) aligned to onboarding conductor phases
4. Extended test scenarios to exercise wawkr canary requirements (gates and artifacts)
5. Updated workflows and docs to expose pilot-wawkr as onboarding profile option

**Key Design Decisions**:

- Wawkr uses identical gate and artifact policies to luxesite (both require all 6 gates + 5 artifacts)
- Canary stage lanes named `pilot-wawkr-canary-*` to signal execution context
- Tests validate both full-pass and blocking scenarios (missing gates/artifacts, gate failures)

---

## Metrics

| Metric | Value |
|--------|-------|
| Sprint velocity | 2 tracks per sprint cycle |
| CI first-pass rate | 100% (no rework needed after lint/test failures) |
| Time to first merge | ~2h (Sprint 1: arch baseline) |
| Time to second merge | ~1h (Sprint 2: contract + engine) |
| Total files added | 4 (architecture-baseline.md, intent-contract-v1.md, goal-loop-engine.ps1, release-notes.md) |
| Blocking issues encountered | 1 (detached HEAD state — workaround documented) |
