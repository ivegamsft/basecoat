# Sprint W29 Execution Plan — Published Docs Hardening & CI Routing Completion

**Sprint:** 2026-W29 (July 14-20, 2026)
**Status:** PLANNED
**Scope:** 12 issues across 3 waves
**Focus areas:** Published repo health, Copilot agent assignment, MCP runner routing completion

---

## Scope Summary

| Metric | Value |
|---|---|
| Total issues | 12 |
| Priority:high | 4 |
| Priority:medium | 4 |
| Priority:low | 4 |
| Carryover from W28 | 2 (#2237, #2238) |
| Blocked (needs-prd) | 3 (#2239, #2240, #2231) |

---

## Wave 1 — Published Repo & Copilot Agent (High Priority)

**Goal:** unblock published repo health and automate Copilot agent assignment.

| Issue | Title | Priority | Notes |
|---|---|---|---|
| #2246 | fix deployment failures in public mirror | high | prod/staging deploy failures |
| #2244 | remove internal-only content from public exports | high | leaking sprint summaries to public |
| #2245 | pin published docs to build version | high | version drift in published pages |
| #2250 | enable Copilot coding agent for automated issue assignment | high | issue-approve.yml update |

**Wave 1 acceptance gate:** all four PRs merged, public mirror deploys green.

---

## Wave 2 — CI Intent Routing & Test Coverage (Medium Priority)

**Goal:** complete W28 carryover runner work and fill intent/triage gaps.

| Issue | Title | Priority | Notes |
|---|---|---|---|
| #2237 | route MCP workflows through runner vars | medium | W28 carryover |
| #2238 | daily runner inventory audit for workflow routing | medium | W28 carryover |
| #2248 | add missing ship-it intent mapping | medium | intent-dispatch gap |
| #2242 | cover triage label and field sync tests | medium | regression guard |

**Wave 2 acceptance gate:** CI green, no regressions on validate-basecoat.

---

## Wave 3 — Cleanup & Polish (Low Priority)

**Goal:** reduce CI noise and improve docs usability.

| Issue | Title | Priority | Notes |
|---|---|---|---|
| #2243 | commit runner-routing docs update | low | docs already on disk, needs PR |
| #2233 | remove dead self-hosted runner contract checks | low | cleanup after MCP pin |
| #2232 | strengthen MCP workflow runner guardrail coverage | low | test hardening |
| #2247 | increase diagram size in published pages | low | docs UX |

---

## Blocked / Deferred

| Issue | Title | Blocker |
|---|---|---|
| #2239 | feat(ci): add issue-to-spec synthesis workflow | needs-prd |
| #2240 | feat(ci): add release-train packaging orchestration | needs-prd |
| #2231 | pin remaining deploy workflows to Linux runners | needs-prd decision |

---

## Execution Notes

- Serialize merges per fleet-merge-pacing convention.
- #2173 ([aw] No-Op Runs) is auto-managed; do not assign or close manually.
- Wave 2 can start in parallel with Wave 1 tail once first Wave 1 PR merges.
- #2239 and #2240 need a PRD before implementation can be scoped.
