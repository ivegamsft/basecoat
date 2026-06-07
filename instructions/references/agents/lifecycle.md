# Agent Testing, Versioning & Example Skeleton

## Validation Checklist (Before Merging)

1. **Frontmatter valid** — YAML parses without errors. `name` matches filename. `description` is a single sentence. `tools` is a valid array.
2. **All required sections present** — Title, Purpose, Inputs, Workflow, Domain sections, GitHub Issue Filing, Model, Output Format.
3. **Skill references resolve** — every path referenced exists on disk; every name in `allowed_skills` has a directory under `skills/`.
4. **Issue filing template works** — copy the `gh issue create` block, substitute sample values, confirm valid command.
5. **Workflow is executable** — each numbered step is actionable and unambiguous.
6. **Model section complete** — Recommended model, minimum model, and rationale all present.
7. **No orphaned agents** — if the agent replaces another, the old file is removed and references updated.
8. **Dry-run the agent** — execute against representative input and confirm output matches Output Format.
9. **Skill isolation check** — if `allowed_skills: []`, confirm the workflow invokes no skills.

## Versioning & Deprecation

- Agent files are versioned through Git history — no in-file version number.
- **Breaking changes** require a changelog entry and notice in the PR description.
- **Deprecating**: add `> [!WARNING] This agent is deprecated. Use <replacement-agent> instead.` below the frontmatter; keep for two sprints, then delete.
- **Renaming**: create new file, deprecate old file, update all cross-references in the same PR.
- When deleting an agent, also delete its paired skill directory if no other agent references those skills.

## Minimal Agent Skeleton

```markdown
---
name: example-agent
description: "Example agent. Use when creating a new agent from scratch."
tools: [read_file, write_file, list_dir, run_terminal_command, create_github_issue]
allowed_skills: [example-skill]
---

# Example Agent

Purpose: demonstrate the required structure.

## Inputs

- Feature description or user story
- Relevant existing files or documentation

## Workflow

1. **Gather context** — read inputs and identify scope.
2. **Execute the task** — perform domain-specific work.
3. **Validate output** — confirm result meets acceptance criteria.
4. **File issues** — create GitHub Issues for discovered problems.

## Domain Standards

- Domain-specific rules, checklists, or reference tables go here.

## GitHub Issue Filing

| Finding | Labels |
|---|---|
| Discovered defect or debt | `tech-debt,example` |

## Model

**Recommended:** gpt-5.3-codex
**Minimum:** gpt-5.4-mini
**Rationale:** Code-optimized model suitable for implementation tasks.

## Output Format

- Deliver code or artifacts with inline comments.
- Reference filed issue numbers in output.

## Allowed Skills

*(none)*
```

Refer to `agents/basecoat-10-core-backend-dev.agent.md` and `agents/basecoat-50-security-security-analyst.agent.md` for fully fleshed-out examples.
