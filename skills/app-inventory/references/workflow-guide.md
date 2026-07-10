# App Inventory Workflow Guide

## Workflow

### 1. Trigger a scan

Invoke the `app-inventory` agent and collect its JSON output. Save it alongside the repo
or attach it to the relevant GitHub issue.

### 2. Fill the complexity scoring template

Open `complexity-scoring-template.md` and rate each of the six dimensions. The weighted
total becomes the overall complexity score.

### 3. Populate the inventory report template

Use the structured scan output to fill `inventory-report-template.md`. This document
becomes the canonical record for that application in the ADR log.

### 4. Select a treatment path

Bring the complexity score and strategic-value rating to `docs/treatment-matrix.md` to
select Retire, Rehost, Replatform, Refactor, Rebuild, or Replace.

### 5. Hand off to downstream agents

- **Low complexity / Rehost**: pass to `containerization-planner`
- **Replatform**: pass to `legacy-modernization` + `config-auditor`
- **Refactor / Rebuild**: pass to `solution-architect` + `backend-dev`
- **Dependency upgrades**: pass to `dependency-lifecycle`

## Related Assets

- `docs/app-inventory.md` — conceptual guide and parameter reference
- `docs/treatment-matrix.md` — decision framework for app disposition
- `agents/basecoat-10-core-legacy-modernization.agent.md` — executes the strangler-fig pattern
- `agents/basecoat-10-core-dependency-lifecycle.agent.md` — manages discovered dependency upgrades
- `skills/service-bus-migration/SKILL.md` — messaging migration patterns
- `skills/identity-migration/SKILL.md` — authentication migration patterns
