# PRD: Agent Frontmatter Disambiguation

> **Status:** Approved
> **Issue:** #2926
> **Author:** Copilot
> **Target Version:** Next release
> **Last Updated:** 2026-09-02

## Problem Statement

Seventeen published agent descriptions lack the `USE FOR:` and `DO NOT USE FOR:`
clauses used by the rest of the catalog. Consumers therefore receive ambiguous
routing guidance and fail the BaseCoat Sheen W02 description-overlap audit.

## Goals

- Make every agent named in #2926 pass the W02 routing-description convention.
- Preserve each agent's existing intended responsibility and visibility.
- Ensure descriptions communicate both positive routing and meaningful exclusions.

## Non-Goals

- Changing agent models, tools, visibility, or capabilities.
- Rewriting agent bodies or routing catalogs beyond the affected descriptions.
- Adding new agents.

## Requirements

| ID | Requirement |
|---|---|
| FR-1 | Each affected `description` contains a concise `USE FOR:` clause. |
| FR-2 | Each affected `description` contains a concise `DO NOT USE FOR:` clause. |
| FR-3 | Positive and negative cases reflect the current agent content. |
| NFR-1 | Changes preserve valid YAML frontmatter and Markdown formatting. |

## Acceptance Criteria

- All 17 paths listed in #2926 include both required clauses.
- `pwsh scripts/validate-basecoat.ps1` passes.
- The relevant agent/frontmatter test coverage passes.

## Risks and Mitigations

| Risk | Mitigation |
|---|---|
| A description changes routing intent | Derive clauses from the existing description and agent body. |
| Description bloat exceeds the catalog target | Keep clauses short and limit each to the principal cases. |

## References

- Issue #2926
- `docs/agents/AGENTS.md`
- `.github/instructions/agents-skills-dev.instructions.md`
