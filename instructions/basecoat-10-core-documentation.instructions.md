---
description: "Use when a change affects setup, workflows, public contracts, operational behavior, or developer experience. Covers common documentation best practices."
applyTo: "**/*"
---

# Documentation Standards

Use this instruction when a code or configuration change affects how people build, run, operate, or integrate with the system.

## Expectations

- Update README or nearby docs when setup, commands, configuration, or workflows change.
- Document breaking changes, migrations, and rollout considerations explicitly.
- Keep examples aligned with the current code and commands.
- Prefer concise operational notes over long prose that goes stale quickly.
- Write docs for the next maintainer, not only for the original author.
- Use standard heading scaffolds so docs are consistent across repositories.
- Use PRD and technical spec templates for non-trivial product or architecture changes.

## Review Lens

- Would another engineer know how to run or verify this after the change?
- Were new environment variables, flags, or dependencies documented?
- If the change alters behavior, are the user-facing consequences explained?
- Is the documentation close enough to the code that it is likely to be maintained?

## Heading Scaffolding

Use the shared templates in `docs/documentation-heading-scaffolds.md` as a baseline.

- README scaffold for project onboarding and daily use
- Runbook scaffold for operations and incident handling
- ADR scaffold for architectural decisions
- Change note scaffold for rollout and migration communication

## PRD And Spec Guidance

Use `docs/prd-and-spec-guidance.md` when defining scope, requirements, and implementation detail for medium-to-large changes.

- PRD: business goal, user needs, success metrics, constraints, non-goals
- Technical spec: architecture, data flow, interfaces, rollout, risk, validation plan
- Keep PRD and spec linked so delivery remains aligned with original intent

## File Placement

Follow the canonical placement rules in `docs/guides/file-placement.md`. Key rules:

- **Repo root**: only standard project files (README, CHANGELOG, LICENSE, sync scripts, config dotfiles). No specs, no summaries, no API files.
- **docs/guides/**: how-to guides and tutorials
- **docs/reference/**: stable reference material; API specs go in `docs/reference/api/`
- **docs/operations/**: runbooks, release docs, ops tracking
- **docs/archive/**: retired content and sprint artifacts — do not add new content without tagging it for archival
- **agents/**: flat `.agent.md` files only — no subdirectories, no meta-docs
- **instructions/**: flat `.instructions.md` files; reference shards in `instructions/references/<topic>/`
- **prompts/**: flat `.prompt.md` files
- **Never** place source code (`.py`, `.ts`, `.sql`) inside `docs/`
- **Never** commit AI-generated summary `.txt` files — see `.gitignore` patterns
