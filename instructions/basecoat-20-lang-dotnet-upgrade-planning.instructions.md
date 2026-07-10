---
description: ".NET upgrade planning checklist and phased execution guidance."
applyTo: "**/*.{sln,csproj,props,targets,cs,json,yml,yaml}"
---

# .NET Upgrade Planning

## Objective

Produce a phased, low-risk upgrade plan from current .NET targets to a supported modern target.

## Rules

- Define the target SDK and runtime first, then evaluate every project against that destination.
- Sequence upgrades so shared libraries and build infrastructure move before dependent applications.
- Capture rollout gates, rollback conditions, and owner approval for each phase.
- Call out packages, hosting dependencies, or operating systems that can block the runtime move.

## Required steps

1. Inventory current frameworks, SDKs, runtimes, and package dependencies.
2. Identify unsupported or end-of-life components and classify risk.
3. Define the target runtime and migration sequencing by project boundaries.
4. Add explicit quality gates for build, tests, and deployment validation at each phase.
5. Add rollback criteria and contingency paths for each deployment wave.

## Examples

### Example phased plan

```text
Phase 1: Upgrade shared packages and build agents to the target SDK
Phase 2: Move class libraries from net6.0 to net8.0 and rerun integration tests
Phase 3: Upgrade web apps, deploy to staging, and validate rollback scripts
```

### Example target framework change

```xml
<PropertyGroup>
  <TargetFramework>net8.0</TargetFramework>
  <Nullable>enable</Nullable>
</PropertyGroup>
```

Pair the project change with a plan entry that lists blockers, validation steps, and rollback criteria.

## Output expectations

- A concise phased plan with dependencies and blockers
- Risk register with mitigation owner and validation method
- Clear go/no-go gates between phases
