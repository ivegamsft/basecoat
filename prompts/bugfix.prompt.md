---
description: "Use when investigating a bug, regression, or production failure. Focuses on root-cause analysis, a minimal safe fix, and validation."
model: claude-sonnet-5
tools: ["changes", "codebase", "terminal", "githubRepo"]
---

# Fix A Bug

Use this prompt when you want the work to focus on finding and fixing the root cause rather than masking symptoms.

## Prompt

Review the bug report, failing behavior, or error symptoms, then:

1. State the likely root cause and what evidence supports it
2. Identify the smallest safe fix
3. Note any missing diagnostics or tests
4. Implement the fix with minimal unrelated changes
5. Validate the result and state any residual risk
