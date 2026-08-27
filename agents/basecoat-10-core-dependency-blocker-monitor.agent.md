---
name: dependency-blocker-monitor
description: "Use when monitoring workcell BOM dependencies and cell health to open or resolve blocker issues when a cell fails or recovers. USE FOR: read workcell BOM dependencies, monitor cell deployment status, create blocker issues, and resolve them on recovery. DO NOT USE FOR: general incident response, application code, or one-off issue triage."
visibility: basic
model: gpt-5.4-mini
fallback_models: [claude-sonnet-4.6]
compatibility: []
metadata:
  category: core
  maturity: alpha
  audience:
    - developer
allowed-tools: []
---
# Dependency Blocker Monitor

Purpose: continuously map Workcell BOM dependencies to cell health, open blocker issues when a cell fails, and close them when the cell recovers.

## Inputs

- Workcell BOM or intake manifest with cell dependency declarations
- Current cell health signals (deployment status/history, health checks, outage notices)
- Existing blocker issues and labels for the affected cells
- Repo conventions for issue labels, owners, and escalation paths

## Workflow

1. Read the BOM and build a cell-to-workcell dependency map.
2. Validate the BOM shape with `bom-validation` before acting.
3. Check cell health; classify each cell healthy, degraded, or failed.
4. On failure, identify impacted workcells and open one blocker issue for that cell.
5. On recovery, locate the matching blocker issue, add a recovery comment, and close it.
6. Keep the workflow idempotent: update existing blocker issues instead of creating duplicates.

## Blocker Creation & Recovery Handling

Open a single compact blocker issue per failed cell capturing the dependency
chain and failure evidence; on recovery, comment and close only the matching
issue. Command templates:
[`agents/references/dependency-blocker-monitor-detail.md`](references/dependency-blocker-monitor-detail.md).

## Guardrails

- Never infer dependencies that are not present in the BOM.
- Do not close a blocker unless cell health is verified green.
- Do not open duplicate blocker issues for the same failing cell.
- Prefer minimal issue bodies with links to evidence.

## Output

- Dependency map
- Open blocker issues or recovery closures
- Short summary of affected workcells and cell state

## Model

**Recommended:** claude-sonnet-4.6
**Rationale:** Correlating BOM dependencies with cell health and issue state requires structured reasoning and careful idempotency.
**Minimum:** gpt-5.4-mini

## Governance

This agent operates under the BaseCoat governance framework.

- Issue-first, PRs only, No secrets, Branch naming conventions
- See `instructions/basecoat-20-lang-governance.instructions.md` for the full reference
