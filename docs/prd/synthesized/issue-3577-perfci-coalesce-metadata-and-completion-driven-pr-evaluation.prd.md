---
issue: 3577
title: "perf(ci): coalesce metadata and completion-driven PR evaluation fan-out"
status: implemented
author: ibuyspy
created: 2026-10-06
labels: ["enhancement", "priority:medium"]
---

# PRD: coalesce PR evaluation notifications

## Problem Statement

Label/body changes and required-workflow completions cause bursts of repeated
evaluations for unchanged PR heads. This carries forward the problem statement
from generated draft #3582, while refining its unspecified scope.

## Scope

Bound expensive work for short metadata/completion bursts while guaranteeing a
surviving evaluation of current authorization evidence. Separate metadata gates
from code validation. Never cache approvals/holds or deduplicate solely by SHA.

## Success Criteria

- Reproduce label/body and five-check bursts with a controlled baseline.
- Invalidate on head, metadata, hold, approval or required-check changes.
- Retain current-head checks, solo-dev gates and PR/merge-group/main validation.
- Report measured fixture calls and cancellations without production inference.

## References

- Source: #3577; incorporated generated draft: #3582
- Spec: [issue-3577 spec](../../spec/synthesized/issue-3577-perfci-coalesce-metadata-and-completion-driven-pr-evaluation.spec.md)
