---
description: "Use when planning, implementing, or reviewing changes. Requires explicit success criteria before coding and completed verification with evidence before declaring work done."
applyTo: "**/*"
---

# Verification-Driven Development

Use this instruction for every implementation task, bug fix, refactor, and content update.

## Expectations

- Before implementing, define at least one verification criterion: a test case, expected output, acceptance check, or manual inspection rule.
- Include expected outputs in prompts when requesting implementation. This is the highest-leverage way to improve quality.
- Choose verification that matches the change: unit tests, integration tests, lint, build success, manual inspection criteria, or output comparison.
- After implementing, run the planned verification before marking the work complete.
- Never declare a task done without evidence that the change works: test output, build or lint success, or an explicit manual verification step.
- Fail fast. If verification fails, fix the issue immediately instead of moving on to the next task.

## Verification Planning

Before making changes, state:

1. What will be checked.
2. How it will be checked.
3. What result is expected.

Examples:

- "Run the relevant unit tests and expect all targeted tests to pass."
- "Build the project and expect a successful build with no new errors."
- "Compare command output and expect the new field to appear with the correct value."
- "Manually inspect the rendered result and confirm the updated text, layout, or behavior matches the acceptance criteria."

## Completion Standard

A task is complete only when the verification step has been executed and the result matches the expected outcome.

If verification cannot be run, say so explicitly, explain why, and do not present the work as fully verified.
