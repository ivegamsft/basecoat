---
description: "Use when you want a risk-focused code review of a diff, branch, or set of files. Returns findings first, then open questions, then a short summary."
model: claude-sonnet-5
tools: ["changes", "codebase", "githubRepo"]
---

# Review A Change

Use this prompt when you want a risk-focused code review.

## Prompt

Review the changed code with a review mindset. Prioritize:

1. Bugs and regressions
2. Risky edge cases
3. Missing tests
4. Security or data integrity issues

Return findings first with clear file references, then open questions, then a short summary.
