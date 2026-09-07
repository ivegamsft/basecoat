---
issue: 2976
title: "Convert non-negotiable prose rules (LOG-FIRST, PR-size, config secrets) to enforced controls"
status: draft
author: ibuyspy
created: 2026-09-07
labels: ["enhancement", "governance", "priority:medium", "needs-prd", "needs-info"]
---

# Spec: Convert non-negotiable prose rules (LOG-FIRST, PR-size, config secrets) to enforced controls

## Problem Statement

Several of basecoat's **non-negotiable** rules are encoded only as **advisory prose inside always-on instructions**, relying on the model to remember and comply, rather than as enforced controls. Examples:

- **LOG-FIRST** (log a GitHub issue before implementation work) — prose only.
- **Batch/PR-size limits** — prose only.
- **No secrets in config / config-secret handling** — prose guidance, not a scan.

Prose rules fail open: under context pressure (made worse by the ~40k always-on token load) the model can silently skip them, and there's no deterministic backstop. The sibling HVE framework's authoring standard (`hve-builder`) explicitly says to **route non-negotiables to enforced controls** (schemas, validators, hooks) and keep prose for judgement calls — and it ships `validate:frontmatter` / `plugin:validate` schema gates to back that up.

basecoat already has the machinery to do this: a large `tests/*.ps1` suite and validation scripts. The gap is that these hard rules aren't wired into it.

## Why This Matters

Mandatory controls need machine-verifiable backstops. A model-facing instruction
can improve behavior, but it cannot prove compliance or fail closed when
context pressure, branch churn, or automation retries skip a step.

## Scope

Implement this as an incremental control inventory plus validation hardening:

1. Add a checked-in inventory of non-negotiable controls with fields for source
   instruction, enforceability, validation surface, failure mode, and owner.
2. Add validation for the first enforcement wave:
   - issue-first evidence for implementation PRs,
   - PR-size/batch limit policy,
   - config-secret handling in repo configuration examples and docs.
3. Reuse existing PowerShell validation patterns and fail with actionable
   messages.
4. Update documentation to distinguish enforced controls from advisory judgment
   guidance.

The implementation must avoid brittle natural-language policing. Validate
structured metadata, changed-file counts, known config paths, policy files, and
documented evidence patterns where possible; route ambiguous prose to explicit
manual-review guidance instead of pretending it is enforceable.

## Acceptance Criteria

- [ ] A control inventory exists and includes LOG-FIRST, PR-size/batch limits,
  and config-secret handling.
- [ ] Existing validation commands fail on representative violations and pass
  on compliant fixtures.
- [ ] Error output names the violated control and gives the remediation.
- [ ] Advisory controls remain documented but are not presented as deterministic
  gates.
- [ ] PR references this PRD and spec.

## References

- PRD: `docs/prd/synthesized/issue-2976-convert-non-negotiable-prose-rules-log-first-pr-size-config-.prd.md`
- Refs #2976
- Issue: <https://github.com/IBuySpy-Shared/basecoat/issues/2976>
