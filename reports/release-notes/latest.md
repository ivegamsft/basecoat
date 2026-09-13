# Latest Release Notes

## 4.4.0 - 2026-09-11

### Added

- feat(skills): add agentic-cost-audit skill for CI model and token waste (#3343)
- feat(governance): add tracker mutation gates (#3241)
- feat(governance): add task provenance trail (#3240)
- feat(security): add untrusted content boundary (#3239)
- feat(governance): add RAI privacy review (#3238)
- feat(governance): add licensing posture (#3237)
- feat(governance): add advisory standards mapping (#3235)
- feat(governance): enforce config secret examples (#3205)

### Changed

- perf(ci): gate agentic PR review workflows to cut model spend (#3293)

### Fixed

- fix(instructions): scope applyTo to operational surfaces (#3357)
- fix(agents): remove duplicate visibility keys (#3355)
- fix(skill): remove electron pseudo-path applyTo (#3354)
- fix(instructions): align governance alias distribution (#3353)
- fix(backlog-autopilot): map native sub-issue and Parent: dependencies in build-waves (#3352)
- fix(instructions): repair malformed YAML frontmatter (fabric + python) (#3350)
- fix(tests): repair and wire 15 orphaned test suites into the runner (#3322)
- fix(docs): escape placeholder brackets in pathways symptom text (#3312)
- fix(agents): roll model catalog forward to claude-sonnet-5 (#3307)
- fix(triage): fold all triage output into a single comment (#3305)
- fix(ci): honour watchdog suppression labels in release-chain backfill (#3303)
- fix(ci): emit release-chain evidence for auto-merged PRs (#3302)
- fix(docs): correct OAuth onboarding markdown spacing (#3288)
- fix(portal): fail closed for missing GitHub OAuth config (#3283)
- fix(release): keep asset manifest version aligned (#3206)
- fix(workflows): honor targeted spec synthesis dispatch (#3201)

### Documentation

- docs(contributing): clarify distribute marker semantics (#3362)
- docs(pathways): record test-suite-subprocess-tax RCA (#3345)
- docs(pathways): record orphaned-test-suite-drift learning (#3323)
- docs(governance): revise PR creation onboarding scope guidance (#3313)
- docs(learnings): record agent-description derived-artifact pathway (#3310)
- docs(learnings): record agentic-CI and path-filter pathways (#3300)
- docs(intent): add read-only investigate: intent and cost-audit skill spec (#3297)
- docs(portal): add downstream OAuth onboarding guide (#3285)
- docs(inventory): list standards mapping skill (#3236)
- spec: synthesize spec for issue #3118 — Governance enhancement: durable per-task provenance/evidence trail to complement point-in-time audits (#3202)
- docs(changelog): add release notes for 4.3.0 (#3196)
- docs(graph): refresh dependency graph report (#3178)

### Testing

- test(skills): add adjacent negative eval coverage (#3309)

### Maintenance

- chore(ci): regenerate gh-aw locks and assert value consistency (#3306)
- chore(docs): auto-update token context inventory (#3179)

### Other

- Fix hybrid branching skill category conflicts (#3356)
