---
name: dependency-blocker-monitoring
description: "Use when monitoring workcell BOM dependencies and cell health so blocker issues are opened when a cell fails and resolved when it recovers. USE FOR: dependency maps, cell health checks, blocker issue creation, and recovery closures. DO NOT USE FOR: general project tracking or unrelated CI triage."
compatibility:
  editors:
    - vscode
  platforms:
    - github
metadata:
  category: "Process"
  tags: ["workcell", "bom", "dependencies", "cell-health", "blocker", "recovery"]
  maturity: "beta"
  audience: ["developers", "project-managers", "tech-leads"]
allowed-tools: ["bash", "git", "gh", "azure-cli"]
visibility: "internal"
---
# Dependency Blocker Monitoring Skill

Use this skill to keep Workcell dependency blockers synchronized with cell health.

## Workflow

1. Read the workcell BOM and validate the dependency shape.
2. Build a cell-to-workcell impact map from the declared dependencies.
3. Check the current cell health signal for each dependency cell.
4. Create blocker issues when a cell fails.
5. Resolve the matching blocker issue when the cell recovers.

## Issue Lifecycle

Use one open blocker issue per failed cell.

```bash
gh issue list --state open --label blocker --search "<cell-name>"
```

If no blocker exists for the failed cell, create one with the failure evidence and impacted workcells. If a blocker already exists, update the existing issue instead of creating a duplicate.

On recovery, add a short closure comment, then close the issue after the health check is green.

## Guardrails

- Do not invent dependencies that are not in the BOM.
- Do not close blockers without a verified recovery signal.
- Keep the issue body short and link to the authoritative evidence.
- Reuse existing BOM and factory state artifacts when they are present.

## Output

- Dependency impact map
- Open or closed blocker issues
- Short recovery summary
