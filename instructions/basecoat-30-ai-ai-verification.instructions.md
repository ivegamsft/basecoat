---
description: "Use when reviewing or accepting AI-generated code. Provides a risk-tiered verification protocol to reduce trust overhead while catching real issues."
applyTo: "**/*"
---

# AI Output Verification Protocol

Use this instruction when reviewing AI-generated code, suggestions, or refactoring proposals. The goal is efficient verification — proportional effort to proportional risk.

## Risk-Tiered Review

Classify every AI-generated change by risk tier and apply corresponding verification:

| Tier | Category | Examples | Required Verification |
|------|----------|----------|----------------------|
| 1 | **Cosmetic** | Formatting, comments, naming | Compile + quick visual check |
| 2 | **Logic** | New functions, control flow, data transforms | Compile + tests + line-by-line review |
| 3 | **Security** | Auth, crypto, input validation, secrets | Full review + security checklist + tests |
| 4 | **Architecture** | Interface changes, data model changes, dependency changes | Full review + team discussion + integration tests |

When in doubt, escalate to the next tier.

## Automated Verification Gates

Run these on ALL AI-generated changes before human review:

1. **Compile/build** — catches invented APIs, type errors, syntax issues.
2. **Lint** — catches style violations and common anti-patterns.
3. **Existing tests** — catches regressions in behavior the tests cover.
4. **Static analysis / sanitizers** — catches memory errors, null issues, type confusion (when available).

If any gate fails, fix before proceeding to human review. AI-generated code that does not compile is never acceptable.

## Diff-Audit Discipline

When reviewing AI-generated diffs line by line:

- **Read deletions first**: what was removed? Was it load-bearing?
- **Check boundary conditions**: loops, array access, string operations — off-by-one is the most common AI error.
- **Verify error paths**: does the AI handle failures, or only the happy path?
- **Trace data flow**: where does input come from? Is it validated before use?
- **Check naming**: did the AI invent a function, method, or import that does not exist in the codebase?

## Confidence Signals

Indicators that AI output is likely correct:

- ✅ Consistent across multiple re-prompts (same approach each time).
- ✅ Matches existing patterns in the codebase.
- ✅ Passes all existing tests without modification.
- ✅ References real APIs, functions, and types that exist.
- ✅ Handles error cases explicitly.

Red flags that require deeper review:

- ⚠️ Uses APIs or functions you cannot find in documentation or the codebase.
- ⚠️ Dramatically different approach on re-prompt.
- ⚠️ Ignores or removes existing error handling.
- ⚠️ Introduces new dependencies not discussed.
- ⚠️ Modifies code far from the stated change scope.

## Incremental Acceptance

- Accept AI output in small, independently verifiable chunks.
- Do not accept a 500-line AI-generated change as one unit. Break it into logical commits.
- Each chunk must pass automated gates independently.
- If a chunk introduces a test, verify the test actually fails without the corresponding implementation.

## Known AI Failure Patterns

Common mistakes to specifically check for:

| Pattern | What to look for |
|---------|-----------------|
| Hallucinated APIs | Function calls to methods that don't exist in the library version you use |
| Off-by-one errors | Loop bounds, array indices, string slicing |
| Missing null/error checks | Optimistic paths without failure handling |
| Incorrect async/await | Missing awaits, unhandled promise rejections, race conditions |
| Wrong method signatures | Correct function name but wrong parameters or return type |
| Stale patterns | Using deprecated APIs or patterns from older framework versions |
| Incomplete refactoring | Renamed in some places but not all, leaving inconsistencies |
| Test theater | Tests that pass but don't actually verify the behavior they claim to |

## Review Efficiency

- Spend 80% of review time on Tier 3-4 changes, 20% on Tier 1-2.
- If a change passes all automated gates and is Tier 1-2, a quick scan is sufficient.
- For Tier 3-4, schedule focused review time — do not review security-critical AI output while multitasking.
- Keep a team log of AI mistakes caught in review. Patterns inform future verification focus.
