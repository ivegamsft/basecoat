---
name: documentation
compatibility: [github-copilot-cli]
description: "Use when writing or improving technical documentation such as READMEs, ADRs, runbooks, and reference guides. USE FOR: write a project README, record an architecture decision, create an operational runbook, review docs for accuracy and gaps, establish docs-as-code standards. DO NOT USE FOR: implementing application features, generating code-only refactors, designing infrastructure topology diagrams from scratch."
---
# Documentation Skill

Use this skill when the task involves creating, updating, or reviewing technical documentation of any kind.

## When to Use

- Creating a new README or project overview
- Recording an architecture decision (ADR)
- Writing an operational runbook
- Reviewing existing docs for accuracy and completeness
- Establishing documentation standards for a project
- Writing API reference documentation

## How to Invoke

Reference this skill by attaching `skills/documentation/SKILL.md` to your agent context, or instruct the agent:

> Use the documentation skill. Apply the ADR template to document our decision to adopt PostgreSQL.

## Templates in This Skill

| Template | Purpose |
|---|---|
| `readme-template.md` | Project README structure — overview, setup, usage, and contributing |
| `adr-template.md` | Architecture Decision Record — context, decision, and consequences |
| `runbook-template.md` | Operational runbook — trigger, steps, rollback, and escalation |

## Agent Pairing

This skill is designed to be used alongside the following agents:

- **tech-writer** — Drives documentation creation using these templates
- **solution-architect** — Provides architectural context for ADRs
- **devops-engineer** — Provides operational context for runbooks
- **product-manager** — Provides feature context for user-facing documentation

For code-level documentation (inline comments, docstrings), coordinate with the `backend-dev` or `frontend-dev` agents.


