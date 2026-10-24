---
description: "BaseCoat repository structure, file organization, and naming conventions"
applyTo: "agents/**/*,skills/**/*,instructions/**/*,prompts/**/*,docs/**/*"
---

# BaseCoat Repository Structure

BaseCoat is an enterprise shared library of GitHub Copilot customization assets
including agents, skills, instruction files, prompt templates, and documentation.

## Directory Organization

- **Agents**: Flat files at `agents/<name>.agent.md` with YAML frontmatter (name, description)
- **Instructions**: Files at `instructions/<name>.instructions.md` with frontmatter (description, applyTo)
- **Skills**: Directories at `skills/<name>/` containing SKILL.md with frontmatter
- **Prompts**: Files at `prompts/<name>.prompt.md` with YAML frontmatter
- **Docs**: Markdown files in `docs/` — no frontmatter required

## Markdown Standards

- Use `##` headings, never bold-as-heading (MD036)
- Blank lines before/after code fences (MD031)
- Files end with single newline (MD047)
- No trailing spaces, consistent list markers
- No emojis in any content (code, docs, UI, commit messages)

## Provider and Implementation Scope

BaseCoat guidance is provider-neutral by default. Any guidance tied to a specific
cloud provider (AWS, Azure, GCP), IaC tool (Terraform, Bicep), or a concrete
deployment must say so explicitly:

- Name the provider, tool, or implementation in the title, or open the doc with a
  `> **Scope:**` line stating what it applies to and when to use it.
- In a provider-neutral doc, put provider-specific steps in a labeled section or
  example (for example `### Example: Azure`), never as the only path.
- Docs for one deployment of this repository (for example the legacy Portal under
  `infra/aws/`) must state that they are not generic BaseCoat guidance.
- Generic docs must not link to implementation-specific docs as their template.
