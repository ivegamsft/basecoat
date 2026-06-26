---
name: frontend-audit
compatibility: [github-copilot-cli]
description: "Use when reviewing frontend implementations, component output, responsive behavior, accessibility states, or UI consistency. USE FOR: audit generated UI, review a PR for WCAG or responsive issues, verify interaction states and copy consistency, check performance-sensitive patterns. DO NOT USE FOR: building UI features from scratch, backend API design, database schema modeling."
category: operations
---
# Frontend Audit Skill

Review frontend output for accessibility, responsiveness, interaction feedback, and component correctness.

## USE FOR

- Auditing generated or hand-built frontend code
- Reviewing UI PRs for WCAG, semantics, and keyboard support
- Checking responsive behavior, empty/loading/error states, and copy consistency
- Verifying component boundaries and state transitions

## DO NOT USE FOR

- Designing a new feature from scratch
- Backend API or contract design
- Database schema or migration work
- Pure styling changes that do not affect behavior or accessibility

## Workflow

1. Inspect semantics, accessibility, and keyboard paths.
2. Check layout at mobile, tablet, and desktop breakpoints.
3. Review interaction states: hover, focus, active, disabled, loading, empty, and error.
4. Verify performance-sensitive patterns such as bundle size, redundant renders, and unnecessary client state.
5. Summarize findings with severity, evidence, and fix guidance.

## Output

Return:

- Summary verdict: pass, pass with notes, or request changes
- Findings with severity, file reference, and evidence
- Suggested fix for each finding
- Follow-up questions if scope is unclear

## Related Agent

Use with `frontend-dev` agent.
