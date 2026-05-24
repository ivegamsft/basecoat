# Contributing to BaseCoat

BaseCoat grows through contributions from teams who discover patterns worth sharing.

## What to contribute

Good contributions are patterns that:

- Solve a problem that applies to **multiple teams**, not one project
- Are **actionable** — Copilot can follow them without ambiguity
- Contain **no org-specific details** — product names, internal URLs, team names
- Have been **validated** in at least one real session

## Contribution types

| Type | Where | Template |
|---|---|---|
| Agent | `agents/<name>.agent.md` | See existing agent for format |
| Skill | `skills/<name>/SKILL.md` | See existing skill for format |
| Instruction | `instructions/<name>.instructions.md` | frontmatter + rules |
| Memory | Via `submit-learning-callable.yml` workflow | JSON payload |

## Naming collisions across asset types

Skill names and instruction names can intentionally overlap. Current shared names
include `architecture`, `documentation`, `observability`, `security`, and `ux`.

This is a known pattern, not an error. Routing behavior is determined by asset
type and source path:

- `instruction@instructions/` for instructions
- `skill@skills/` for skills

When reviewing context output, use the **Source (type@path)** column to
disambiguate similarly named assets.

## Required file structure

### Agent (`agents/<name>.agent.md`)

```yaml
---
name: agent-name
description: One-sentence description.
---
```

Required sections: `## Inputs`, `## Workflow`, `## Output`

### Skill (`skills/<name>/SKILL.md`)

```yaml
---
name: skill-name
description: One-sentence description.
---
```

Required sections: `## Triggers`, `## Inputs`, `## Workflow`, `## Output`, `## Examples`

### Instruction (`instructions/<name>.instructions.md`)

```yaml
---
description: What this instruction enforces.
applyTo: path/pattern/**
---
```

## Submitting

1. Fork or branch from `main`
2. Add your asset following the structure above
3. Run validation: `pwsh scripts/validate-basecoat.ps1`
4. Run tests: `pwsh tests/run-tests.ps1`
5. Open a PR — the Squad agent will triage it

## Memory contributions

Short-lived patterns (session fixes, workarounds) go through the memory contribution workflow rather than direct PRs. Use the `memory-promoter` agent to identify candidates, then call `submit-learning-callable.yml`.
