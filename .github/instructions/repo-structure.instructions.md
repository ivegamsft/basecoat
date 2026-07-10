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
