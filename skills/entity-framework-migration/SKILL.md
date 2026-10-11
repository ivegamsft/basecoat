---
name: entity-framework-migration
compatibility: [github-copilot-cli]
title: Entity Framework Migration
description: "Use when modernizing legacy Entity Framework data layers to EF Core with help for model mapping, DbContext refactors, phased cutovers, and migration risk review. USE FOR: migrate EF6 to EF Core, refactor DbContext configuration, convert model mappings and conventions, plan phased database cutover, validate query compatibility after migration. DO NOT USE FOR: greenfield ORM selection, raw SQL tuning only, non-.NET data pipelines."

author: BaseCoat contributors
version: 1.0.0
category: data
metadata:
  category: data
  maturity: stable
  audience:
    - developer
tags: [dotnet, entity-framework, ef-core, migration]
allowed-tools: []
---
## Entity Framework Migration

Use this skill when modernizing data layers from Entity Framework 6 or older patterns to EF Core.

## When to use

- Assessing EF6-to-EF Core migration feasibility
- Refactoring data access patterns and DbContext configuration
- Migrating model mappings and conventions
- Planning phased cutovers for schema and query behavior changes

## Inputs

- Existing data access projects and context classes
- Current migration history and database schema constraints
- Query hot paths and performance baselines

## Outputs

- EF migration approach and risk summary
- Mapping and query refactor checklist
- Validation strategy for correctness and performance
