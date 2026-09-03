---
issue: 2975
title: "Re-scope always-on instructions by load timing to reclaim ~40k tokens/turn"
status: draft
author: ibuyspy
created: 2026-09-03
labels: ["enhancement", "governance", "priority:medium", "synthesize-spec"]
---

# PRD: Re-scope always-on instructions by load timing to reclaim ~40k tokens/turn

## Problem Statement

basecoat parks its cognitive/core instruction layer at `applyTo: "**/*"`, so it loads on **every** file edit regardless of relevance. Measured directly against the upstream `instructions/` folder:

- **34 of 91 instruction files are always-on (`applyTo: "**/*"`) ≈ 39,780 tokens** (~bytes/4).
- In a real consumer (`IBuySpy-Dev/ibuypets-v3`) the always-on set is **43 files ≈ 47.4k tokens** (core 34 + sheen 9), i.e. **~43% of the entire instruction corpus is hot on every single turn** — including backend `.cs`, IaC `.bicep`, and `.sql` edits.

This **contradicts basecoat's own always-on instructions**: `basecoat-50-security-token-economics` and `basecoat-*-tool-minimization` preach frugal context, yet they are themselves inside the ~40k always-on block. Several of the heaviest always-on files are even marked `distribute: false` in their frontmatter (`basecoat-10-core-hrm-execution`, `basecoat-10-core-memory-index`, `basecoat-50-security-token-economics`) — the maintainers already signalled these are not consumer-facing, yet they still load in the consumer.

By contrast the sibling **HVE** framework ships *more* total instruction content but keeps only ~5.6k tokens always-on (~3.5%) by routing on load-timing (`applyTo` path globs + on-demand skills) — roughly **8.5× less hot context per turn**.

## Why This Matters

*Not specified.*

## Scope

*Not specified.*

## Success Criteria

- [ ] The implementation addresses the stated problem.
- [ ] The acceptance criteria are validated before release.

## References

- Refs #2975
- Issue: <https://github.com/IBuySpy-Shared/basecoat/issues/2975>
