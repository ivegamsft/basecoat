# Intent2Prod Learning Log

**Control Plane Issue**: [#1874](https://github.com/IBuySpy-Shared/basecoat/issues/1874)  
**Program**: Intent2Prod — contract-driven, governed execution loop for ship-it automation

---

## Run 1 Summary (June 2026)

**Sprints completed**: 1, 2, 3  
**Tracks completed**: A (Intent Contract), B (Goal-Loop Engine)  
**PRs merged**: #1955, #1958  
**Issues closed**: #1875, #1876, #1877, #1853, #1857

---

## What Worked Well

1. **Additive docs-first approach**: Starting with architecture spec (Sprint 1) before implementation (Sprint 2) kept scope clear and CI checks green on first attempt.

2. **Serialized sprint merge pattern**: Waiting for Sprint 1 to merge before starting Sprint 2 prevented merge conflicts and kept the branch tree clean.

3. **Detached HEAD workaround**: Using `git checkout -b feat/<branch> origin/main` from a detached HEAD worktree is reliable; avoid `git checkout main` in multi-worktree setups.

4. **goal-loop-engine as a diagnostic**: The state machine engine in `scripts/ship-it/goal-loop-engine.ps1` provides a repeatable way to answer "where are we?" for any control-plane run without needing to manually inspect all three sprint issues.

5. **sprint:42 label auto-creation**: The release-label-gate was satisfied by creating the label before the PR — this pattern should be automated in future runs (pre-flight label creation step).

---

## What Needs Improvement

1. **Tracks C–F not implemented**: This run only covered Tracks A and B. Tracks C (PR hygiene), D (build-break recovery), E (release gates), and F (artifact completeness) remain as follow-up work. The architecture-baseline.md spec covers them, but no scripts or workflows have been created.

2. **Dispatch-intent.ps1 does not validate against Intent Contract v1**: The dispatcher script (`scripts/ship-it/dispatch-intent.ps1`) predates the intent contract spec. Future work should add schema validation at dispatch time.

3. **Goal-loop engine requires manual invocation**: There is no CI trigger for the engine. Future work should wire it into the ship-it workflow or a scheduled job to auto-report stale control-plane runs.

4. **Pilot onboarding deferred**: All three pilots (luxesite #1851, wawkr #1852, work-tracker #1855) are blocked on Track C–F completion. They should be re-activated once the automation tracks are built.

5. **Autonomy band configuration not yet enforced**: The intent contract v1 defines autonomy bands A0–A5, but no enforcement mechanism exists in the dispatch workflow yet. The goal-loop engine reports the band from issue metadata but does not gate actions on it.

---

## Follow-Up Issues to Open

| Priority | Topic | Notes |
|----------|-------|-------|
| High | Track C — PR/Merge Hygiene | Depends on architecture-baseline.md Track C section |
| High | Track D — Build-Break Auto-Recovery | Depends on Track C baseline |
| Medium | Track E — Release Gate Enforcement | Can start in parallel with Track D |
| Medium | Track F — Artifact Completeness | Can start in parallel with Track E |
| Low | Dispatch-intent schema validation | Integrate intent-contract-v1.md into dispatch-intent.ps1 |
| Low | Automate goal-loop status reporting | Wire engine into scheduled workflow |
| Low | Pilot onboarding (luxesite, wawkr, work-tracker) | Re-activate after Tracks C–F complete |

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
