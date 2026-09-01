---
name: yagni-analysis
compatibility: [copilot-chat, copilot-coding-agent, github-copilot-cli]
description: "Use for evidence-based YAGNI analysis before removal. USE FOR: audit suspected dead dependencies, validate unused-code claims, debate keep/remove/defer with rollback guidance. DO NOT USE FOR: automatic deletion, dependency upgrades, or broad code review."
category: development
metadata:
  category: development
  maturity: stable
  audience:
    - developer
allowed-tools: []
---

# YAGNI Analysis

Produce a report-only recommendation. Never remove files, manifests, or
runtime configuration.

## Modes

- **Audit:** find candidates in a bounded scope.
- **Validate:** test one necessity claim.
- **Debate:** compare keep, remove, and defer cases.

## Evidence Contract

For each candidate, report:

```text
Candidate: <package, path, feature flag, or abstraction>
Usage: [one or more of: direct, transitive, dynamic, generated, test-only, deployment, unknown]
Evidence for use: <file:line, runtime signal, or package graph>
Evidence against use: <file:line, query, or negative result>
Confidence: high | medium | low - <why>
Decision: keep | remove | consolidate | instrument | defer
Validation: <smallest targeted command or observation>
Rollback: <reversible restoration step>
```

## Workflow

1. Bound the candidate and mode; never infer broad cleanup from one match.
2. Gather positive and negative evidence from manifests, lockfiles, source,
   tests, workflows, IaC, generated artifacts, configuration, and runtime
   signals.
3. Classify every observed use. A missing text match is negative evidence, not
   proof of non-use.
4. Use `defer` or `instrument` when dynamic, reflective, generated, plugin,
   serialization, or runtime-config use cannot be ruled out.
5. In debate mode, present strongest keep, remove, and defer cases, then the
   smallest reversible action.
6. Hand package metadata to `dependency-lifecycle`; hand approved,
   behavior-preserving removal to `refactoring`.

## Guardrails

- Do not remove any candidate automatically.
- Do not label medium- or low-confidence candidates safe to remove.
- Check direct and transitive package references before recommending removal.
- Classify dynamic imports, reflection, generated code, test-only references,
  workflows, IaC, and runtime configuration separately.
- Use the configured corporate package proxy for registry or security evidence;
  report unavailable data as blocked rather than bypassing the proxy.
- Prefer a feature flag, telemetry, or canary experiment when static evidence
  cannot establish runtime reachability.

## Output

Return the evidence contract, ranked recommendations, exact targeted validation,
rollback guidance, and an explicit statement that no mutation was performed.
