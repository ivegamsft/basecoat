---
description: "Shearing Layers design framework — guides contributors and AI agents to reason about change velocity and coupling between BaseCoat layers."
applyTo: "**/*.{cs,csproj,fs,fsproj,ts,tsx,js,jsx,py,go,java,kt,rb,php,rs,sql,bicep,tf}"
---

# Shearing Layers

BaseCoat assets exist at different layers, each changing at a different pace.
Fast-changing layers must not couple to slow-changing ones. Slow-changing layers
must not assume details of fast-changing ones.

This model is adapted from Stewart Brand's *How Buildings Learn* (1994).

## The Layers

| Layer | Pace | BaseCoat Analog | Examples |
|-------|------|-----------------|----------|
| **Site** | Eternal | Organization identity, repo structure, naming conventions | `basecoat/` repo layout, four-primitive model, `asset-manifest.json` schema |
| **Structure** | Rarely changes | Core asset types, frontmatter schema, validation contract | Agent/skill/instruction/prompt definitions, `validate-basecoat.ps1` rules |
| **Skin** | Seldom changes | Governance vocabulary, guidance syntax, audit rules | `.lexicon.md`, `.impeccable.md`, vocabulary audit scripts |
| **Services** | Periodic changes | MCP server, Copilot Extension, CI/CD pipelines, deployment infra | `mcp/basecoat-metrics/`, GitHub Actions workflows, `infra/` |
| **Space plan** | Occasional changes | Instruction scoping, skill composition, agent-to-skill wiring | `applyTo` patterns, `allowed_skills` in agents, `basecoat-metadata.json` routing |
| **Stuff** | Frequent changes | Individual agent prompts, skill content, prompt templates, eval cases | Any single `.agent.md`, `SKILL.md`, `.eval.yaml`, `.prompt.md` |

## Rules

### Do Not Couple Upward

A fast layer must never depend on implementation details of a slower layer above it.

- An agent prompt (Stuff) must not hard-code a deployment URL (Services).
- A skill template (Stuff) must not assume a specific CI tool (Services).
- An instruction file (Space plan) must not embed the frontmatter schema (Structure).

### Each Layer Is Independently Replaceable

You should be able to:

- Swap the MCP server (Services) without rewriting skills (Stuff).
- Change governance vocabulary (Skin) without restructuring the repo (Site).
- Rewire agent-to-skill mappings (Space plan) without editing the skills themselves (Stuff).

### Change Velocity Guides Review Rigor

| Layer touched | Review expectation |
|---------------|-------------------|
| Site, Structure | Broad consensus required — RFC or design doc |
| Skin | Governance team approval |
| Services | Platform team review + deployment plan |
| Space plan | Standard PR review |
| Stuff | Lightweight review — correctness + eval pass |

## Applying the Model

When reviewing a PR or designing a new asset, ask:

1. **Which layer does this change touch?** — Classify before you code.
2. **Does it introduce cross-layer coupling?** — A red flag if Stuff references Services.
3. **Is the review rigor appropriate?** — Structure changes in a one-line PR need escalation.
4. **Could this be pushed to a faster layer?** — Prefer Stuff over Space plan; prefer Space plan over Skin. Put decisions at the fastest layer that can own them.

## Anti-Patterns

| Anti-pattern | Why it's wrong | Fix |
|--------------|---------------|-----|
| Agent prompt embeds API endpoint | Stuff coupled to Services | Use environment variable or instruction-provided config |
| Validation script checks specific skill names | Structure coupled to Stuff | Validate structure/schema, not content |
| Instruction file lists every agent by name | Space plan coupled to Stuff | Use glob patterns or metadata queries |
| CI workflow hard-codes governance rules | Services coupled to Skin | CI reads rules from `.lexicon.md` dynamically |
