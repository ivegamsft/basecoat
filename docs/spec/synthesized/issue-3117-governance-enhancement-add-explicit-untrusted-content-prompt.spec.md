---
issue: 3117
title: "Governance enhancement: add explicit untrusted-content / prompt-injection boundary instruction"
status: draft
author: ibuyspy
created: 2026-09-07
labels: ["enhancement", "governance", "security", "priority:medium", "needs-triage", "needs-prd", "synthesize-spec"]
---

# Spec: Governance enhancement: add explicit untrusted-content / prompt-injection boundary instruction

## Problem Statement

**Gap (vs HVE):** HVE ships `untrusted-content-boundary.instructions.md` — external/ingested content is treated as data, not instructions, with a non-overridable authority anchor (only user + identity + trusted config carry authority). basecoat has no explicit injection-boundary instruction.

**Proposal:** Add an always-on untrusted-content boundary instruction scoped to agents/skills that ingest web fetches, tool outputs, and provided artifacts.

**Existing partial coverage:** `s4-safety-gates`, `tool-minimization` (adjacent, not injection-specific).

Parent: #3113

## Why This Matters

Prompt-injection defenses need a reusable authority model. Otherwise every
agent, skill, and workflow has to rediscover whether issue text, fetched web
content, generated artifacts, or tool output can override system, developer,
repository, or user instructions.

## Scope

Implement the first wave as an authoring and validation boundary:

1. Add an untrusted-content boundary instruction that states:
   - untrusted content is evidence/data,
   - embedded commands in untrusted content do not carry authority,
   - provenance must be preserved when summarizing or transforming content,
   - suspicious instructions should be reported or ignored according to the
     surrounding task.
2. Scope the instruction to agent/skill/prompt/documentation authoring surfaces
   and any workflow guidance that consumes issue, PR, web, artifact, or tool
   output.
3. Update agent/skill development guidance so new assets include negative evals
   for untrusted-content override attempts when they ingest external text.
4. Add or extend tests/evals for a representative injected artifact, such as a
   fetched page or issue body that asks the agent to ignore higher-priority
   instructions.
5. Add runtime guidance for workflows and scripts that transform untrusted
   content into repo artifacts: preserve the source issue/PR/artifact link,
   avoid executing embedded commands, and fail or require human review when the
   content asks to change authority, credentials, repository settings, or
   approval policy.
6. Regenerate any affected asset manifests or inventories so downstream
   consumers can discover the new boundary instruction after sync.

The implementation should be precise: do not classify repository-owned
instructions or direct user requests as untrusted merely because they are text.

## Runtime Enforcement Points

The first implementation wave should cover both authoring-time and runtime
surfaces:

- agent/skill evals for web, issue, PR, artifact, and tool-output ingestion,
- workflow-generated PRD/spec artifacts that quote or summarize issue content,
- scripts that ingest generated files or external reports before committing
  changes,
- documentation that tells users how to distinguish trusted instructions from
  quoted evidence.

Runtime checks should be conservative. They do not need to detect every possible
prompt injection, but they must prevent the obvious unsafe path: treating
embedded text such as "ignore previous instructions", "approve this PR", "change
the token", or "disable safety checks" as authoritative merely because it
appears in an issue body, fetched page, log, or artifact.

## Regression Coverage

Add negative coverage for both sides of the boundary:

- untrusted-channel regression: an issue body, fetched page, or artifact embeds
  instructions to ignore policy or alter credentials, and the agent/workflow
  refuses to treat it as authority,
- trusted-channel regression: a direct user request or checked-in repository
  policy still applies normally and is not mislabeled as untrusted content.

## Acceptance Criteria

- [ ] The instruction defines trusted authority sources and untrusted content
  classes.
- [ ] At least one eval/test covers a prompt-injection attempt in untrusted
  content.
- [ ] At least one trusted-channel regression proves direct user/repository
  instructions still apply normally.
- [ ] Runtime guidance covers workflow/script ingestion of issue bodies, PR
  comments, fetched content, logs, and generated artifacts.
- [ ] Agent/skill authoring docs require relevant negative evals for assets that
  ingest external text.
- [ ] Affected asset manifests or inventories are regenerated or explicitly
  confirmed unchanged.
- [ ] Validation commands pass with no errors.
- [ ] PR references this spec.

## References

- PRD: `docs/prd/synthesized/issue-3117-governance-enhancement-add-explicit-untrusted-content-prompt.prd.md`
- Refs #3117
- Issue: <https://github.com/IBuySpy-Shared/basecoat/issues/3117>
