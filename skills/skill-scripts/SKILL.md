---
name: skill-scripts
compatibility: [github-copilot-cli]
description: "Use when a skill needs executable multi-step workflows where each script produces structured JSON that is passed to the next step, enabling composable assessment, planning, validation, and execution with clear contracts. USE FOR: splitting large skills into deterministic script stages, chaining assessment and planning outputs, defining executable skill contracts, and building reusable automation pipelines inside a skill. DO NOT USE FOR: single-step prompt-only skills, ad hoc shell snippets without contracts, or replacing repo-wide workflow orchestration."
category: development
metadata:
  category: development
  maturity: stable
  audience:
    - developer
allowed-tools: []
---
# Skill Scripts

Use this pattern to split a skill into executable steps instead of one large prompt.

## Frontmatter Contract

Define script steps in `SKILL.md`:

```yaml
scripts:
  - name: assess
    entrypoint: scripts/assess.ps1
    inputs: []
  - name: plan
    entrypoint: scripts/plan.ps1
    inputs:
      - name: assessment
```

## Execution

Run the orchestrator:

```powershell
./scripts/orchestrate-skill-scripts.ps1 `
  -SkillPath skills/container-build-assessment/SKILL.md
```

Run one step:

```powershell
./scripts/orchestrate-skill-scripts.ps1 `
  -SkillPath skills/container-build-assessment/SKILL.md `
  -Step assess
```

## Guidance

1. Keep each step focused and independently testable.
2. Prefer JSON output for all steps.
3. Treat previous-step output as input contract, not free-form text.
4. Keep entrypoints inside the skill directory.
