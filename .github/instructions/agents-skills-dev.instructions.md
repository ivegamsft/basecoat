---
description: "Agent and skill development conventions, frontmatter requirements, visibility tagging, and evaluation coverage"
applyTo: "agents/**/*,skills/**/*"
---

# Agent & Skill Development

## Agent Frontmatter

All agents require:

```yaml
name: string (required)
description: string (required) — Include USE FOR: [3-5 cases] and DO NOT USE FOR: [3 anti-patterns]
visibility: basic|specialized|advanced|internal (required)
model: string (optional, defaults to claude-sonnet-4.5)
allowed_skills: [list] (optional)
```

### Visibility Tags

- `visibility: basic` — Everyday workflows (issue-triage, sprint-planner, code-review)
- `visibility: specialized` — Direct-target jobs (build-triage, branch-hygiene, ci-audit)
- `visibility: advanced` — Complex orchestration (escalation-router, orchestrator)
- `visibility: internal` — MCP/infrastructure only (mcp-developer, agentops)

## Skill Frontmatter

All skills require:

```yaml
description: string (required) — USE FOR: [trigger cases]
visibility: public|private (optional, defaults to public)
```

## Evaluation Coverage

All agents must have a companion `<agent>.agent.eval.yaml` file.
All skills must have a companion `eval.yaml` in the skill directory.

Run `pwsh tests/run-tests.ps1` to validate coverage.
