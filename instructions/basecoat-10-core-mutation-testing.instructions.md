---
description: >
  Mutation testing standards — use when verifying test quality. Mutation testing checks whether
  existing tests actually catch bugs. Covers score thresholds, tool selection, and fix strategies.
applyTo: "agents/contract-testing.agent.md, agents/e2e-test-strategy.agent.md, instructions/testing.instructions.md"
---

# Mutation Testing Standards

## When to Apply

Use mutation testing when:

- Test suite has ≥80% line coverage but you want to verify it catches real bugs.
- Validating critical system behavior before production release.
- Investigating false confidence (low failure rate, but bugs still ship).

**Key insight:** Line coverage is a poor proxy for test quality. A test that executes a line but never asserts the result is worthless. Mutation testing exposes this gap.

## How It Works

1. Tool introduces deliberate bugs (mutations: operator swap, condition delete, return value flip).
2. Full test suite runs against each mutation.
3. **Killed** = tests caught the bug (good). **Survived** = tests missed it (gap).
4. `Mutation Score = killed / total × 100`. Target: **>80%**, aim for **>85%**.

## Quick Rules

- Score **>85%** — production-ready; monitor on CI.
- Score **70–85%** — acceptable; plan fixes in next sprint.
- Score **<70%** — halt feature development; remediate first.
- Always test at **exact boundaries** (18 vs 17/19) to catch `>=` vs `>` mutations.
- Always test **invalid inputs** to catch return-value mutations.
- Always test **guard conditions** (auth, validation) to catch conditional-deletion mutations.
- Group survived mutations by category before fixing; don't fix one-off survivors at random.

## Tools

| Language | Tool | Install |
|---|---|---|
| Python | mutmut | `pip install mutmut` |
| JavaScript/TypeScript | Stryker | `npm install -D @stryker-mutator/core` |
| Java | PIT | Maven plugin `pitest-maven` |

## Reference Files

| File | Contents |
|---|---|
| [mutation-tools-and-ci.md](references/mutation-testing/mutation-tools-and-ci.md) | Tool config (mutmut/Stryker/PIT), CI/CD YAML, score interpretation, improvement phases |
| [survival-patterns-and-fixes.md](references/mutation-testing/survival-patterns-and-fixes.md) | Boundary, conditional-deletion, operator, and return-value mutation patterns with test fixes |

## See Also

- `testing.instructions.md` — General pytest/Jest conventions, coverage, and CI integration.
- `contract-testing.agent.md` — Contract test quality assurance.
