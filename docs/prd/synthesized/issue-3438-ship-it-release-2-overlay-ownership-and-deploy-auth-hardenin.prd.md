---
issue: 3438
title: "ship-it: release 2 overlay ownership and deploy auth hardening"
status: draft
author: ibuyspy
created: 2026-09-19
labels: ["enhancement", "priority:medium", "needs-triage", "wave:2", "ship-it", "needs-prd", "needs-info", "synthesize-spec"]
---

# PRD: ship-it: release 2 overlay ownership and deploy auth hardening

## Problem Statement

Release automation spans multiple products that share overlay directories. A
partial sync or inconsistent deployment authentication contract can overwrite
foreign files, leave stale BaseCoat files behind, or fail late in a release.

## Goal

Plan and execute the next ship-it release focused on sync safety, overlay
ownership, and deploy auth hardening.

## Scope

- finalize shared overlay ownership and lock semantics
- ensure sync only prunes BaseCoat-owned stale files and preserves foreign overlays
- standardize deploy auth contracts and IaC review gates
- validate release readiness with the repo test suite

## Why This Matters

*Not specified.*

## Success Criteria

- [ ] Shared overlay writes are serialized and ownership metadata is updated
      atomically.
- [ ] Sync removes only stale files owned by BaseCoat and preserves foreign
      overlay content.
- [ ] Deployment workflows validate their authentication and IaC contracts
      before privileged work begins.
- [ ] Targeted and full repository validation pass before release.

## References

- Refs #3438
- Issue: <https://github.com/IBuySpy-Shared/basecoat/issues/3438>
