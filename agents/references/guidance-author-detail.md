# Guidance Author — Detail Reference

## Frontmatter by Asset Type

- Instructions: `description`, `applyTo`
- Skills: `name`, `description`, `compatibility` (required — see canonical field list in
  `.github/instructions/agents-skills-dev.instructions.md`)
- Agents: `name`, `description`, `visibility` (required — see canonical field list, including
  optional `metadata`, `allowed-tools`, `model`/`model_policy`, `allowed_skills`, in the same file)
- Prompts: `name`, `description`, `mode`

For the full, current required/optional field set per asset type, always defer to
`.github/instructions/agents-skills-dev.instructions.md` rather than this summary.

## Body Section Requirements

- All agents require `## Inputs`, `## Workflow` (or `## Process`), and one output section
  (`## Output`, `## Expected Output`, `## Report`, or `## Results`)
- Skills require a readable description body explaining triggers, inputs, and outputs
- Instructions should use `##` sections and fenced code blocks for examples

## Scope and Quality Checklist

- Is the content broadly applicable, not project-specific?
- Is it durable — still true in 3+ sprints?
- Is each behavior actionable (what to do, not just what to avoid)?
- Are examples realistic and non-trivial?

## Style Conventions

`##` headings (never bold-as-heading), blank lines around code fences, single
trailing newline, no trailing spaces.
