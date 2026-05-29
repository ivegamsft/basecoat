---
description: ".NET modernization test strategy and regression-gate guidance."
applyTo: "**/*.{sln,csproj,props,targets,cs,yml,yaml}"
---

# .NET Test Strategy

## Objective

Define and enforce a test strategy that protects behavior, performance, and operability during .NET modernization.

## Rules

- Tie every migration phase to explicit unit, integration, and end-to-end coverage.
- Protect critical business paths first when baseline coverage is incomplete.
- Define measurable regression gates for behavior, latency, and deployment readiness.
- Keep CI gates fast enough for every pull request and reserve heavier suites for release promotion.

## Required steps

1. Establish baseline test coverage and identify critical business paths.
2. Map unit, integration, and end-to-end coverage to each migration phase.
3. Add regression criteria for API behavior, data access, and performance.
4. Require CI quality gates before phase promotion.

## Examples

### Example phase test matrix

```text
Phase                    Required coverage                            Promotion gate
Package upgrades         Unit + smoke integration                     No API contract regressions
Runtime upgrade          Unit + integration + perf baseline           P95 latency within agreed threshold
Deployment cutover       Synthetic health checks + rollback rehearsal Production validation complete
```

### Example CI gate

```yaml
- name: .NET regression gate
  run: |
    dotnet test tests/Unit/UnitTests.csproj --configuration Release
    dotnet test tests/Integration/IntegrationTests.csproj --configuration Release --filter "Category!=Flaky"
```

## Output expectations

- Phase-by-phase test matrix
- Entry/exit criteria for each modernization wave
- Post-deployment validation checks and rollback triggers
