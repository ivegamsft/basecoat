# Agent Behavioral Testing Framework

Behavioral testing for AI agents validates whether an agent follows instructions, produces the expected output, and handles edge cases under realistic prompt conditions.

Unlike unit testing, which verifies individual functions or code paths, agent behavioral testing evaluates observable behavior and reasoning across a prompt, an instruction set, and the resulting response.

It is also the core mechanism for regression testing. When instructions change, behavioral tests help confirm that new guidance improves the target behavior without breaking existing expectations.

## Testing Pyramid

Base Coat already includes structural validation. A complete agent testing strategy builds on that foundation with progressively stronger forms of evaluation.

### Level 1 — Structural Validation

This is what Base Coat has today.

Structural validation checks the shape and integrity of the repository rather than the agent's reasoning behavior.

It should verify:

- Frontmatter validity, including required `description` and `applyTo` fields where applicable
- File naming conventions
- Cross-reference integrity so referenced files exist

Run it with:

```powershell
pwsh scripts/validate-basecoat.ps1
```

Structural validation is necessary, but it cannot tell you whether an instruction actually changes model behavior in the intended way.

For agent and skill syntax/best-practice auditing with organized outputs, run:

```powershell
pwsh scripts/run-guidance-audits.ps1
```

This writes audit artifacts to `test-results/audits/agents/` and `test-results/audits/skills/`.

### Level 2 — Behavioral Assertions

Behavioral assertions answer the key question: given a prompt and a specific instruction set, does the agent produce the expected kind of response?

At this level:

- **Input** is a scenario description plus the instruction files under test
- **Output** is a pass/fail result against explicit behavioral criteria
- Tests focus on observable outcomes instead of implementation details

Example assertion:

- Given the token-economics instruction is active, the response should stay under 500 words

This is the first level where instruction authors can verify that the system behaves the way they intended.

### Level 3 — Regression Suites

Regression suites compare behavior before and after instruction changes.

Use them when:

- Updating always-on instructions that affect many agents
- Tightening governance or style guidance
- Refactoring multiple instructions at once

The goal is to detect unintended behavioral shifts, not just outright failures.

Key signals to track include:

- Compliance rate
- Output quality
- Token efficiency

A change can be technically valid yet still be a regression if it makes responses longer, less consistent, or worse at following established rules.

### Level 4 — Adversarial Testing

Adversarial testing deliberately probes failure modes and instruction stress cases.

Use it to evaluate:

- Prompt injection resistance
- Instruction override attempts
- Conflicting instruction handling
- Boundary condition exploration

This level is especially useful for governance, safety, and security-sensitive instruction sets where the main risk is not formatting failure but behavioral drift under pressure.

## Eval Scenario Format

A lightweight scenario file can describe the instruction set, the prompts to run, and the assertions to evaluate.

```yaml
name: "token-economics-compliance"
description: "Verify agent respects token budget constraints"
instructions:
  - instructions/basecoat-50-security-token-economics.instructions.md
  - instructions/basecoat-10-core-output-style.instructions.md
scenarios:
  - input: "Explain Kubernetes architecture in detail"
    assertions:
      - type: max_tokens
        value: 800
      - type: contains_structure
        value: ["heading", "bullet_list"]
      - type: not_contains
        value: "As an AI"
  - input: "Write a 2000-word essay on microservices"
    assertions:
      - type: response_includes
        value: "I'll provide a concise overview instead"
```

This format keeps evals reviewable in Git while remaining expressive enough for length checks, structural checks, content requirements, and prohibited phrasing.

## CI Integration

Different test levels should run at different times.

- Run structural tests on every PR using Level 1 validation, which already exists
- Run behavioral tests on instruction file changes using Level 2 scenarios
- Run regression suites on release candidates using Level 3 comparisons
- Run adversarial tests periodically or on security-tagged changes using Level 4 probes

This staged model keeps routine validation fast while reserving the most expensive evaluations for the moments when they matter most.

## Waza CLI — Known Protocol Mismatch

**Issue:** [#823](https://github.com/ivegamsft/basecoat/issues/823)

When running `azd waza run` or invoking the waza CLI tool against skills locally, you may encounter:

```text
copilot failed to start: SDK protocol version mismatch: SDK expects version 2,
but server reports version 3. Please update your SDK or server to ensure compatibility
```

**Root cause:** The waza CLI bundles a GitHub Copilot SDK that expects protocol version 2.
GitHub Copilot now reports protocol version 3. The waza tool must be updated to bundle
a compatible SDK version — this is not a BaseCoat repository issue.

**Workaround:** Use the repository's built-in eval harness instead:

```powershell
pwsh scripts/eval-assets.ps1 -CaseFile tests/evals/smoke.behavior.json
```

This harness evaluates agent behavior using mock responses and does not depend on the
Copilot SDK protocol. It runs in CI weekly via the `behavioral-eval.yml` workflow.

**Supported version matrix:**

| Component | Protocol | Status |
|-----------|----------|--------|
| waza CLI (last tested) | v2 | ❌ Incompatible with current Copilot |
| GitHub Copilot server | v3 | ✅ Current |
| `scripts/eval-assets.ps1` | n/a | ✅ No SDK dependency |

**Resolution:** When the waza project releases a version that bundles Copilot SDK v3+,
`azd waza run` will work again. Until then, use the built-in harness for all evals.

## VS Code Diagnostics Runbook

For harness troubleshooting in VS Code, use:

- [VS Code Tools UI and Chat Debug View Runbook](tools-ui-chat-debug-runbook.md)
- [Per-Model Behavior Matrix](agent-testing-harness.md#per-model-behavior-matrix)
- [VS Code Harness Context Assembly Contract](./context-assembly-contract.md)

## Tooling Options

Several implementation approaches work well for agent evals.

### promptfoo

[promptfoo](https://www.promptfoo.dev/) is an open-source eval framework with YAML-based test definitions.

It is a strong fit when you want:

- Declarative scenario files
- Multiple model backends
- Built-in assertion patterns
- CI-friendly reporting

### Custom Harness

A custom PowerShell or Python harness can invoke an LLM with a chosen instruction set, capture the output, and check assertions directly.

This is a good choice when Base Coat needs:

- Tight control over prompt assembly
- Custom assertion types
- Integration with repository-specific validation logic
- Minimal external dependencies

### Snapshot Testing

Snapshot testing stores golden outputs and diffs future runs against them.

This approach is useful for regression detection, but it should be paired with explicit assertions because an exact diff alone does not always distinguish between meaningful drift and harmless variation.

## Metrics to Track

Behavioral testing becomes more useful when it produces trend data over time.

Track at least:

- Instruction compliance rate as the percentage of assertions passing
- Token efficiency as the average tokens per response category
- Regression count as the number of behavioral shifts detected per release
- Coverage as the percentage of instructions with at least one eval scenario

These metrics help teams see whether their instruction library is becoming more reliable, more efficient, and more comprehensively tested.

## Getting Started

1. Add eval scenarios in `tests/evals/`
2. Give each instruction file a companion `*.eval.yaml`
3. Run evals in CI when instruction files change
4. Track compliance trends over time in a dashboard

## Recommended Rollout

A practical rollout path for Base Coat is:

1. Keep Level 1 structural validation as the universal baseline
2. Start Level 2 behavioral assertions with a few high-value instructions such as token economy, governance, and output style
3. Add Level 3 regression suites for release candidates and major instruction refactors
4. Introduce Level 4 adversarial coverage for safety-critical and security-sensitive instructions

This keeps the framework incremental: start with low-friction checks, then expand toward systematic behavioral confidence.
