# Agent Merge Concept

Agent merge is a structured pattern for combining multiple source components into a single merged agent while keeping safety checks and rollback metadata explicit.

## Why this exists

The merge flow exists to reduce manual copy-and-paste composition errors and make merged agents auditable. It enforces:

1. Duplicate-name prevention before merge.
2. Tool-permission conflict detection across source agents.
3. Auto-generated frontmatter changelog for PR traceability.
4. Skill `eval.yaml` gate enforcement before merge.
5. Rollback support that restores source components.

## Required merged-agent frontmatter

A merged agent is any `agents/*.agent.md` file that includes `merged_from` in frontmatter.

```yaml
---
name: merged-agent-name
description: ...
merged_from:
  - agents/source-a.agent.md
  - agents/source-b.agent.md
  - skills/shared-skill/SKILL.md
---
```

### Optional permission metadata for conflict checks

If source agents define permission intent, include it in frontmatter.

```yaml
tool_permissions:
  allow:
    - web-search
    - azure-monitor
  deny:
    - azure-role
```

The merge gate fails when one source allows a tool that another source denies.

## Workflow behavior

The `.github/workflows/agent-merge.yml` workflow provides two modes:

1. **Validation mode** (`pull_request` or manual dispatch): runs duplicate-name, permission-conflict, changelog, and eval checks.
2. **Rollback mode** (`workflow_dispatch`): removes a merged agent and restores source components from git history on a rollback PR branch.

## Rollback usage

Run workflow dispatch for `agent-merge.yml` with:

- `mode=rollback`
- `merged_agent_path=agents/<merged-file>.agent.md`
- `source_agent_paths` (optional if `merged_from` still exists in merged file)

Rollback opens a PR instead of pushing directly to `main`.
