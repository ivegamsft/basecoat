# Agent Merge Concept

## Purpose

Agent merge automation provides a single validation flow before changes to agent
assets are merged.

## Scope

The automation targets five controls:

1. Duplicate agent-name prevention
2. Conflicting tool-permission detection for duplicated agent names
3. Frontmatter-diff changelog generation
4. Eval companion validation before merge
5. Rollback patch generation for a selected merge commit

## Workflow Contract

Implementation lives in:

- `.github/workflows/agent-merge.yml`

That workflow enforces controls during pull requests that modify agent or skill
assets and supports manual rollback planning through `workflow_dispatch`.

## Changelog Output Contract

`agent-merge.yml` now generates structured frontmatter deltas for changed
`agents/*.agent.md` and `skills/*/SKILL.md` files:

- Added keys
- Removed keys
- Changed keys
- Tool-permission specific changes (`tools`, `allowed-tools`, `allowed_skills`)

Artifacts published under `agent-merge-changelog`:

- `agent-merge-changelog.md` (human-readable detailed diff)
- `agent-merge-changelog.json` (deterministic machine-readable delta data)
- `agent-merge-changelog-summary.md` (compact summary for PR comment)

The workflow also posts (or updates) a PR comment with the compact summary.
