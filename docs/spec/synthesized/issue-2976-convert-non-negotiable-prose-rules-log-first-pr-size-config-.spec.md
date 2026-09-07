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
4. Wire the enforceable checks into PR or CI gates so violations fail closed at
   the point they would otherwise be merged. The PR-size rule must retain the
   existing routine-work ceiling of 15 changed files or 300 net line changes and
   document the explicit override path for larger work.
5. Update documentation to distinguish enforced controls from advisory judgment
   guidance. When a prose rule becomes enforced, replace the long always-on
   wording with a one-line pointer to the authoritative control inventory or
   validator.

The implementation must avoid brittle natural-language policing. Validate
structured metadata, changed-file counts, known config paths, policy files, and
documented evidence patterns where possible; route ambiguous prose to explicit
manual-review guidance instead of pretending it is enforceable.

## Acceptance Criteria

- [ ] A control inventory exists and includes LOG-FIRST, PR-size/batch limits,
  and config-secret handling.
- [ ] Existing validation commands fail on representative violations and pass
  on compliant fixtures.
- [ ] Enforced controls fail closed in the relevant PR/CI path, including the
  15-file/300-line PR-size ceiling and the documented override path.
- [ ] Error output names the violated control and gives the remediation.
- [ ] Advisory controls remain documented but are not presented as deterministic
  gates.
- [ ] Always-on instruction text for newly enforced controls is reduced to
  one-line pointers instead of duplicated long-form prose.
- [ ] PR references this PRD and spec.

## References

- PRD: `docs/prd/synthesized/issue-2976-convert-non-negotiable-prose-rules-log-first-pr-size-config-.prd.md`
- Refs #2976
- Issue: <https://github.com/IBuySpy-Shared/basecoat/issues/2976>
