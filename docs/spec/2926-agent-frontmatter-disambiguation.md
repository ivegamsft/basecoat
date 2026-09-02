# Technical Specification: Agent Frontmatter Disambiguation

## Context

BaseCoat agent frontmatter descriptions are consumed by routing tools and the
BaseCoat Sheen W02 audit. The audit expects explicit positive and negative
routing cases.

## Scope

Update only the `description` frontmatter values for the 17 agents listed in
#2926. Append `USE FOR:` and `DO NOT USE FOR:` clauses that match their existing
responsibilities.

## Out of Scope

Agent body, model, tools, visibility, metadata, and compatibility changes.

## Implementation Plan

1. Read the existing frontmatter and agent guidance for every affected path.
2. Add concise positive and negative routing clauses without changing the
   existing role statement.
3. Run structural and targeted frontmatter validation.

## Testing Strategy

- Run `pwsh scripts/validate-basecoat.ps1`.
- Run the existing agent/skill audit coverage that validates agent frontmatter.
- Assert every affected description has both required phrases.

## Rollback

Revert the description-only commit. No runtime state or external dependency is
changed.

## References

- PRD: `docs/prd/2926-agent-frontmatter-disambiguation.md`
- Issue #2926
