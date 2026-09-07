---
issue: 3117
title: "Governance enhancement: add explicit untrusted-content / prompt-injection boundary instruction"
status: draft
author: ibuyspy
created: 2026-09-07
labels: ["enhancement", "governance", "security", "priority:medium", "needs-triage", "needs-prd", "synthesize-spec"]
---

# PRD: Governance enhancement: add explicit untrusted-content / prompt-injection boundary instruction

## Problem Statement

**Gap (vs HVE):** HVE ships `untrusted-content-boundary.instructions.md` — external/ingested content is treated as data, not instructions, with a non-overridable authority anchor (only user + identity + trusted config carry authority). basecoat has no explicit injection-boundary instruction.

**Proposal:** Add an always-on untrusted-content boundary instruction scoped to agents/skills that ingest web fetches, tool outputs, and provided artifacts.

**Existing partial coverage:** `s4-safety-gates`, `tool-minimization` (adjacent, not injection-specific).

Parent: #3113

## Why This Matters

BaseCoat agents and skills regularly ingest issue bodies, PR comments, web
content, tool outputs, artifacts, and downstream repository files. Without an
explicit authority boundary, malicious or accidental text in those inputs can
look like instructions to the model. A dedicated untrusted-content boundary
reduces prompt-injection risk and gives reviewers a common standard for agent
and skill authoring.

## Scope

In scope:

- Add an explicit instruction that treats external or tool-produced content as
  data, not authority.
- Define trusted authority sources: user instructions, repository-owned
  configuration, checked-in BaseCoat instructions, and authenticated identity
  context.
- Require agents/skills that ingest untrusted text to preserve provenance and
  avoid following embedded instructions unless they are separately authorized.
- Add eval or validation coverage for at least one prompt-injection attempt in
  an ingested artifact or tool result.

Out of scope:

- Rewriting every existing agent prompt in the first wave.
- Claiming complete prompt-injection prevention.
- Blocking legitimate user-provided requirements that are delivered through the
  normal user instruction channel.

## Success Criteria

- [ ] A first-class untrusted-content boundary instruction exists and is loaded
  where relevant.
- [ ] Agent/skill authoring guidance references the boundary for web, artifact,
  issue, PR, and tool-output ingestion.
- [ ] Tests or evals demonstrate that embedded instructions in untrusted content
  are ignored or surfaced for human decision instead of executed.
- [ ] The boundary does not prevent users from intentionally changing
  requirements through trusted conversation or repository-config channels.

## References

- Refs #3117
- Issue: <https://github.com/IBuySpy-Shared/basecoat/issues/3117>
