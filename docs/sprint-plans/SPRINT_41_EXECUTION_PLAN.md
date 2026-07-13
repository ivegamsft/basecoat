# Sprint 41 Execution Plan — Carryover Wave

- **Status:** ACTIVE
- **Scope:** 9 issues across 3 waves
- **Purpose:** carry forward the deferred incident-routing, drift, rollup, and learning work from Sprint 40

---

## Wave Breakdown

### Wave 1 — Foundation / Specs / Guards

- #2489 — Define incident-to-backlog routing contract
- #2490 — Define portfolio drift detection audit rules
- #2491 — Define rollup metrics and publisher contract
- #2492 — Define learning promotion and memory hygiene criteria

### Wave 2 — Core Implementations

- #2493 — Implement incident routing workflow and verification linkage
- #2494 — Implement drift detection report and alerting
- #2495 — Implement rollup publisher and scorecard generation
- #2496 — Implement learning promotion queue and cleanup sweep

### Wave 3 — Closeout / Handoff

- #2497 — Publish Sprint 41 closeout evidence and carryover summary

---

## Dependency Map

Each Wave 1 contract gates only its corresponding Wave 2 implementation (one-to-one),
and all Wave 2 implementations gate the Wave 3 closeout:

```text
Wave 1:  #2489    #2490    #2491    #2492
           |        |        |        |
           v        v        v        v
Wave 2:  #2493    #2494    #2495    #2496
            \        \      /        /
             \        \    /        /
              +--------> #2497 <----+
Wave 3:               (closeout)
```

- #2489 -> #2493 (incident routing)
- #2490 -> #2494 (drift detection)
- #2491 -> #2495 (rollup metrics)
- #2492 -> #2496 (learning promotion)

## Success Criteria

1. Wave 1 definitions are explicit enough to support implementation without re-planning.
2. Each Wave 2 issue can start once its corresponding Wave 1 contract is complete
   (per the one-to-one edges above), independently of the other Wave 2 tracks.
3. Wave 3 publishes the final evidence package and documents any carryover.

## Follow-ups Discovered During Implementation

These `sprint:41`-labelled issues were opened while implementing the carryover work and are
tracked as follow-ups beyond the original nine-issue scope:

- #2502 — ship-it dispatch rerun idempotency for closed predecessor stages
- #2504 — drift-audit live-validated condition/action signature detection
- #2507 — incident routing online linkage verification (referenced issue/PR mentions incident ID)

## Notes

- All issues are labeled `sprint:41`.
- Wave 2 and Wave 3 issues are marked `blocked` until their prerequisite wave completes.
- The execution plan intentionally keeps the carryover scope bounded to one sprint lane.
- The original scope is nine issues (#2489-#2497); the follow-ups above were added during
  implementation and are tracked separately.
