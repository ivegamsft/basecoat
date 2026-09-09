---
description: "Use when you want an implementation plan before editing code. Helps break down a feature or system change into options, tradeoffs, and execution steps."
model: claude-sonnet-5
tools: ["changes", "codebase", "githubRepo"]
---

# Architect A Change

Use this prompt when you want an implementation plan before editing code.

## Prompt

Review the request and the current codebase, then produce:

1. A brief problem statement
2. The main constraints and assumptions
3. Two or three implementation options with tradeoffs
4. A recommended approach
5. A concrete execution plan with validation steps
