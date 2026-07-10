---
name: agent-design
compatibility: [github-copilot-cli]
description: "Use when designing Copilot agents, skills, or instruction assets for a shared customization repo. USE FOR: design a new Copilot agent, scaffold a skill folder, create an instruction file, choose agent vs skill vs instruction, author agent frontmatter and conventions. DO NOT USE FOR: implementing product features, troubleshooting runtime incidents, deploying infrastructure."
category: agent-development

metadata:
  category: agent-development
  domain: agent-development
  maturity: production
  audience:
    - developer
    - maintainer
allowed-tools:
  - bash
  - git
visibility: public
---
# Agent Design Skill

Design, scaffold, or author Copilot agent definitions, skill folders, and instruction files for a shared customization repository.

## Template Index

| Template | Purpose | Path |
|---|---|---|
| Agent definition | Scaffold a new `.agent.md` with frontmatter and standard sections | `agent-template.md` |
| Skill folder | Scaffold a new skill with `SKILL.md` and supporting structure | `skill-template.md` |
| Instruction file | Scaffold a reusable instruction file | `instruction-template.md` |

## Conventions & Guardrails

- Agent filenames: `<kebab-case-name>.agent.md`; skill folders: `skills/<name>/SKILL.md`; instruction files: `instructions/<name>.instructions.md`
- All files use YAML frontmatter fenced by `---`; descriptions include trigger phrases for discovery
- Do not create an agent when a skill or instruction would suffice; check inventory for duplicates
- Keep each primitive scoped to a single responsibility; validate frontmatter with a YAML linter

## Agent Pairing

Use with `agent-designer` agent (primary consumer). `prompt-engineer` agent optimizes instruction text.
