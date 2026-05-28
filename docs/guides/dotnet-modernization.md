# .NET Modernization Framework

This document defines the Base Coat approach for modernizing .NET workloads.

## Scope

- Legacy .NET Framework to modern .NET runtime migration
- Dependency compatibility and upgrade sequencing
- Test and release governance for phased modernization

## Modernization lifecycle

## 1. Assess

- Inventory projects, frameworks, and package dependencies
- Identify unsupported runtimes and high-risk coupling
- Capture architecture and operational constraints

## 2. Plan

- Choose migration strategy (in-place, incremental, strangler)
- Sequence work by dependency boundaries and risk
- Define build/test/release gates and rollback criteria

## 3. Execute

- Migrate in controlled waves
- Validate each wave with CI and runtime checks
- Capture learnings and update runbooks

## Base Coat assets

- Agent: `agents/dotnet-modernization-advisor.agent.md`
- Skills:
  - `skills/dotnet-modernization/SKILL.md`
  - `skills/entity-framework-migration/SKILL.md`
- Instructions:
  - `instructions/dotnet-upgrade-planning.instructions.md`
  - `instructions/dotnet-dependency-analysis.instructions.md`
  - `instructions/dotnet-test-strategy.instructions.md`
