---
name: dotnet-modernization
compatibility: [github-copilot-cli]
title: .NET Modernization
description: "Structured guidance for assessing and executing modernization from .NET Framework or older .NET targets to modern .NET. USE FOR: inventory a legacy .NET solution, plan phased .NET upgrade, review NuGet and framework compatibility, define modernization test and release gates, remediate breaking changes during migration. DO NOT USE FOR: brand-new .NET app scaffolding, non-.NET platform migrations, day-to-day feature development unrelated to upgrades."

author: IBuySpy-Shared
version: 1.0.0
category: modernization
metadata:
  category: modernization
tags: [dotnet, modernization, migration, upgrade]
allowed-tools: []
---
## .NET Modernization

Use this skill when evaluating, planning, or executing migration from legacy .NET Framework or older .NET targets to modern .NET.

## When to use

- Inventorying a solution before modernization
- Creating phased upgrade plans and risk controls
- Reviewing package/framework compatibility and breaking changes
- Defining test and release gates for modernization waves

## Inputs

- Solution and project files (`*.sln`, `*.csproj`)
- Current runtime and framework versions
- NuGet package graph (direct and transitive)
- CI test coverage and deployment constraints

## Outputs

- Modernization assessment summary
- Phased migration plan with checkpoints
- Dependency remediation recommendations
- Test and rollout strategy

## References

- ./references/breaking-changes.md
