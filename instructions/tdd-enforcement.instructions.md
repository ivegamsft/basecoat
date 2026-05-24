---
description: "Enforces RED-GREEN-REFACTOR test-driven development as a sequence gate for implementation work. Applies to feature code, bug fixes, and refactors in source directories."
applyTo: "src/**,lib/**,app/**,packages/**"
---

# TDD Enforcement — RED-GREEN-REFACTOR Gate

This instruction enforces test-driven development as a mandatory workflow sequence,
not advisory guidance. Implementation code must not exist before a failing test
proves the need for it.

## Sequence Gate

Every implementation change MUST follow this order:

1. **RED** — Write a test that fails, proving the behavior gap exists.
2. **GREEN** — Write the minimum implementation to make the test pass.
3. **REFACTOR** — Improve structure without changing behavior (tests stay green).

Violating this sequence (writing implementation before a failing test) is a blocking
issue in code review. The implementation must be reverted or a failing test must be
added retroactively before merge.

## Enforcement Rules

- Do NOT write implementation code without a corresponding failing test first.
- Do NOT skip the RED phase by writing tests that pass immediately on new code.
- Each RED-GREEN-REFACTOR cycle should target a single behavior or requirement.
- Commit after each phase when practical (separate red/green/refactor commits aid review).
- Test names must describe the behavior being proven, not the implementation detail.

## When This Applies

- New feature code (any new function, method, endpoint, or module)
- Bug fixes (the failing test reproduces the bug before the fix)
- Refactors that change public contracts or observable behavior
- API changes (request/response shape, status codes, error formats)

## When This Does NOT Apply

- Configuration-only changes (env vars, feature flags, infra-as-code)
- Documentation, comments, or formatting changes
- Exploratory spikes explicitly marked as throwaway (must not be merged without tests)
- Generated code (schema output, migrations) where the generator is itself tested
- Dependency upgrades with no code changes (rely on existing test suite)

## Integration with Plan-First Workflow

When using the plan-first workflow (plan → design → implement → verify):

- The **design** phase must identify which tests will be written.
- The **implement** phase begins with RED (failing tests), not production code.
- The **verify** phase confirms all cycles completed in sequence.

## Escape Hatch

If TDD is genuinely impractical for a specific change:

1. Add a comment in the PR description explaining why (not just "too hard").
2. Add the `skip-tdd-gate` label to the PR.
3. File a follow-up issue to add missing test coverage within one sprint.

Acceptable reasons: hardware-dependent behavior, third-party API with no test
double available, time-critical hotfix (must still file follow-up).

## Review Checklist

When reviewing a PR under this instruction:

- [ ] Each new behavior has a test that would fail without the implementation.
- [ ] Tests were committed before or alongside (not after) the implementation.
- [ ] Test names describe behavior, not implementation.
- [ ] No implementation code exists without a corresponding test.
- [ ] Refactoring steps do not introduce new behavior (tests unchanged).
