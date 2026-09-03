---
issue: 2927
title: "chore: 8 eval.yaml files with aria/keyboard terms not routed to accessibility-auditor (W04), 8 files with low eval-coverage negatives (W05)"
status: draft
author: ibuyspy
created: 2026-09-03
labels: ["priority:low", "chore", "synthesize-spec"]
---

# Spec: chore: 8 eval.yaml files with aria/keyboard terms not routed to accessibility-auditor (W04), 8 files with low eval-coverage negatives (W05)

## Problem Statement

## Summary
`warn-rules.ps1` rules W04 (aria-keyboard) and W05 (eval-coverage) flagged findings against consumer-synced basecoat/sheen skill eval files.

## W04 aria-keyboard (8 files)
eval.yaml references aria/keyboard terms but the routed agent is not `accessibility-auditor` -- verify routing intent:
- accessibility-audit/eval.yaml
- component-spec/eval.yaml
- data-visualisation/eval.yaml

## Why This Matters

_Not specified._

## Scope

_Not specified._

## Acceptance Criteria

- [ ] Implementation matches the scope defined above.
- [ ] Validation commands pass with no errors.
- [ ] PR references this spec.

## References

- PRD: `docs/prd/synthesized/issue-2927-chore-8-evalyaml-files-with-ariakeyboard-terms-not-routed-to.prd.md`
- Refs #2927
- Issue: https://github.com/IBuySpy-Shared/basecoat/issues/2927
