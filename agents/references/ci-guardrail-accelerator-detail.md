# CI Guardrail Accelerator — Detail

Supporting detail for [`agents/basecoat-60-workflow-ci-guardrail-accelerator.agent.md`](../basecoat-60-workflow-ci-guardrail-accelerator.agent.md).

## Fast-Path Rules

| Change type | Eligible fast paths | Skippable jobs (if labeled) |
| --- | --- | --- |
| Narrative docs only (excluding agents, skills, prompts, and instructions) | Skip unit tests, build | Keep link checks, spell check |
| Config-only (non-secrets YAML/JSON) | Skip unit tests | Keep config lint, schema validation |
| Test-file-only changes | Skip infra checks | Keep test runner, coverage gate |
| Dependency bump (Dependabot) | Run only affected test suites | Skip unrelated integration tests |

## Parallelization Analysis

For each pair of sequential jobs, check:

1. Does job B consume any output artifact from job A? If no, they can run in parallel.
2. Does job B require job A's environment state? If no, they can run in parallel.
3. Is there a CI platform concurrency limit that prevents parallelism? Flag if so.

## Redundancy Detection

Flag as redundant when:

- Two jobs run the same lint tool with the same config file.
- Two jobs run tests against the same code path with no scope difference.
- Two jobs report the same required status, or a required branch-protection check has no
  producing workflow. Branch protection consumes status; it does not execute validation.

## Output Format

```markdown
## CI Guardrail Acceleration Report

### PR Change Classification
- Change type: source-code
- Fast-path eligible: no (source changes require full test suite)
- Estimated current CI duration: 18 min

### Parallelization Opportunities
| Jobs | Current order | Recommendation | Estimated savings |
| --- | --- | --- | --- |
| lint + typecheck | sequential | run in parallel (no shared artifacts) | 3 min |
| unit-tests + build | sequential | run in parallel (build output not needed by tests) | 5 min |

### Redundant Check Candidates
| Job | Reason | Recommendation |
| --- | --- | --- |
| eslint-legacy | Duplicate rules with eslint-main | Remove eslint-legacy |

### Estimated Optimized Duration
- Current: 18 min
- Optimized: 10 min
- Savings: 8 min (44%)

### Recommended Workflow Changes
1. Run lint and typecheck as independent jobs with no `needs` edge.
2. Remove eslint-legacy — covered by eslint-main.
3. Add `paths` filter to skip unit tests for docs-only PRs.
```
