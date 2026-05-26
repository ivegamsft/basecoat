# Example 2: Refactoring an Existing Module

**Original request:** "Refactor the auth service to use dependency injection and improve testability."

---

## BAD Decomposition ✗

### The Problem
```
Sub-task 1: Refactor auth service
  - Update auth service to use DI
  - Refactor all callers
  - Update tests
  - Make sure nothing breaks

Sub-task 2: Improve code quality
  - Remove duplication
  - Make it more testable
```

**Why it's bad:**
- **Vague success criteria:** "Make sure nothing breaks" is not measurable
- **Scope creep:** "Remove duplication" could mean anything; where?
- **Coupled changes:** Refactoring the service AND all callers in one task = high risk
- **No metrics:** How do we know testability improved?
- **Unclear staging:** Should we refactor service first, then callers? Or in parallel?

---

## GOOD Decomposition ✓

### The Solution

```
Sub-task 1: Backend — Refactor auth service to use DI [30 min]
  Input: src/services/authService.ts, existing tests in src/services/auth.test.ts
  Scope:
    - Extract logger and config as constructor-injected dependencies
    - Maintain the same public interface (no breaking changes)
    - Add 3 new unit tests for DI setup (mocking logger, config)
  Success:
    - TypeScript compilation: no errors
    - All existing tests pass (run: npm test -- auth.test.ts)
    - New tests for DI scenarios pass
    - No changes to public method signatures
  Out of Scope:
    - Do NOT refactor calling code yet (separate task)
    - Do NOT add new features
    - Do NOT optimize performance

Sub-task 2: Backend — Update auth service callers [25 min]
  Input: Depends on Sub-task 1
  Scope:
    - Find all instantiations of AuthService (use grep: 'new AuthService')
    - Update each to inject logger and config instances
    - Expected files: src/index.ts, src/startup.ts, src/middleware/auth.ts
  Success:
    - All 5–7 callers updated to use constructor-injected dependencies
    - npm test passes (all tests, not just auth)
    - No TypeScript errors or warnings
    - grep 'new AuthService()' returns zero results (no bare instantiation)
  Out of Scope:
    - Do NOT refactor the callers' own initialization logic (separate concern)

Sub-task 3: Backend — Test coverage audit [15 min]
  Input: Updated authService.ts and all calling code from Sub-tasks 1 & 2
  Scope:
    - Verify existing test suite still covers all paths
    - Add 2–3 integration tests for DI wiring (mocked logger + config)
    - Run coverage report: npm test -- --coverage
  Success:
    - Coverage report shows ≥90% for authService.ts (was ≥85% before)
    - No untested error paths
    - Coverage report attached to PR description
  Out of Scope:
    - Do NOT overhaul the entire test suite
    - Do NOT test unrelated modules

Sub-task 4: Code Review — DI & testability review [15 min]
  Input: PRs from Sub-tasks 1, 2, and 3
  Scope:
    - Verify constructor injection pattern matches team conventions
    - Check for missing dependency injection (any hardcoded singletons?)
    - Verify mocking strategy in tests is correct
    - Check for circular dependencies
  Success:
    - All code review comments resolved or marked as tech debt
    - Approved for merge
  Out of Scope:
    - Do NOT request refactoring beyond the scope (e.g., "also refactor X")
```

### Parallelization
```
Timeline:
- Sub-task 1: 0–30 min (refactor service)
- Sub-task 2: 30–55 min (update callers; waits for Task 1)
- Sub-task 3: 55–70 min (test audit; waits for Task 2)
- Sub-task 4: 70–85 min (code review; waits for Tasks 1–3)

Note: Tasks 3 & 4 could start slightly earlier if needed, but they depend on prior tasks being complete.
```

---

## Key Lessons

1. **Backward compatibility first:** Refactor service first WITHOUT breaking public interface; update callers in a separate task

2. **Measurable testability:** Instead of "improve testability", specify "add 3 DI-focused tests" and "achieve ≥90% coverage"

3. **Explicit dependencies:** Sub-task 2 depends on Sub-task 1; state this clearly

4. **Staged approach:** Refactor → Update callers → Verify → Review (not all at once)

5. **Clear search patterns:** "grep 'new AuthService()'" is a testable success criterion

6. **Risk containment:** By updating callers in a separate task, we reduce the risk of one big refactor breaking everything

7. **Scope isolation:** Each sub-task focuses on one concern (DI injection, caller updates, coverage, review)

---

## Anti-Patterns to Avoid

- ❌ "Refactor everything that's bad" (unbounded scope)
- ❌ "Make it more testable" (not measurable)
- ❌ "Update all references" (unclear which references)
- ❌ "Ensure nothing breaks" (vague; should be specific tests)
- ❌ Refactoring the service AND updating all callers in one sub-task (high risk, hard to review)

