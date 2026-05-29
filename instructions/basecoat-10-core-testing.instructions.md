---
description: "Use when adding, updating, or reviewing tests. Covers common testing best practices for regression protection, determinism, and change validation."
applyTo: "**/*"
---

# Testing Standards

Use this instruction when adding or modifying tests, or when validating risky changes.

## Expectations

- Test behavior, not implementation trivia.
- Add the smallest set of tests that protects against the real regression.
- Prefer deterministic tests with explicit fixtures and clear failure messages.
- Cover boundary conditions and error paths when the change affects them.
- If tests cannot be run, state that clearly and explain why.
- Prefer narrow, high-value tests over broad brittle suites.
- When fixing a bug, add a test that fails before the fix when feasible.

## Positive Test Guidance

- Add positive-path tests that prove expected behavior under valid inputs and normal conditions.
- Confirm the main success path returns the expected result, state change, or output.
- Include at least one realistic end-to-end happy path when integration behavior changes.

## Negative Test Guidance

- Add negative-path tests that prove invalid inputs and failure conditions are handled safely.
- Verify error messages, status codes, and fallback behavior are explicit and stable.
- Cover authorization failures, validation failures, dependency failures, and timeout paths when relevant.
- Ensure failures do not leak secrets, PII, or internal-only diagnostic details.

## Minimum Validation Checklist

- Existing tests relevant to the change still pass.
- New or changed behavior is exercised.
- Manual verification steps are noted when automation is missing.
- The test names make the protected behavior obvious.
- Positive and negative scenarios are both represented for changed behavior.

## Manual Test Strategy

Use the manual test strategy agents and skill when a change or feature needs explicit decisions about where human judgment is still required and what should graduate into automation.

### When to Apply

- A new feature or risk area has no documented manual scope.
- Exploratory work is informal or undocumented.
- A checklist or charter needs to be reproducible by a new team member.
- Automation candidates from manual testing need to be captured and filed.

### Agents

- **`agents/manual-test-strategy.agent.md`**: produces the full strategy — decision rubric, exploratory charter, regression checklist, defect template, and automation backlog with GitHub Issues filed for every candidate.
- **`agents/exploratory-charter.agent.md`**: generates one or more time-boxed exploratory sessions with mission, scope, evidence format, and triage routing. Files GitHub Issues for automation-worthy findings.
- **`agents/strategy-to-automation.agent.md`**: converts manual paths and rubric rows into tiered automation candidates (smoke, regression, integration, or agent spec) and files a GitHub Issue for every candidate without exception.

### Skill

- **`skills/manual-test-strategy/`**: provides the rubric, charter, checklist, and defect templates used by all three agents.

### Decision Rubric

Every behavior under manual test scope should be classified as one of:

| Classification | When to use |
| --- | --- |
| **Manual-only** | Human judgment required; exploratory, context-dependent, or infrequent |
| **Automate-now** | Stable, deterministic, high-value, frequently repeated |
| **Hybrid** | Core path can be scripted; edge cases or environment variation still need a manual pass |

See `skills/manual-test-strategy/rubric-template.md` for the full scoring matrix.

### Automation Handoff

- Automation candidates are never left implicit. Every identified candidate is filed as a GitHub Issue with labels `testing` and `automation-candidate`.
- Defect evidence records include an automation handoff section so future scripted coverage is easier to prioritize.
- Keep all strategy artifacts stack-agnostic: no framework-specific references belong in rubrics, charters, or checklists.
