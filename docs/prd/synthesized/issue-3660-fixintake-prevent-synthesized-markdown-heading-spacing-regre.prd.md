---
issue: 3660
title: "fix(intake): prevent synthesized Markdown heading-spacing regressions"
status: proposal
author: ibuyspy
created: 2026-10-08
labels: ["bug", "priority:high", "needs-triage", "needs-prd", "synthesize-spec"]
---

# PRD: fix(intake): prevent synthesized Markdown heading-spacing regressions

## Problem Statement

## Description

fix(intake): prevent synthesized Markdown heading-spacing regressions

## Intake Contract

### RCA

## Why This Matters

Generated PRD/spec artifacts must pass the same Markdown rules as PR CI.
Publishing known-invalid output creates drafts with no safe completion
handoff and repeats already diagnosed MD022 failures.

## Scope

Normalize copied sections without changing meaning, compile embedded
JavaScript before deployment and validate both generated artifacts before
publishing a synthesis draft. Preserve draft-producing behavior and explicit
source authority. Missing requirements remain visibly unresolved; formatting
never turns a placeholder into an approved spec.

## Non-goals

No approval manufacture, coding-agent assignment, release-gate bypass or
production authority. Do not treat successful generation or green CI as
permission to promote incomplete design documents.

## Acceptance and Evidence

- [x] Identify copied-heading MD022 and duplicate lexical-binding signatures.
- [x] Specify heading/fence/CRLF and full-script compilation regressions.
- [x] Separate draft readiness from formatting and generation success.
- [x] Define prepublication failure and retry behavior.

The current hotfix candidate is #3691. Its parse/heading tests do not prove
the full prepublication linting and source-extraction contract below is
deployed. Retain #3660 until required acceptance is verified.

## Success Criteria

- [ ] The implementation addresses the stated problem.
- [ ] The acceptance criteria are validated before release.

## References

- Refs #3660
- Issue: <https://github.com/IBuySpy-Shared/basecoat/issues/3660>
