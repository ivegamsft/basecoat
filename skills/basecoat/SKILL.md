---
name: basecoat
description: "Use when you need to discover the right BaseCoat agent or route a request to the correct discipline. USE FOR: find the right BaseCoat agent, browse the BaseCoat agent catalog, route a prompt to backend-dev, discover which agent handles code review, delegate a task to the right discipline. DO NOT USE FOR: implementing the task directly, editing skill internals, general package installation guidance."
compatibility: GHCP
---

# BaseCoat Router

The front door to the BaseCoat framework. Routes requests to the right agent across
6 disciplines in two modes: **Discovery** (browse agents) and **Delegation** (route directly).

## Quick Start

```text
/basecoat                        → Full agent catalog by category
/basecoat find "deploy"          → Search agents by keyword
/basecoat backend build a REST API for orders  → Delegate to @backend-dev
```

## Reference Files

| File | Contents |
|------|----------|
| [`references/authoring.md`](references/authoring.md) | Discovery mode, delegation mode, examples |
| [`references/governance.md`](references/governance.md) | Full keyword-to-agent routing table, metadata registry, governance rules |

## Categories

| Category | Agents |
|----------|--------|
| 🔨 Development | `@backend-dev`, `@frontend-dev`, `@middleware-dev`, `@data-tier` |
| 🏗️ Architecture | `@solution-architect`, `@api-designer`, `@ux-designer` |
| 🔍 Quality | `@code-review`, `@security-analyst`, `@performance-analyst`, `@config-auditor` |
| 🚀 DevOps | `@devops-engineer`, `@release-manager`, `@rollout-basecoat` |
| 📋 Process | `@sprint-planner`, `@product-manager`, `@issue-triage`, `@retro-facilitator` |
| 🧰 Meta | `@agent-designer`, `@prompt-engineer`, `@mcp-developer`, `@tech-writer` |
