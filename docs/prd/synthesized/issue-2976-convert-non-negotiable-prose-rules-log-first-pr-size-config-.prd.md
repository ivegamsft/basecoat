---
issue: 2976
title: "Convert non-negotiable prose rules (LOG-FIRST, PR-size, config secrets) to enforced controls"
status: draft
author: ibuyspy
created: 2026-09-07
labels: ["enhancement", "governance", "priority:medium", "needs-prd", "needs-info"]
---

# PRD: Convert non-negotiable prose rules (LOG-FIRST, PR-size, config secrets) to enforced controls

## Problem Statement

Several of basecoat's **non-negotiable** rules are encoded only as **advisory prose inside always-on instructions**, relying on the model to remember and comply, rather than as enforced controls. Examples:

- **LOG-FIRST** (log a GitHub issue before implementation work) — prose only.
- **Batch/PR-size limits** — prose only.
- **No secrets in config / config-secret handling** — prose guidance, not a scan.

Prose rules fail open: under context pressure (made worse by the ~40k always-on token load) the model can silently skip them, and there's no deterministic backstop. The sibling HVE framework's authoring standard (`hve-builder`) explicitly says to **route non-negotiables to enforced controls** (schemas, validators, hooks) and keep prose for judgement calls — and it ships `validate:frontmatter` / `plugin:validate` schema gates to back that up.

basecoat already has the machinery to do this: a large `tests/*.ps1` suite and validation scripts. The gap is that these hard rules aren't wired into it.

## Why This Matters

The repo already treats these rules as mandatory during human review, but they
are not measurable until after a mistake is visible in chat, a PR, or a workflow
failure. Converting them to deterministic checks reduces reliance on model
memory, keeps solo-dev automation honest, and makes downstream BaseCoat
consumers inherit the same guardrails through validation instead of guidance.

## Scope

In scope:

- Identify every instruction phrase currently framed as "must", "never", or
  "non-negotiable" and classify whether it is enforceable, advisory, or needs a
  follow-up design.
- Add or extend validation for enforceable controls, starting with issue-first
  implementation evidence, PR-size/batch limits, and config-secret handling.
- Make enforceable controls fail closed in the PR or CI path where the
  violation would matter. At minimum, preserve the existing PR-size ceiling of
  15 changed files or 300 net line changes, require an explicit documented
  override path for larger work, and reject configuration examples that place
  secrets in committed config.
- Wire new checks into the existing PowerShell validation/test suite instead of
  introducing a new runner.
- Document any intentionally advisory controls so reviewers know why they
  remain prose.
- Reduce instructions for controls that become enforced to short pointers to
  the authoritative validation or policy surface instead of duplicating long
  always-on prose.

Out of scope:

- Rewriting all always-on instructions.
- Replacing human judgment for design/security tradeoffs.
- Blocking emergency fixes that explicitly use the repo's documented bypass or
  incident process.

## Success Criteria

- [ ] Covered controls fail closed where they are enforced: implementation PRs
  without issue evidence fail the appropriate PR gate, routine PRs above 15
  files or 300 net changed lines fail without an explicit override, and
  committed config-secret examples fail validation.
- [ ] Advisory-only rules are documented with a reason they cannot be reliably
  enforced.
- [ ] Validation failures produce actionable messages naming the violated rule
  and remediation path.
- [ ] `scripts\validate-basecoat.ps1` or the existing test suite exercises the
  new checks.
- [ ] Always-on instruction prose for enforced rules is reduced to one-line
  pointers to the control inventory or validation surface.

## References

- Refs #2976
- Issue: <https://github.com/IBuySpy-Shared/basecoat/issues/2976>
