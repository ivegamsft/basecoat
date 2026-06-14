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
